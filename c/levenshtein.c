/**
 * PostgreSQL is released under the PostgreSQL License,
 * a liberal Open Source license, similar to the BSD or MIT licenses.
 *
 * PostgreSQL Database Management System
 * (formerly known as Postgres, then as Postgres95)
 *
 * Portions Copyright © 1996-2021, The PostgreSQL Global Development Group
 * Portions Copyright © 1994, The Regents of the University of California
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without a written agreement
 * is hereby granted, provided that the above copyright notice and this
 * paragraph and the following two paragraphs appear in all copies.
 *
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
 * LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
 * EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 * FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON AN
 * "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATIONS TO PROVIDE
 * MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 */
#include "postgres.h"
#include "mb/pg_wchar.h"
#include "util.h"
#include "levenshtein.h"

/*
 * Levenshtein distance implementation from the PostgreSQL fuzzystrmatch module,
 * adapted to simplify and without a limit on the string length.
 *
 * Calculates Levenshtein distance metric between supplied strings, which are
 * not necessarily null-terminated.
 *
 * source: source string, of length slen bytes.
 * target: target string, of length tlen bytes.
 * max_d: if provided and >= 0, maximum distance we care about; see below.
 *
 * One way to compute Levenshtein distance is to incrementally construct
 * an (m+1)x(n+1) matrix where cell (i, j) represents the minimum number
 * of operations required to transform the first i characters of s into
 * the first j characters of t.  The last column of the final row is the
 * answer.
 *
 * We use that algorithm here with some modification.  In lieu of holding
 * the entire array in memory at once, we'll just use two arrays of size
 * m+1 for storing accumulated values. At each step one array represents
 * the "previous" row and one is the "current" row of the notional large
 * array.
 *
 * If max_d >= 0, we only need to provide an accurate answer when that answer
 * is less than or equal to max_d.  From any cell in the matrix, there is
 * theoretical "minimum residual distance" from that cell to the last column
 * of the final row.  This minimum residual distance is zero when the
 * untransformed portions of the strings are of equal length (because we might
 * get lucky and find all the remaining characters matching) and is otherwise
 * based on the minimum number of insertions or deletions needed to make them
 * equal length.  The residual distance grows as we move toward the upper
 * right or lower left corners of the matrix.  When the max_d bound is
 * usefully tight, we can use this property to avoid computing the entirety
 * of each row; instead, we maintain a start_column and stop_column that
 * identify the portion of the matrix close to the diagonal which can still
 * affect the final answer.
 */
