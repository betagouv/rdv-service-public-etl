-- from https://www.postgresql.org/message-id/CANu8FiyJtt-0q%3DbkUxyra66tHi6FFzgU8TqVR2aahseCBDDntA%40mail.gmail.com

-- Function: clone_schema(text, text)

-- DROP FUNCTION clone_schema(text, text);

CREATE OR REPLACE FUNCTION clone_schema(
    source_schema text,
    dest_schema text,
    include_recs boolean)
  RETURNS void AS
$BODY$

--  This function will clone all sequences, tables, data, views & functions from any existing schema to a new one
-- SAMPLE CALL:
-- SELECT clone_schema('public', 'new_schema', TRUE);

DECLARE
src_oid          oid;
  tbl_oid          oid;
  func_oid         oid;
  object           text;
  buffer           text;
  srctbl           text;
  default_         text;
  column_          text;
  qry              text;
  dest_qry         text;
  v_def            text;
  seqval           bigint;
  sq_last_value    bigint;
  sq_max_value     bigint;
  sq_start_value   bigint;
  sq_increment_by  bigint;
  sq_min_value     bigint;
  sq_cache_value   bigint;
  sq_log_cnt       bigint;
  sq_is_called     boolean;
  sq_is_cycled     boolean;
  sq_cycled        char(10);

BEGIN

-- Check that source_schema exists
SELECT oid INTO src_oid
FROM pg_namespace
WHERE nspname = quote_ident(source_schema);
IF NOT FOUND
    THEN
    RAISE NOTICE 'source schema % does not exist!', source_schema;
    RETURN ;
END IF;

  -- Check that dest_schema does not yet exist
  PERFORM nspname
    FROM pg_namespace
   WHERE nspname = quote_ident(dest_schema);
  IF FOUND
    THEN
    RAISE NOTICE 'dest schema % already exists!', dest_schema;
    RETURN ;
END IF;

EXECUTE 'CREATE SCHEMA ' || quote_ident(dest_schema) ;

-- Create tables
FOR object IN
SELECT TABLE_NAME::text
FROM information_schema.tables
WHERE table_schema = quote_ident(source_schema)
  AND table_type = 'BASE TABLE'

    LOOP
    buffer := dest_schema || '.' || quote_ident(object);
EXECUTE 'CREATE TABLE ' || buffer || ' (LIKE ' || quote_ident(source_schema) || '.' || quote_ident(object)
    || ' INCLUDING ALL)';

IF include_recs
      THEN
      -- Insert records from source table
      EXECUTE 'INSERT INTO ' || buffer || ' SELECT * FROM ' || quote_ident(source_schema) || '.' || quote_ident(object) || ';';
END IF;

FOR column_, default_ IN
SELECT column_name::text,
        REPLACE(column_default::text, source_schema, dest_schema)
FROM information_schema.COLUMNS
WHERE table_schema = dest_schema
  AND TABLE_NAME = object
  AND column_default LIKE 'nextval(%' || quote_ident(source_schema) || '%::regclass)'
    LOOP
      EXECUTE 'ALTER TABLE ' || buffer || ' ALTER COLUMN ' || column_ || ' SET DEFAULT ' || default_;
END LOOP;

END LOOP;

--  add FK constraint
FOR qry IN
SELECT 'ALTER TABLE ' || quote_ident(dest_schema) || '.' || quote_ident(rn.relname)
           || ' ADD CONSTRAINT ' || quote_ident(ct.conname) || ' ' || pg_get_constraintdef(ct.oid) || ';'
FROM pg_constraint ct
         JOIN pg_class rn ON rn.oid = ct.conrelid
WHERE connamespace = src_oid
  AND rn.relkind = 'r'
  AND ct.contype = 'f'

    LOOP
      EXECUTE qry;

END LOOP;



  RETURN;

END;

$BODY$
LANGUAGE plpgsql VOLATILE
  COST 100;
