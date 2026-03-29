class EnglishContentNormalizer {
  static final RegExp _allowedEnglishChars = RegExp(
    "^[A-Za-z0-9\\s\\.,;:'\"!?()\\-_/&@#%+\\n\\r]*\$",
  );

  static String normalize(String input) {
    return input.replaceAll('\r\n', '\n').trim();
  }

  static bool isEnglishLike(String input) {
    final value = normalize(input);
    if (value.isEmpty) return true;
    return _allowedEnglishChars.hasMatch(value);
  }

  static bool areEnglishLike(Iterable<String> values) {
    for (final value in values) {
      if (!isEnglishLike(value)) return false;
    }
    return true;
  }
}