int _levenshtein(const char *source, int slen,
                 const char *target, int tlen, int max_d)
{
  // Costs remain 1
  int ins_c = 1;
  int del_c = 1;
  int sub_c = 1;

  // Convert string lengths (in bytes) to lengths in characters.
  // Use PostgreSQL function to get length of multibyte characters.
  int m = pg_mbstrlen_with_len(source, slen);
  int n = pg_mbstrlen_with_len(target, tlen);

  // We can transform an empty s into t with n insertions, or a non-empty t
  // into an empty s with m deletions.
  if (!m)
    return n * ins_c;
  if (!n)
    return m * del_c;

  int start_column = 0;
  int stop_column = m + 1;

  // If max_d >= 0, determine whether the bound is impossibly tight.  If so,
  // return max_d + 1 immediately.  Otherwise, determine whether it's tight
  // enough to limit the computation we must perform.  If so, figure out
  // initial stop column.
  if (max_d >= 0)
  {
    int net_inserts = n - m;

    // Theoretical minimum distance
    int min_theo_d = net_inserts < 0
      ? -net_inserts * del_c
      : net_inserts * ins_c;

    if (min_theo_d > max_d)
      return max_d + 1;

    if (ins_c + del_c < sub_c)
      sub_c = ins_c + del_c;

    // Theoretical maximum distance
    int max_theo_d = min_theo_d + sub_c * (m < n ? m : n);

    if (max_d >= max_theo_d)
      max_d = -1;
    else if (ins_c + del_c > 0)
    {
      // Figure out how much of the first row of the notional matrix we
      // need to fill in.  If the string is growing, the theoretical
      // minimum distance already incorporates the cost of deleting the
      // number of characters necessary to make the two strings equal in
      // length.  Each additional deletion forces another insertion, so
      // the best-case total cost increases by ins_c + del_c. If the
      // string is shrinking, the minimum theoretical cost assumes no
      // excess deletions; that is, we're starting no further right than
      // column n - m.  If we do start further right, the best-case
      // total cost increases by ins_c + del_c for each move right.
      int slack_d = max_d - min_theo_d;
      int best_column = net_inserts < 0 ? -net_inserts : 0;

      stop_column = best_column + (slack_d / (ins_c + del_c)) + 1;
      if (stop_column > m)
        stop_column = m + 1;
    }
  }

  // In order to avoid calling pg_mblen() repeatedly on each character in s,
  // we cache all the lengths before starting the main loop -- but if all
  // the characters in both strings are single byte, then we skip this and
  // use a fast-path in the main loop.  If only one string contains
  // multi-byte characters, we still build the array, so that the fast-path
  // needn't deal with the case where the array hasn't been initialized.
  int *s_char_len = NULL;
  if (m != slen || n != tlen)
    s_char_len = lengths_of_chars(source, slen, m);

  // One more cell for initialization column and row
  ++m;
  ++n;

  // Previous and current rows of notional array.
  // Uses the PostgreSQL functions palloc and pfree instead of the
  // corresponding C library functions malloc and free. The memory allocated
  // by palloc will be freed automatically at the end of each transaction,
  // preventing memory leaks.
  int *prev = (int *) palloc(2 * m * sizeof(int));
  int *curr = prev + m;

  // To transform the first i characters of s into the first 0 characters of
  // t, we must perform i deletions.
  int i;
  for (i = start_column; i < stop_column; i++)
    prev[i] = i * del_c;

  // Loop through rows of the notional array
  int j;
  const char *y = target;
  for (j = 1; j < n; j++)
  {
    const char *x = source;

    // Use PostgreSQL function to get length of multibyte characters
    int y_char_len = n != tlen + 1 ? pg_mblen(y) : 1;

    // In the best case, values percolate down the diagonal unchanged, so
    // we must increment stop_column unless it's already on the right end
    // of the array.  The inner loop will read prev[stop_column], so we
    // have to initialize it even though it shouldn't affect the result.
    if (stop_column < m)
    {
      prev[stop_column] = max_d + 1;
      ++stop_column;
    }

    // The main loop fills in curr, but curr[0] needs a special case: to
    // transform the first 0 characters of s into the first j characters
    // of t, we must perform j insertions.  However, if start_column > 0,
    // this special case does not apply.
    if (start_column == 0)
    {
      curr[0] = j * ins_c;
      i = 1;
    }
    else
      i = start_column;

    // This inner loop is critical to performance, so we include a
    // fast-path to handle the (fairly common) case where no multibyte
    // characters are in the mix.  The fast-path is entitled to assume
    // that if s_char_len is not initialized then BOTH strings contain
    // only single-byte characters.
    for (; i < stop_column; i++)
    {
      int x_char_len = s_char_len != NULL ? s_char_len[i - 1] : 1;

      // Calculate costs for insertion, deletion, and substitution.
      // When calculating cost for substitution, we compare the last
      // character of each possibly-multibyte character first,
      // because that's enough to rule out most mis-matches.  If we
      // get past that test, then we compare the lengths and the
      // remaining bytes.
      int ins = prev[i] + ins_c;
      int del = curr[i - 1] + del_c;
      int sub;
      if (s_char_len == NULL)
        sub = prev[i - 1] + ((*x == *y) ? 0 : sub_c);
      else if (char_is_same(x, x_char_len, y, y_char_len))
        sub = prev[i - 1];
      else
        sub = prev[i - 1] + sub_c;

      // Take the one with minimum cost
      curr[i] = ins < del ? ins : del;
      curr[i] = curr[i] < sub ? curr[i] : sub;

      // Point to next character
      x += x_char_len;
    }

    // Swap current row with previous row
    int	*temp = curr;
    curr = prev;
    prev = temp;

    // Point to next character
    y += y_char_len;

    // This chunk of code represents a significant performance hit if used
    // in the case where there is no max_d bound.  This is probably not
    // because the max_d >= 0 test itself is expensive, but rather because
    // the possibility of needing to execute this code prevents tight
    // optimization of the loop as a whole.
    if (max_d >= 0)
    {
      // The "zero point" is the column of the current row where the
      // remaining portions of the strings are of equal length.  There
      // are (n - 1) characters in the target string, of which j have
      // been transformed.  There are (m - 1) characters in the source
      // string, so we want to find the value for zp where (n - 1) - j =
      // (m - 1) - zp.
      int zp = j - (n - m);

      // Check whether the stop column can slide left
      while (stop_column > 0)
      {
        int ii = stop_column - 1;
        int net_inserts = ii - zp;

        if (prev[ii] + (net_inserts > 0
          ? net_inserts * ins_c : -net_inserts * del_c) <= max_d)
          break;

        stop_column--;
      }

      // Check whether the start column can slide right
      while (start_column < stop_column)
      {
        int net_inserts = start_column - zp;

        if (prev[start_column] + (net_inserts > 0
          ? net_inserts * ins_c : -net_inserts * del_c) <= max_d)
          break;

        // We'll never again update these values, so we must make sure
        // there's nothing here that could confuse any future
        // iteration of the outer loop.
        prev[start_column] = max_d + 1;
        curr[start_column] = max_d + 1;

        if (start_column != 0)
          source += (s_char_len != NULL) ? s_char_len[start_column - 1] : 1;

        start_column++;
      }

      // If they cross, we're going to exceed the bound
      if (start_column >= stop_column)
        return max_d + 1;
    }
  }

  // Because the final value was swapped from the previous row to the
  // current row, that's where we'll find it.
  return prev[m - 1];
}
