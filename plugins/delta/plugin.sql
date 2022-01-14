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
