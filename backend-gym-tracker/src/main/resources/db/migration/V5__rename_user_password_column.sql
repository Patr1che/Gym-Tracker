DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = current_schema()
                 AND table_name = 'users'
                 AND column_name = 'password_plaintext') THEN
        ALTER TABLE users RENAME COLUMN password_plaintext TO user_password;
    END IF;
END $$;

COMMENT ON COLUMN users.user_password IS NULL;
