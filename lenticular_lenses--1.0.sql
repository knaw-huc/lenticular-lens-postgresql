-- Complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION lenticular_lenses" to load this file. \quit

------------------------------------------- C functions --------------------------------------------

CREATE FUNCTION levenshtein(text, text, int) RETURNS int
AS 'MODULE_PATHNAME', 'levenshtein'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION jaro(text, text) RETURNS double precision
AS 'MODULE_PATHNAME', 'jaro'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION jaro_winkler(text, text, double precision) RETURNS double precision
AS 'MODULE_PATHNAME', 'jaro_winkler'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

----------------------------------------- Python functions -----------------------------------------

CREATE FUNCTION soundex(input text, size integer) RETURNS text AS $$
from lenticular_lenses.soundex import soundex
return soundex(input, size)
$$ LANGUAGE plpython3u IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION bloothooft(input text, type text) RETURNS text AS $$
from lenticular_lenses.bloothooft import bloothooft_reduct
return bloothooft_reduct(input, type)
$$ LANGUAGE plpython3u IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION word_intersection(source text, target text, ordered boolean,
                                  approximate boolean, stop_symbols text) RETURNS decimal AS $$
from lenticular_lenses.word_intersection import word_intersection
return word_intersection(source, target, ordered, approximate, stop_symbols)
$$ LANGUAGE plpython3u IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION init_dictionary(key text, dictionary text,
                                additional_stopwords text[] = ARRAY[]::text[]) RETURNS void AS $$
from lenticular_lenses.stop_words import init_dictionary

if '_' in dictionary:
    [language, specific_set] = dictionary.split('_', 1)
else:
    language = dictionary

GD['language_' + key] = language
GD['stopwords_' + key] = init_dictionary(dictionary, additional_stopwords)
$$ LANGUAGE plpython3u IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION remove_stopwords(key text, input text) RETURNS text AS $$
from lenticular_lenses.stop_words import remove_stopwords

stop_words_set = GD['stopwords_' + key]
language = GD['language_' + key]

return remove_stopwords(stop_words_set, language, input)
$$ LANGUAGE plpython3u IMMUTABLE STRICT PARALLEL SAFE;

------------------------------------------ SQL functions -------------------------------------------

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

CREATE FUNCTION logic_ops(operation text, a numeric, b numeric) RETURNS numeric AS $$
SELECT CASE
   WHEN a IS NULL
       THEN b
   WHEN b IS NULL
       THEN a
   WHEN operation = 'MINIMUM_T_NORM'
       THEN least(a, b)
   WHEN operation = 'PRODUCT_T_NORM'
       THEN a * b
   WHEN operation = 'LUKASIEWICZ_T_NORM'
       THEN greatest(0, a + b - 1)
   WHEN operation = 'DRASTIC_T_NORM'
       THEN CASE WHEN b = 1 THEN a WHEN a = 1 THEN b ELSE 0 END
   WHEN operation = 'NILPOTENT_MINIMUM'
       THEN CASE WHEN a + b > 1 THEN least(a, b) ELSE 0 END
   WHEN operation = 'HAMACHER_PRODUCT'
       THEN CASE WHEN NOT a = 0 AND NOT b = 0 THEN a * b / (a + b - (a * b)) ELSE 0 END
   WHEN operation = 'MAXIMUM_T_CONORM'
       THEN greatest(a, b)
   WHEN operation = 'PROBABILISTIC_SUM'
       THEN a + b - (a * b)
   WHEN operation = 'BOUNDED_SUM'
       THEN least(a + b, 1)
   WHEN operation = 'DRASTIC_T_CONORM'
       THEN CASE WHEN b = 0 THEN a WHEN a = 0 THEN b ELSE 1 END
   WHEN operation = 'NILPOTENT_MAXIMUM'
       THEN CASE WHEN a + b < 1 THEN greatest(a, b) ELSE 1 END
   WHEN operation = 'EINSTEIN_SUM'
       THEN (a + b) / (1 + a * b)
   END;
$$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;

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

----------------------------------------- PL/SQL functions -----------------------------------------

CREATE FUNCTION logic_ops(operation text, similarities numeric[]) RETURNS numeric AS $$
DECLARE
    similarity     numeric;
    cur_similarity numeric;
BEGIN
    FOREACH cur_similarity IN ARRAY similarities
        LOOP
            IF similarity IS NULL THEN
                similarity = cur_similarity;
            ELSE
                similarity = logic_ops(operation, similarity, cur_similarity);
            END IF;
        END LOOP;
    RETURN similarity;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;

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
