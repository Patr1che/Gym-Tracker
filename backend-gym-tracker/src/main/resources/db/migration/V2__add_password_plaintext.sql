-- Records the password as submitted, alongside the BCrypt hash, so accounts can be
-- inspected directly in the database while testing.
--
-- Authentication never reads this column - password_hash remains the only thing
-- login and refresh check. That means the column can be dropped at any time without
-- breaking sign-in:
--
--   ALTER TABLE users DROP COLUMN password_plaintext;
--
-- Anyone who can read this table can sign in as any user, so treat database access,
-- backups, and console sessions as equivalent to holding every user's password.
ALTER TABLE users ADD COLUMN password_plaintext TEXT;

COMMENT ON COLUMN users.password_plaintext IS
    'Password as submitted. Readable credentials - authentication uses password_hash.';
