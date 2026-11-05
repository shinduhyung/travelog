/// Firebase Storage 파일 이름 만들기.
/// ranked_cities, new_countrydex 쪽 사진은 악센트 글자를 알파벳으로 바꾼 이름으로 올라간다
/// (São Paulo -> sao_paulo). 예전 방식(악센트 글자를 지움: so_paulo)으로 올라간 파일은
/// [legacySnake]로 한 번 더 찾는다.
library;

const _accentFold = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
  'ç': 'c', 'ć': 'c', 'č': 'c', 'ď': 'd', 'đ': 'd',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ě': 'e', 'ę': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ı': 'i',
  'ł': 'l', 'ń': 'n', 'ñ': 'n', 'ň': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ő': 'o',
  'ř': 'r', 'ś': 's', 'š': 's', 'ş': 's', 'ș': 's', 'ß': 'ss',
  'ť': 't', 'ţ': 't', 'ț': 't',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u',
  'ý': 'y', 'ÿ': 'y', 'ź': 'z', 'ż': 'z', 'ž': 'z',
};

String _snakeOf(String s) => s
    .replaceAll(RegExp(r"[''`’]"), '')
    .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
    .trim()
    .replaceAll(RegExp(r'\s+'), '_');

/// 악센트를 알파벳으로 바꾼 이름 (São Paulo -> sao_paulo)
String foldedSnake(String name) {
  final b = StringBuffer();
  for (final r in name.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    b.write(_accentFold[ch] ?? ch);
  }
  return _snakeOf(b.toString());
}

/// 예전 방식: 알파벳이 아닌 글자는 그냥 지운다 (São Paulo -> so_paulo)
String legacySnake(String name) => _snakeOf(name.toLowerCase());
