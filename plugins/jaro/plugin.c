#include <stdbool.h>
#include "postgres.h"
#include "mb/pg_wchar.h"
#include "util.h"
#include "fmgr.h"

/*
 * Jaro code based on http://www.rosettacode.org/wiki/Jaro_distance#C
 * Adapted to use PostgreSQL functions to deal with multi-byte chars.
 */
static double jaro_impl(const char *source, int slen, int m, int *s_char_len,
                        const char *target, int tlen, int n, int *t_char_len)
{
  // If both strings are empty return 1
  if (!m && !n) return 1.0;

  // If only one of the strings is empty return 0
  if (!m || !n) return 0.0;

  // Max distance between two chars to be considered matching
  // floor() is omitted due to integer division rules
  int match_distance = (int) (m > n ? m : n) / 2 - 1;

  // Arrays of bools that signify if that char in the string has a match
  // Uses the PostgreSQL functions palloc instead of malloc
  bool *s_matches = palloc0(m * sizeof(bool));
  bool *t_matches = palloc0(n * sizeof(bool));

  // Number of matches and transpositions
  double matches = 0.0;
  double transpositions = 0.0;

  // Find the matches
  const char *x = source;
  const char *y;
  for (int i = 0; i < m; i++)
  {
    // Get length of current char in source
    int	x_char_len = s_char_len[i];

    // Start and end take into account the match distance
    int start = 0 < i - match_distance ? i - match_distance : 0;
    int end = i + match_distance + 1 < n ? i + match_distance + 1 : n;

    y = target;
    for (int j = 0; j < n; j++) {
      // Get length of current char in target
      int y_char_len = t_char_len[j];

      // Within the match distance, only if there is a new match
      if (j >= start && j < end && !t_matches[j]
        && char_is_same(x, x_char_len, y, y_char_len)) {

        s_matches[i] = true;
        t_matches[j] = true;
        matches++;
        break;
      }

      // Point to next character in target
      y += y_char_len;
    }

    // Point to next character in source
    x += x_char_len;
  }

  // If there are no matches return 0
  if (matches == 0) return 0.0;

  // Count transpositions
  x = source;
  y = target;
  int j = 0;
  for (int i = 0; i < m; i++)
  {
    // Get length of the current char in source and target
    int	x_char_len = s_char_len[i];
    int	y_char_len = t_char_len[j];

    // Only if there are no matches in s_matches
    if (s_matches[i])
    {
      // While there is no match in the target point to the next char in j
      while (!t_matches[j])
      {
        j++;
        y += y_char_len;
        y_char_len = t_char_len[j];
      }

      // Increment transpositions
      if (!char_is_same(x, x_char_len, y, y_char_len)) transpositions++;

      // Point to next character in target
      j++;
      y += y_char_len;
    }

    // Point to next character in source
    x += x_char_len;
  }

  // Divide the number of transpositions by two as per the algorithm specs
  // This division is valid because the counted transpositions include both
  // instances of the transposed characters
  transpositions /= 2.0;

  // Return the Jaro distance / similarity
  return ((matches / m) + (matches / n)
    + ((matches - transpositions) / matches)) / 3.0;
}

static double jaro_winkler_impl(const char *source, int slen,
                                int m, int *s_char_len,
                                const char *target, int tlen,
                                int n, int *t_char_len, double prefix_weight)
{
  // Compute Jaro distance
  double jaro_d = jaro_impl(source, slen, m, s_char_len,
                            target, tlen, n, t_char_len);

  // Compute the common prefix length
  int common_prefix = 0;
  int max_len = n < 4 ? n : 4;
  const char *x = source;
  const char *y = target;
  for (int i = 0; i < max_len; ++i)
  {
    // Use PostgreSQL functions to get length of the characters
    int x_char_len = s_char_len[i];
    int y_char_len = t_char_len[i];

    // Increase common prefix with one if the chars are the same
    if (char_is_same(x, x_char_len, y, y_char_len))
      ++common_prefix;
    else
      break;

    // Point to next characters
    x += x_char_len;
    y += y_char_len;
  }

  // Return the Jaro-Winkler similarity
  return jaro_d + (common_prefix * prefix_weight * (1.0 - jaro_d));
}

static double _jaro_winkler(const char *source, int slen,
                            const char *target, int tlen,
                            bool use_jaro_winkler, double prefix_weight)
{
  // Convert string lengths (in bytes) to lengths in characters
  // Use PostgreSQL function to get length of multibyte characters
  int m = pg_mbstrlen_with_len(source, slen);
  int n = pg_mbstrlen_with_len(target, tlen);

  // Avoid calling pg_mblen() repeatedly on each char
  // Get the lengths of all chars in both strings
  int *s_char_len = lengths_of_chars(source, slen, m);
  int *t_char_len = lengths_of_chars(target, tlen, n);

  if (use_jaro_winkler)
    return jaro_winkler_impl(source, slen, m, s_char_len,
                             target, tlen, n, t_char_len, prefix_weight);

  return jaro_impl(source, slen, m, s_char_len, target, tlen, n, t_char_len);
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
