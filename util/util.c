#include <stdbool.h>
#include "postgres.h"
#include "mb/pg_wchar.h"
#include "util.h"
#include "fmgr.h"

PG_MODULE_MAGIC;

/*
 * In order to avoid calling pg_mblen() repeatedly on each character,
 * we cache all the lengths.
 *
 * Uses the PostgreSQL function palloc instead of the corresponding
 * C library function malloc. The memory allocated by palloc will be
 * freed automatically at the end of each transaction, preventing memory leaks.
 */
int* lengths_of_chars(const char *text, int byte_len, int str_len)
{
  int *char_len = (int *) palloc((str_len + 1) * sizeof(int));

  int i;
  for (i = 0; i < str_len; ++i)
  {
    char_len[i] = byte_len != str_len ? pg_mblen(text) : 1;
    text += char_len[i];
  }
  char_len[i] = 0;

  return char_len;
}

/*
 * Faster than memcmp(), for this use case.
 */
static inline bool rest_of_char_same(const char *s1, const char *s2, int len)
{
  while (len > 0)
  {
    len--;
    if (s1[len] != s2[len])
      return false;
  }
  return true;
}

/*
 * Helper function to test if two (multibyte) characters are the same.
 * We compare the last character of each possibly-multibyte character first,
 * because that's enough to rule out most mis-matches.
 * If we get past that test, we compare the lengths and the remaining bytes.
 */
inline bool char_is_same(const char *s1, int s1len, const char *s2, int s2len)
{
  return s1[s1len - 1] == s2[s2len - 1]
    && s1len == s2len
    && (s1len == 1 || rest_of_char_same(s1, s2, s1len));
}
