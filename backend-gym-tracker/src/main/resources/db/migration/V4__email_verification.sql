-- Email verification by one-time code.
--
-- Verification gates sync, not sign-in. The app is offline-first: it is fully usable
-- with no server at all, so refusing to let an unverified user in would break the thing
-- that makes it work on a train. Refusing to STORE their data costs them nothing they
-- can see locally, and keeps unverified sign-ups from filling the free tier's 0.5 GB.

ALTER TABLE users ADD COLUMN email_verified BOOLEAN NOT NULL DEFAULT FALSE;

-- A code, not a link. The user types six digits back into the app, so the app learns
-- the moment verification succeeds and can drop its banner and resume syncing. A link
-- is opened in a browser instead, which leaves the app unaware until its next token
-- refresh - the user does the right thing and the app appears not to notice.
--
-- attempts is what makes six digits safe. A million combinations is nothing to a script,
-- so a code is burned after too many wrong guesses; the short expiry and that limit are
-- the real protection here. code_hash keeps the code out of casual view in a dump or a
-- log, but it is not a serious barrier on its own: six digits fall to a hash search
-- instantly, which is exactly why the attempt limit is not optional.
CREATE TABLE verification_codes (
    id          UUID PRIMARY KEY,
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code_hash   TEXT        NOT NULL,
    expires_at  TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ,
    attempts    INTEGER     NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Looked up by user, newest first - a code is only ever checked against the account
-- already identified by the caller's JWT, never by the code alone.
CREATE INDEX idx_verification_codes_user ON verification_codes(user_id, created_at DESC);
