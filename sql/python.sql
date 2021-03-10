CREATE FUNCTION soundex(input text, size integer) RETURNS text AS $$
from lenticular_lens.soundex import soundex
return soundex(input, size)
$$ LANGUAGE plpython3u IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION bloothooft(input text, type text) RETURNS text AS $$
from lenticular_lens.bloothooft import bloothooft_reduct
return bloothooft_reduct(input, type)
$$ LANGUAGE plpython3u IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION word_intersection(source text, target text, ordered boolean,
                                  approximate boolean, stop_symbols text) RETURNS decimal AS $$
from lenticular_lens.word_intersection import word_intersection
return word_intersection(source, target, ordered, approximate, stop_symbols)
$$ LANGUAGE plpython3u IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION init_dictionary(key text, dictionary text,
                                additional_stopwords text[] = ARRAY[]::text[]) RETURNS void AS $$
from lenticular_lens.stop_words import init_dictionary

if '_' in dictionary:
    [language, specific_set] = dictionary.split('_', 1)
else:
    language = dictionary

GD['language_' + key] = language
GD['stopwords_' + key] = init_dictionary(dictionary, additional_stopwords)
$$ LANGUAGE plpython3u IMMUTABLE STRICT PARALLEL RESTRICTED;

CREATE FUNCTION remove_stopwords(key text, input text) RETURNS text AS $$
from lenticular_lens.stop_words import remove_stopwords

stop_words_set = GD['stopwords_' + key]
language = GD['language_' + key]

return remove_stopwords(stop_words_set, language, input)
$$ LANGUAGE plpython3u IMMUTABLE STRICT PARALLEL RESTRICTED;

