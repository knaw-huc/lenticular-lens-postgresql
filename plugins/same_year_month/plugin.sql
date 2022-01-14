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
