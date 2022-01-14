CREATE FUNCTION soundex(input text, size integer) RETURNS text AS $$
from lenticular_lens.soundex import soundex
return soundex(input, size)
$$ LANGUAGE plpython3u IMMUTABLE STRICT PARALLEL SAFE;
