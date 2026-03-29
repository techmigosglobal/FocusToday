import 'package:flutter/material.dart';

/// Lightweight markdown renderer for app content.
/// Supports:
/// - **bold**
/// - *italic*
/// - unordered list lines: "- item" / "* item"
/// - ordered list lines: "1. item"
class MarkdownText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;

  const MarkdownText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    return RichText(
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      text: TextSpan(
        style: baseStyle,
        children: _buildMarkdownSpans(text, baseStyle),
      ),
    );
  }

  static List<InlineSpan> _buildMarkdownSpans(String raw, TextStyle base) {
    final spans = <InlineSpan>[];
    final lines = raw.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final unorderedMatch = RegExp(r'^\s*[-*]\s+(.*)$').firstMatch(line);
      final orderedMatch = RegExp(r'^\s*(\d+)\.\s+(.*)$').firstMatch(line);

      if (unorderedMatch != null) {
        spans.add(
          TextSpan(
            text: '\u2022 ',
            style: base.copyWith(fontWeight: FontWeight.w600),
          ),
        );
        spans.addAll(_parseInline(unorderedMatch.group(1) ?? '', base));
      } else if (orderedMatch != null) {
        final idx = orderedMatch.group(1) ?? '1';
        spans.add(
          TextSpan(
            text: '$idx. ',
            style: base.copyWith(fontWeight: FontWeight.w600),
          ),
        );
        spans.addAll(_parseInline(orderedMatch.group(2) ?? '', base));
      } else {
        spans.addAll(_parseInline(line, base));
      }

      if (i != lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    return spans;
  }

  static List<InlineSpan> _parseInline(String input, TextStyle base) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*)');
    var cursor = 0;

    for (final match in regex.allMatches(input)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: input.substring(cursor, match.start), style: base),
        );
      }

      final token = input.substring(match.start, match.end);
      if (token.startsWith('**') && token.endsWith('**') && token.length >= 4) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('*') &&
          token.endsWith('*') &&
          token.length >= 3) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else {
        spans.add(TextSpan(text: token, style: base));
      }
      cursor = match.end;
    }

    if (cursor < input.length) {
      spans.add(TextSpan(text: input.substring(cursor), style: base));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: input, style: base));
    }
    return spans;
  }
}
