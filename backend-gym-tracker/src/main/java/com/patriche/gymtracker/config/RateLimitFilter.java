package com.patriche.gymtracker.config;

import com.patriche.gymtracker.common.JsonErrors;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Caps how often one client may hit the unauthenticated auth endpoints.
 *
 * <p>Everything under {@code /api/v1/auth/**} is {@code permitAll} by necessity - you
 * cannot present a token to obtain your first token - which leaves registration and
 * login open to anyone who finds the address. On free hosting that is a resource problem
 * before it is a security one: each registration is a row on a 0.5 GB database and a
 * verification email out of a capped daily quota, and a login loop is BCrypt work on a
 * tenth of a CPU. A script could spend the month in an afternoon.
 *
 * <p>Two limits, because the two abuses look nothing alike. Guessing a password is many
 * requests against one endpoint in a short burst; farming accounts is a slow drip that a
 * per-minute limit never notices. So requests are capped per minute and registrations
 * per hour, and a client has to stay under both.
 *
 * <p><b>What this is not.</b> The counters live in memory on one instance. They reset on
 * restart and would not be shared if this ever ran on two - fine on Render's free tier,
 * which is a single instance that restarts on deploy, and the reason not to reach for
 * Redis to hold what is only a speed bump. It cannot stop a distributed attempt either,
 * since the key is the client address. It raises the cost of the cheap attacks that
 * actually find a small public API; it is not a WAF.
 */
@Component
public class RateLimitFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(RateLimitFilter.class);

    private static final String PATH_PREFIX = "/api/v1/auth/";
    private static final String REGISTER_PATH = "/api/v1/auth/register";

    /** How long a client must be silent before its entry may be swept. */
    private static final long IDLE_NANOS = TimeUnit.HOURS.toNanos(2);

    /** Floor between sweeps, so a flood of new addresses cannot make every request scan. */
    private static final long SWEEP_INTERVAL_NANOS = TimeUnit.MINUTES.toNanos(1);

    private final AppProperties.RateLimit config;
    private final Map<String, Client> clients = new ConcurrentHashMap<>();
    private final AtomicLong lastSweepNanos = new AtomicLong(System.nanoTime());

    RateLimitFilter(AppProperties props) {
        this.config = props.rateLimit();
        if (config.enabled()) {
            log.info("Auth rate limiting enabled: {} requests/minute, of which {} "
                            + "registrations/hour, per client address.",
                    config.authPerMinute(), config.registrationsPerHour());
        } else {
            log.warn("Auth rate limiting is DISABLED - /api/v1/auth/** is uncapped.");
        }
    }

    /** Authenticated routes are already gated by a token; only the open ones need this. */
    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !config.enabled() || !request.getRequestURI().startsWith(PATH_PREFIX);
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        long now = System.nanoTime();
        sweepIfDue(now);

        Client client = clients.computeIfAbsent(key(request), k -> new Client(config, now));
        client.lastSeenNanos = now;

        boolean registering = REGISTER_PATH.equals(request.getRequestURI());
        long retryAfter = client.tryConsume(registering, now);
        if (retryAfter >= 0) {
            // Logged without the address: this fires on ordinary retry storms too, and a
            // log full of client IPs is its own small pile of personal data to look after.
            log.warn("Rate limit hit on {} - refusing for {}s",
                    request.getRequestURI(), retryAfter);
            response.setHeader(HttpHeaders.RETRY_AFTER, Long.toString(retryAfter));
            JsonErrors.write(response, HttpStatus.TOO_MANY_REQUESTS,
                    "Too many attempts. Try again in " + retryAfter + " seconds.",
                    request.getRequestURI());
            return;
        }
        chain.doFilter(request, response);
    }

    /**
     * The client address, as resolved by Spring's ForwardedHeaderFilter - which is why
     * {@code server.forward-headers-strategy} is set. Without it every request behind
     * Render's proxy arrives from the same address, and one visitor's limit would be
     * everyone's.
     *
     * <p>A forwarded header is client-supplied, so a determined caller can rotate it and
     * get a fresh bucket each time. Trusting it anyway is the right trade here: the
     * alternative - keying on the proxy's own address - throttles the entire internet as
     * a single client, which is worse in every ordinary case and trivially a
     * self-inflicted outage. This is a speed bump, and working against unsophisticated
     * traffic is the whole ambition.
     */
    private static String key(HttpServletRequest request) {
        String address = request.getRemoteAddr();
        return address == null || address.isBlank() ? "unknown" : address;
    }

    /**
     * Bounds the map. An entry per address is a memory leak with a public endpoint in
     * front of it, so once the table is over its cap the idle entries go. Evicting an
     * active client early would only hand it a fresh allowance, hence the idle window
     * rather than a plain size cap.
     */
    private void sweepIfDue(long now) {
        if (clients.size() <= config.maxTrackedClients()) {
            return;
        }
        long last = lastSweepNanos.get();
        if (now - last < SWEEP_INTERVAL_NANOS || !lastSweepNanos.compareAndSet(last, now)) {
            return;
        }
        int before = clients.size();
        clients.values().removeIf(c -> now - c.lastSeenNanos > IDLE_NANOS);
        log.info("Swept rate-limit table: {} -> {} tracked clients", before, clients.size());
    }

    /** The buckets belonging to one address. */
    private static final class Client {

        private final Bucket perMinute;
        private final Bucket registrations;
        private volatile long lastSeenNanos;

        Client(AppProperties.RateLimit config, long now) {
            this.perMinute =
                    new Bucket(config.authPerMinute(), TimeUnit.MINUTES.toNanos(1), now);
            this.registrations =
                    new Bucket(config.registrationsPerHour(), TimeUnit.HOURS.toNanos(1), now);
        }

        /**
         * Charges the general bucket first and only then the registration one, so a
         * caller still inside its hourly allowance cannot ignore the per-minute cap.
         *
         * @return seconds to wait, or -1 when the request may proceed
         */
        long tryConsume(boolean registering, long now) {
            long wait = perMinute.tryConsume(now);
            if (wait >= 0) {
                return wait;
            }
            if (registering) {
                long registerWait = registrations.tryConsume(now);
                if (registerWait >= 0) {
                    // The minute token is already spent. Not refunding it is deliberate:
                    // a refund would make rejected registrations free, and repeating one
                    // is exactly the behaviour being discouraged.
                    return registerWait;
                }
            }
            return -1;
        }
    }

    /**
     * A token bucket: {@code capacity} requests may arrive at once, and the allowance
     * refills smoothly across the window rather than resetting on a boundary. A fixed
     * window would let a caller spend a full allowance either side of the tick and take
     * double the intended rate through the middle.
     */
    private static final class Bucket {

        private static final double NANOS_PER_SECOND = 1_000_000_000d;

        private final double capacity;
        private final double tokensPerNano;
        private double tokens;
        private long lastRefillNanos;

        /**
         * The clock is the caller's, not this constructor's. The request reads the time
         * before the bucket that serves it exists, so seeding from System.nanoTime() here
         * leaves the bucket fractionally in the future and the first refill subtracts
         * instead of adding. At larger capacities that lost sliver is invisible; at a
         * capacity of one it puts the bucket under a whole token and the first request a
         * client ever makes is refused.
         */
        Bucket(int capacity, long windowNanos, long now) {
            this.capacity = capacity;
            this.tokensPerNano = (double) capacity / windowNanos;
            this.tokens = capacity;
            this.lastRefillNanos = now;
        }

        /** @return seconds until a token exists, or -1 if one was just spent */
        synchronized long tryConsume(long now) {
            tokens = Math.min(capacity, tokens + (now - lastRefillNanos) * tokensPerNano);
            lastRefillNanos = now;
            if (tokens >= 1) {
                tokens -= 1;
                return -1;
            }
            // Rounded up, and never reported as zero: "retry after 0 seconds" invites an
            // immediate retry that is certain to fail again.
            double secondsNeeded = (1 - tokens) / tokensPerNano / NANOS_PER_SECOND;
            return Math.max(1, (long) Math.ceil(secondsNeeded));
        }
    }
}
