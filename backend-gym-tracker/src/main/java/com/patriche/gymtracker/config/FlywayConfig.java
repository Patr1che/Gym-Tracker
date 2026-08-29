package com.patriche.gymtracker.config;

import org.flywaydb.core.Flyway;
import org.springframework.boot.flyway.autoconfigure.FlywayMigrationStrategy;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Repairs the schema history before migrating.
 *
 * <p>Flyway records a version, a description and a CRC32 checksum of every migration it
 * applies, then validates all three on each startup. That makes an already-applied
 * migration file effectively frozen: renaming it changes the description, and editing it
 * - even only its comments, which are part of the checksummed content - changes the
 * checksum. Either one fails validation and the application refuses to start, against a
 * database whose schema is in fact exactly right.
 *
 * <p>{@link Flyway#repair()} realigns the recorded descriptions and checksums with what
 * the files now say, and clears entries for migrations that failed partway. It does not
 * re-run anything and does not touch application data, so an edit that only changes
 * comments costs a deploy nothing.
 *
 * <p>The trade-off is deliberate and worth stating: with repair running unconditionally,
 * a change to the <em>SQL</em> of an applied migration is also accepted silently rather
 * than caught at startup - and that change will never execute against a database that
 * already ran the old version, leaving it quietly different from a freshly built one.
 * Applied migrations still have to be treated as immutable; this only removes the
 * penalty for editing the prose around them.
 */
@Configuration
class FlywayConfig {

    @Bean
    FlywayMigrationStrategy repairBeforeMigrate() {
        return flyway -> {
            flyway.repair();
            flyway.migrate();
        };
    }
}
