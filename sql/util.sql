CREATE FUNCTION similarity(source text, target text, distance decimal) RETURNS decimal AS $$
SELECT 1 - (distance / greatest(char_length(source), char_length(target)));
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION delta(type text, source numeric, target numeric,
                      start_delta numeric, end_delta numeric) RETURNS boolean AS $$
SELECT abs(source - target) BETWEEN start_delta AND end_delta AND
       CASE
           WHEN type = '<' THEN source <= target
           WHEN type = '>' THEN target <= source
           ELSE TRUE END;
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION delta(type text, source date, target date, no_days numeric) RETURNS boolean AS $$
SELECT abs(source - target) < no_days AND
       CASE
           WHEN type = '<' THEN source <= target
           WHEN type = '>' THEN target <= source
           ELSE TRUE END;
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION transform_last_name_format(name text, include_infix bool) RETURNS text AS $$
WITH name_parts (first_name, infix, last_name) AS (
    VALUES (coalesce(trim(substring(name from ', ([^\[]*)')), ''),
            coalesce(trim(substring(name from '\[(.*)\]')), ''),
            coalesce(trim(substring(name from '^[^,\[]*')), ''))
)
SELECT trim(first_name || ' ' ||
            CASE WHEN include_infix AND infix != ''
                THEN infix || ' '
                 ELSE ''
                END || last_name)
FROM name_parts;
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION get_date_part(type text, date text) RETURNS text AS $$
DECLARE
year  text;
month text;
BEGIN
year = substr(date, 0, 5);
month = substr(date, 6, 2);

CASE type
        WHEN 'year'
            THEN IF year ~ E'^\\d+$' THEN
                RETURN year;
ELSE
                RETURN NULL;
END IF;
WHEN 'month'
            THEN IF month ~ E'^\\d+$' THEN
                RETURN month;
ELSE
                RETURN NULL;
END IF;
WHEN 'year_month'
            THEN IF year ~ E'^\\d+$' AND month ~ E'^\\d+$' THEN
                RETURN year || '-' || month;
ELSE
                RETURN NULL;
END IF;
END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;

