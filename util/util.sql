CREATE FUNCTION similarity(source text, target text, distance decimal) RETURNS decimal AS $$
SELECT 1 - (distance / greatest(char_length(source), char_length(target)));
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION to_date_immutable(text, text) RETURNS date AS $$
BEGIN
    RETURN to_date($1, $2);
EXCEPTION
    WHEN SQLSTATE '22008' THEN
        RETURN NULL;
    WHEN SQLSTATE '22007' THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE FUNCTION to_numeric_immutable(text) RETURNS numeric AS $$
BEGIN
    RETURN $1::numeric;
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;
