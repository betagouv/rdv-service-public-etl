DO $$ 
DECLARE 
    stmt text; 
BEGIN 
    -- Drop constraints
    FOR stmt IN 
        SELECT 'ALTER TABLE "' || table_name || '" DROP CONSTRAINT IF EXISTS "' || constraint_name || '" CASCADE;' 
        FROM information_schema.table_constraints 
        WHERE table_schema = 'public'
    LOOP 
        EXECUTE stmt; 
    END LOOP;

    -- Drop tables
    FOR stmt IN 
        SELECT 'DROP TABLE IF EXISTS "' || tablename || '" CASCADE;' 
        FROM pg_tables 
        WHERE schemaname = 'public'
    LOOP 
        EXECUTE stmt; 
    END LOOP;

    -- Drop indexes
    FOR stmt IN 
        SELECT 'DROP INDEX IF EXISTS "' || indexname || '" CASCADE;' 
        FROM pg_indexes 
        WHERE schemaname = 'public'
    LOOP 
        EXECUTE stmt; 
    END LOOP;

    -- drop custom types
    FOR stmt IN
        SELECT
            'DROP TYPE "public"."' || typname || '" CASCADE;'
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE
            n.nspname = 'public'
          AND typname NOT LIKE 'pg_%'    -- Exclude system schemas
          AND typtype != 'b'    -- Exclude base types
          AND n.nspname <> 'information_schema'    -- Exclude information_schema
    LOOP
        EXECUTE stmt;
    END LOOP;

    DROP EXTENSION IF EXISTS "uuid-ossp" CASCADE;
    DROP EXTENSION IF EXISTS pg_stat_statements CASCADE;
END $$;
