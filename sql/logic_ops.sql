CREATE FUNCTION t_min(a numeric, b numeric) RETURNS numeric AS $$
SELECT least(a, b);
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION t_prod(a numeric, b numeric) RETURNS numeric AS $$
SELECT a * b;
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION t_luk(a numeric, b numeric) RETURNS numeric AS $$
SELECT greatest(0, a + b - 1);
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION t_d(a numeric, b numeric) RETURNS numeric AS $$
SELECT CASE WHEN b = 1 THEN a WHEN a = 1 THEN b ELSE 0 END;
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION t_nm(a numeric, b numeric) RETURNS numeric AS $$
SELECT CASE WHEN a + b > 1 THEN least(a, b) ELSE 0 END;
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION t_h0(a numeric, b numeric) RETURNS numeric AS $$
SELECT CASE WHEN NOT a = 0 AND NOT b = 0 THEN a * b / (a + b - (a * b)) ELSE 0 END;
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION tc_max(a numeric, b numeric) RETURNS numeric AS $$
SELECT greatest(a, b);
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION tc_sum(a numeric, b numeric) RETURNS numeric AS $$
SELECT a + b - (a * b);
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION tc_luk(a numeric, b numeric) RETURNS numeric AS $$
SELECT least(a + b, 1);
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION tc_d(a numeric, b numeric) RETURNS numeric AS $$
SELECT CASE WHEN b = 0 THEN a WHEN a = 0 THEN b ELSE 1 END;
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION tc_nm(a numeric, b numeric) RETURNS numeric AS $$
SELECT CASE WHEN a + b < 1 THEN greatest(a, b) ELSE 1 END;
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION tc_h2(a numeric, b numeric) RETURNS numeric AS $$
SELECT (a + b) / (1 + a * b);
$$ LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;

CREATE AGGREGATE t_min_agg(numeric) (sfunc = t_min, stype = numeric);
CREATE AGGREGATE t_prod_agg(numeric) (sfunc = t_prod, stype = numeric);
CREATE AGGREGATE t_luk_agg(numeric) (sfunc = t_luk, stype = numeric);
CREATE AGGREGATE t_d_agg(numeric) (sfunc = t_d, stype = numeric);
CREATE AGGREGATE t_nm_agg(numeric) (sfunc = t_nm, stype = numeric);
CREATE AGGREGATE t_h0_agg(numeric) (sfunc = t_h0, stype = numeric);
CREATE AGGREGATE tc_max_agg(numeric) (sfunc = tc_max, stype = numeric);
CREATE AGGREGATE tc_sum_agg(numeric) (sfunc = tc_sum, stype = numeric);
CREATE AGGREGATE tc_luk_agg(numeric) (sfunc = tc_luk, stype = numeric);
CREATE AGGREGATE tc_d_agg(numeric) (sfunc = tc_d, stype = numeric);
CREATE AGGREGATE tc_nm_agg(numeric) (sfunc = tc_nm, stype = numeric);
CREATE AGGREGATE tc_h2_agg(numeric) (sfunc = tc_h2, stype = numeric);

