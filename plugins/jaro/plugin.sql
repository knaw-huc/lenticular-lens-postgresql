CREATE FUNCTION jaro(text, text) RETURNS double precision
AS 'MODULE_PATHNAME', 'jaro'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION jaro_winkler(text, text, double precision) RETURNS double precision
AS 'MODULE_PATHNAME', 'jaro_winkler'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
