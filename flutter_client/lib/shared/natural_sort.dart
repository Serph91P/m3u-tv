/// Alphanumeric ("natural") string comparator: symbol-led names first, then
/// digit-led names, then letter-led names, and within each group, numeric
/// runs compare by value rather than lexically (`"2 Fast"` before
/// `"10 Things"`, not after). Matches the ordering scheme requested in
/// https://github.com/m3ue/m3u-tv/issues/285 for the Live TV channel list
/// ("special character first ... then by number ... then channels named
/// A-Z").
int compareNatural(String a, String b) {
  final groupCompare = _leadGroup(a).compareTo(_leadGroup(b));
  if (groupCompare != 0) return groupCompare;
  return _compareChunks(a, b);
}

/// 0 = leads with a non-alphanumeric character (or is empty), 1 = leads with
/// a digit, 2 = leads with a letter.
int _leadGroup(String s) {
  if (s.isEmpty) return 0;
  final code = s.codeUnitAt(0);
  const zero = 0x30;
  const nine = 0x39;
  const upperA = 0x41;
  const upperZ = 0x5a;
  const lowerA = 0x61;
  const lowerZ = 0x7a;
  if (code >= zero && code <= nine) return 1;
  if ((code >= upperA && code <= upperZ) ||
      (code >= lowerA && code <= lowerZ)) {
    return 2;
  }
  return 0;
}

final _chunkPattern = RegExp(r'\d+|\D+');

int _compareChunks(String a, String b) {
  final aChunks = _chunkPattern.allMatches(a).map((m) => m[0]!).toList();
  final bChunks = _chunkPattern.allMatches(b).map((m) => m[0]!).toList();
  final length = aChunks.length < bChunks.length
      ? aChunks.length
      : bChunks.length;
  for (var i = 0; i < length; i++) {
    final aChunk = aChunks[i];
    final bChunk = bChunks[i];
    final aNum = int.tryParse(aChunk);
    final bNum = int.tryParse(bChunk);
    final chunkCompare = aNum != null && bNum != null
        ? aNum.compareTo(bNum)
        : aChunk.toLowerCase().compareTo(bChunk.toLowerCase());
    if (chunkCompare != 0) return chunkCompare;
  }
  return aChunks.length.compareTo(bChunks.length);
}
