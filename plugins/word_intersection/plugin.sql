CREATE FUNCTION word_intersection(source text, target text, ordered boolean,
                                  approximate boolean, stop_symbols text) RETURNS decimal AS $$
from lenticular_lens.word_intersection import word_intersection
return word_intersection(source, target, ordered, approximate, stop_symbols)
$$ LANGUAGE plpython3u IMMUTABLE STRICT PARALLEL SAFE;
