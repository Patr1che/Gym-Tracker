package com.patriche.gymtracker;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestTemplate;
import org.springframework.context.annotation.Import;

/**
 * Runs against a real Postgres, because the things most worth testing here - the
 * lower(email) unique index, soft-delete tombstones, and the child-row rewrite on an
 * idempotent PUT - are all database behaviour that an in-memory stub would not reproduce.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {
                "app.jwt.secret=test-secret-that-is-definitely-long-enough-32",
                "spring.jpa.hibernate.ddl-auto=validate"
        })
@Import(TestcontainersConfiguration.class)
class AuthAndSyncIntegrationTest {

    @LocalServerPort
    int port;

    // The default HttpURLConnection factory cannot issue PATCH; the JDK HttpClient one
    // can, and needs no extra dependency.
    private final RestTemplate rest =
            new RestTemplate(new JdkClientHttpRequestFactory());

    private String url(String path) {
        return "http://localhost:" + port + "/api/v1" + path;
    }

    private <T> ResponseEntity<T> call(HttpMethod method, String path, Object body,
                                       String token, Class<T> type) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        if (token != null) headers.setBearerAuth(token);
        try {
            return rest.exchange(url(path), method, new HttpEntity<>(body, headers), type);
        } catch (org.springframework.web.client.HttpStatusCodeException e) {
            return ResponseEntity.status(e.getStatusCode()).build();
        }
    }

    @SuppressWarnings("unchecked")
    private String registerAndGetToken(String email) {
        ResponseEntity<Map> res = call(HttpMethod.POST, "/auth/register",
                Map.of("name", "Test", "email", email, "password", "secret123"),
                null, Map.class);
        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.OK);
        return (String) res.getBody().get("accessToken");
    }

    @Test
    void registerIsCaseInsensitiveOnEmail() {
        registerAndGetToken("Case@Example.com");

        ResponseEntity<Map> dup = call(HttpMethod.POST, "/auth/register",
                Map.of("name", "Other", "email", "CASE@example.COM", "password", "secret123"),
                null, Map.class);

        assertThat(dup.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void unknownEmailAndWrongPasswordAreIndistinguishable() {
        registerAndGetToken("probe@example.com");

        ResponseEntity<String> wrongPassword = call(HttpMethod.POST, "/auth/login",
                Map.of("email", "probe@example.com", "password", "notmypassword"),
                null, String.class);
        ResponseEntity<String> unknownEmail = call(HttpMethod.POST, "/auth/login",
                Map.of("email", "ghost@example.com", "password", "notmypassword"),
                null, String.class);

        assertThat(wrongPassword.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(unknownEmail.getStatusCode()).isEqualTo(wrongPassword.getStatusCode());
    }

    @Test
    void protectedRouteRequiresAToken() {
        ResponseEntity<String> res = call(HttpMethod.GET, "/me", null, null, String.class);
        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    /** The security test that matters most: one user must never reach another's data. */
    @Test
    @SuppressWarnings("unchecked")
    void oneUserCannotReadAnothersWorkout() {
        String alice = registerAndGetToken("alice-iso@example.com");
        String bob = registerAndGetToken("bob-iso@example.com");

        UUID workoutId = UUID.randomUUID();
        call(HttpMethod.PUT, "/workouts/" + workoutId, sampleWorkout(), alice, Map.class);

        ResponseEntity<String> bobRead =
                call(HttpMethod.GET, "/workouts/" + workoutId, null, bob, String.class);
        ResponseEntity<List> bobList =
                call(HttpMethod.GET, "/workouts", null, bob, List.class);

        assertThat(bobRead.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(bobList.getBody()).isEmpty();
    }

    @Test
    @SuppressWarnings("unchecked")
    void puttingTheSameWorkoutTwiceCreatesOneRow() {
        String token = registerAndGetToken("idem@example.com");
        UUID workoutId = UUID.randomUUID();

        call(HttpMethod.PUT, "/workouts/" + workoutId, sampleWorkout(), token, Map.class);
        ResponseEntity<Map> second =
                call(HttpMethod.PUT, "/workouts/" + workoutId, sampleWorkout(), token, Map.class);

        assertThat(second.getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<List> list = call(HttpMethod.GET, "/workouts", null, token, List.class);
        assertThat(list.getBody()).hasSize(1);
    }

    /** Client totals are ignored; the server derives them from the submitted sets. */
    @Test
    @SuppressWarnings("unchecked")
    void serverRecomputesTotalsAndIgnoresClientValues() {
        String token = registerAndGetToken("totals@example.com");
        call(HttpMethod.PATCH, "/me", Map.of("weightKg", 80), token, Map.class);

        UUID workoutId = UUID.randomUUID();
        ResponseEntity<Map> res =
                call(HttpMethod.PUT, "/workouts/" + workoutId, sampleWorkout(), token, Map.class);

        Map<String, Object> body = res.getBody();
        // 60*10 + 60*8 = 1080. The incomplete set and the skipped set contribute nothing,
        // and the bogus 99999 sent by the client is discarded.
        assertThat(((Number) body.get("totalVolumeKg")).doubleValue()).isEqualTo(1080.0);
        assertThat(((Number) body.get("totalSets")).intValue()).isEqualTo(2);
        assertThat(((Number) body.get("durationSec")).intValue()).isEqualTo(3600);
        // MET 5.0 * 80 kg * 1 h
        assertThat(((Number) body.get("caloriesEst")).intValue()).isEqualTo(400);
    }

    @Test
    @SuppressWarnings("unchecked")
    void deleteIsSoftAndTheTombstoneReachesOtherDevices() {
        String token = registerAndGetToken("tomb@example.com");
        UUID workoutId = UUID.randomUUID();
        call(HttpMethod.PUT, "/workouts/" + workoutId, sampleWorkout(), token, Map.class);

        call(HttpMethod.DELETE, "/workouts/" + workoutId, null, token, Void.class);

        ResponseEntity<List> live = call(HttpMethod.GET, "/workouts", null, token, List.class);
        assertThat(live.getBody()).isEmpty();

        ResponseEntity<Map> sync = call(HttpMethod.POST, "/sync",
                Map.of("since", Instant.EPOCH.toString()), token, Map.class);
        List<Map<String, Object>> pulled = (List<Map<String, Object>>) sync.getBody().get("workouts");

        assertThat(pulled).hasSize(1);
        assertThat(pulled.get(0).get("deletedAt")).isNotNull();
    }

    @Test
    @SuppressWarnings("unchecked")
    void aStalePushDoesNotClobberNewerData() {
        String token = registerAndGetToken("lww@example.com");
        UUID workoutId = UUID.randomUUID();

        Map<String, Object> newer = sampleWorkout();
        newer.put("dayName", "Newer");
        call(HttpMethod.PUT, "/workouts/" + workoutId, newer, token, Map.class);

        Map<String, Object> stale = sampleWorkout();
        stale.put("dayName", "Stale");
        stale.put("updatedAt", Instant.now().minus(Duration.ofDays(7)).toString());
        ResponseEntity<Map> res =
                call(HttpMethod.PUT, "/workouts/" + workoutId, stale, token, Map.class);

        assertThat(res.getBody().get("dayName")).isEqualTo("Newer");
    }

    @Test
    @SuppressWarnings("unchecked")
    void firstSyncWithNullCursorReturnsEverything() {
        String token = registerAndGetToken("firstsync@example.com");
        call(HttpMethod.PUT, "/workouts/" + UUID.randomUUID(), sampleWorkout(), token, Map.class);

        java.util.Map<String, Object> nullCursor = new java.util.HashMap<>();
        nullCursor.put("since", null);
        ResponseEntity<Map> sync = call(HttpMethod.POST, "/sync", nullCursor, token, Map.class);

        assertThat((List<?>) sync.getBody().get("workouts")).hasSize(1);
        assertThat(sync.getBody().get("serverTime")).isNotNull();
    }

    private static Map<String, Object> sampleWorkout() {
        Instant end = Instant.now();
        java.util.Map<String, Object> workout = new java.util.HashMap<>();
        workout.put("programId", "prog_ppl");
        workout.put("dayName", "Push");
        workout.put("startedAt", end.minus(Duration.ofHours(1)).toString());
        workout.put("endedAt", end.toString());
        workout.put("entries", List.of(Map.of(
                "exerciseId", "ex_bench_press",
                "sets", List.of(
                        Map.of("weightKg", 60, "reps", 10, "completed", true, "skipped", false),
                        Map.of("weightKg", 60, "reps", 8, "completed", true, "skipped", false),
                        Map.of("weightKg", 60, "reps", 6, "completed", false, "skipped", false),
                        Map.of("weightKg", 60, "reps", 6, "completed", true, "skipped", true)))));
        // Deliberately wrong: the server must ignore these.
        workout.put("totalVolumeKg", 99999);
        workout.put("totalSets", 999);
        workout.put("caloriesEst", 99999);
        return workout;
    }
}
