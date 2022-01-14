CREATE FUNCTION transform_last_name_format(name text, include_infix bool) RETURNS text AS $$
SELECT trim(first_name || ' ' || CASE WHEN include_infix AND infix != ''
                                          THEN infix || ' ' ELSE '' END || last_name)
FROM (VALUES (coalesce(trim(substring(name from ', ([^\[]*)')), ''),
              coalesce(trim(substring(name from '\[(.*)\]')), ''),
              coalesce(trim(substring(name from '^[^,\[]*')), '')))
         AS name_parts (first_name, infix, last_name);
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;
