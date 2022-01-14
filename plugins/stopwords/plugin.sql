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

CREATE FUNCTION get_stopwords(dictionary text) RETURNS text[] AS $$
from lenticular_lens.stop_words import init_dictionary
return init_dictionary(dictionary)
$$ LANGUAGE plpython3u IMMUTABLE STRICT PARALLEL SAFE;
