CREATE FUNCTION bloothooft(input text, type text) RETURNS text AS $$
from lenticular_lens.bloothooft import bloothooft_reduct
return bloothooft_reduct(input, type)
$$ LANGUAGE plpython3u IMMUTABLE STRICT PARALLEL SAFE;
