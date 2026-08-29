-- Trims the schema's storage and per-query cost for the Neon free plan (0.5 GB of
-- storage, 100 CU-hours of compute per month). Nothing here changes what the API
-- returns; it changes what the database has to store and how many round trips a
-- sync costs.

-- ------------------------------------------------- redundant indexes

-- A UNIQUE constraint is backed by a btree, and a btree serves lookups on any prefix
-- of its columns. So UNIQUE (workout_log_id, sort_order) already indexes
-- workout_log_id on its own, and these two indexes only ever duplicated it - paying
-- storage per row and an extra write per insert on the two highest-volume tables in
-- the schema to answer queries the constraint was already answering.
DROP INDEX IF EXISTS idx_exercise_logs_workout;
DROP INDEX IF EXISTS idx_set_logs_exercise;

-- refresh_tokens is only ever read by token_hash, which is UNIQUE and therefore
-- already indexed. This index existed for the ON DELETE CASCADE from users; the
-- cleanup sweep in HousekeepingSweeper now holds the table to live tokens only, so
-- the cascade scans a small table instead of a large one.
DROP INDEX IF EXISTS idx_refresh_tokens_user;

-- ------------------------------------------------- batchable ids

-- exercise_logs and set_logs were BIGSERIAL, which maps to IDENTITY generation, and
-- Hibernate cannot batch inserts whose ids come back from the database one row at a
-- time: a 6-exercise, 24-set workout cost about 31 separate round trips.
--
-- Widening the sequence increment lets the entities claim ids 50 at a time and send
-- the whole workout in a couple of batched statements. The matching allocationSize
-- lives on @SequenceGenerator in the entities - the two MUST stay equal or ids
-- collide.
--
-- setval first so the sequence sits at or above both the current maximum id and one
-- full block, which keeps the first allocated block clear of existing rows.
SELECT setval('exercise_logs_id_seq',
              GREATEST((SELECT COALESCE(MAX(id), 0) FROM exercise_logs), 50));
SELECT setval('set_logs_id_seq',
              GREATEST((SELECT COALESCE(MAX(id), 0) FROM set_logs), 50));

ALTER SEQUENCE exercise_logs_id_seq INCREMENT BY 50;
ALTER SEQUENCE set_logs_id_seq INCREMENT BY 50;
