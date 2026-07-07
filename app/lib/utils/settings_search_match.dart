/// Typo-tolerant matcher for the Settings search bar.
///
/// Pure, dependency-free. Cascades from fast to slow:
///   1. substring match (fast path, handles the common case)
///   2. per-word: substring / subsequence ("perm rev" -> "Permission Review")
///   3. per-word: bounded Levenshtein distance for typo tolerance
///      (<=1 for 3-4 char words, <=2 for words >=5 chars; words under
///      3 chars require an exact match to avoid noisy false positives).
///
/// [query] must match every one of its whitespace-separated words against
/// [title] for the row to be considered a match.
bool matchesSettingsQuery(String query, String title) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final t = title.toLowerCase();

  if (t.contains(q)) return true;

  final titleWords = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final queryWords = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (queryWords.isEmpty) return true;

  return queryWords.every((qw) => _wordMatchesAny(qw, t, titleWords));
}

bool _wordMatchesAny(String queryWord, String fullTitle, List<String> titleWords) {
  if (fullTitle.contains(queryWord)) return true;
  for (final titleWord in titleWords) {
    if (titleWord.contains(queryWord)) return true;
    if (_isSubsequence(queryWord, titleWord)) return true;
    if (_withinTypoDistance(queryWord, titleWord)) return true;
  }
  return false;
}

/// True if every character of [needle] appears in [hay], in order
/// (not necessarily contiguous) — e.g. "ntf" is a subsequence of "notify".
bool _isSubsequence(String needle, String hay) {
  if (needle.isEmpty) return true;
  if (needle.length > hay.length) return false;
  var i = 0;
  for (var j = 0; j < hay.length && i < needle.length; j++) {
    if (hay[j] == needle[i]) i++;
  }
  return i == needle.length;
}

bool _withinTypoDistance(String a, String b) {
  final minLen = a.length < b.length ? a.length : b.length;
  final maxLen = a.length > b.length ? a.length : b.length;
  // ponytail: words under 3 chars skip fuzzy matching entirely — at that
  // length nearly everything is within edit distance 1 of everything else.
  if (minLen < 3) return a == b;
  final threshold = maxLen >= 5 ? 2 : 1;
  if (maxLen - minLen > threshold) return false;
  return _levenshtein(a, b) <= threshold;
}

int _levenshtein(String a, String b) {
  final la = a.length, lb = b.length;
  if (la == 0) return lb;
  if (lb == 0) return la;

  var prev = List<int>.generate(lb + 1, (i) => i);
  var curr = List<int>.filled(lb + 1, 0);

  for (var i = 1; i <= la; i++) {
    curr[0] = i;
    for (var j = 1; j <= lb; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      final deletion = prev[j] + 1;
      final insertion = curr[j - 1] + 1;
      final substitution = prev[j - 1] + cost;
      curr[j] = deletion < insertion
          ? (deletion < substitution ? deletion : substitution)
          : (insertion < substitution ? insertion : substitution);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[lb];
}
