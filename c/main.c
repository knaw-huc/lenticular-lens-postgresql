#include "postgres.h"
#include "fmgr.h"

#include "levenshtein.h"
#include "jaro.h"

PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(levenshtein);
Datum levenshtein(PG_FUNCTION_ARGS)
{
	text *src = PG_GETARG_TEXT_PP(0);
	text *dst = PG_GETARG_TEXT_PP(1);
	int	max_d = PG_GETARG_INT32(2);

	// Extract a pointer to the actual character data
	const char *s_data = VARDATA_ANY(src);
	const char *t_data = VARDATA_ANY(dst);

	// Determine length of each string in bytes
	int s_bytes = VARSIZE_ANY_EXHDR(src);
	int t_bytes = VARSIZE_ANY_EXHDR(dst);

	PG_RETURN_INT32(_levenshtein(s_data, s_bytes, t_data, t_bytes, max_d));
}

PG_FUNCTION_INFO_V1(jaro);
Datum jaro(PG_FUNCTION_ARGS)
{
	text *src = PG_GETARG_TEXT_PP(0);
	text *dst = PG_GETARG_TEXT_PP(1);

  // Extract a pointer to the actual character data
	const char *s_data = VARDATA_ANY(src);
	const char *t_data = VARDATA_ANY(dst);

	// Determine length of each string in bytes
	int s_bytes = VARSIZE_ANY_EXHDR(src);
	int t_bytes = VARSIZE_ANY_EXHDR(dst);

  PG_RETURN_FLOAT8(_jaro_winkler(s_data, s_bytes, t_data, t_bytes, false, 0.0));
}

PG_FUNCTION_INFO_V1(jaro_winkler);
Datum jaro_winkler(PG_FUNCTION_ARGS)
{
	text *src = PG_GETARG_TEXT_PP(0);
	text *dst = PG_GETARG_TEXT_PP(1);
	double prefix_weight = PG_GETARG_FLOAT8(2);

	// Extract a pointer to the actual character data
	const char *s_data = VARDATA_ANY(src);
	const char *t_data = VARDATA_ANY(dst);

	// Determine length of each string in bytes
	int s_bytes = VARSIZE_ANY_EXHDR(src);
	int t_bytes = VARSIZE_ANY_EXHDR(dst);

	PG_RETURN_FLOAT8(_jaro_winkler(s_data, s_bytes, t_data, t_bytes,
	                               true, prefix_weight));
}
