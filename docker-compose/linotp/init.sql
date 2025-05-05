
DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'linotp') THEN
      CREATE USER linotp WITH PASSWORD 'yourpassword';
   END IF;
END$$;

CREATE DATABASE linotpdb OWNER linotp ENCODING 'UTF8';
