/// Chuẩn hoá từ khoá tìm kiếm.
///
/// Dữ liệu Hán Việt dùng kiểu bỏ dấu "mới" (hòa, thủy). Nhiều bàn phím gõ ra
/// kiểu "cũ" (hoà, thuỷ) nên đổi về cùng một kiểu trước khi so khớp.
String normalizeViQuery(String s) {
  var out = s;
  _oldToNew.forEach((from, to) {
    out = out.replaceAll(RegExp('(?<!q)$from'), to);
  });
  return out;
}

const _oldToNew = {
  'oà': 'òa', 'oá': 'óa', 'oả': 'ỏa', 'oã': 'õa', 'oạ': 'ọa',
  'oè': 'òe', 'oé': 'óe', 'oẻ': 'ỏe', 'oẽ': 'õe', 'oẹ': 'ọe',
  'uỳ': 'ùy', 'uý': 'úy', 'uỷ': 'ủy', 'uỹ': 'ũy', 'uỵ': 'ụy',
};

/// Bỏ dấu thanh pinyin: "nǚ ér" → "nu er" (khớp cột py_plain trong DB).
String stripTones(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    b.write(_toneless[ch] ?? ch);
  }
  return b.toString();
}

const _toneless = {
  'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a',
  'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e', 'ê': 'e',
  'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i',
  'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
  'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u',
  'ǖ': 'u', 'ǘ': 'u', 'ǚ': 'u', 'ǜ': 'u', 'ü': 'u',
  'ń': 'n', 'ň': 'n', 'ǹ': 'n', 'ḿ': 'm',
};
