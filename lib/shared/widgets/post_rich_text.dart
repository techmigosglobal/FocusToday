import 'package:flutter/material.dart';

import 'markdown_text.dart';

/// Renders post text with priority to Quill delta content, with markdown fallback.
class PostRichText extends StatelessWidget {
  final String text;
  final List<dynamic>? delta;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;

  const PostRichText(
    this.text, {
    super.key,
    this.delta,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final spans = _buildDeltaSpans(baseStyle);

    if (spans == null || spans.isEmpty) {
      return MarkdownText(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
    }

    return RichText(
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }

  List<InlineSpan>? _buildDeltaSpans(TextStyle baseStyle) {
    final ops = delta;
    if (ops == null || ops.isEmpty) return null;

    final lines = <_DeltaLine>[];
    var current = _DeltaLine();

    try {
      for (final rawOp in ops) {
        if (rawOp is! Map) continue;
        final op = Map<String, dynamic>.from(rawOp);
        final insert = op['insert'];
        final attrsRaw = op['attributes'];
        final attrs = attrsRaw is Map
            ? Map<String, dynamic>.from(attrsRaw)
            : const <String, dynamic>{};

        if (insert is! String || insert.isEmpty) {
          continue;
        }

        final segments = insert.split('\n');
        for (var i = 0; i < segments.length; i++) {
          final chunk = segments[i];
          if (chunk.isNotEmpty) {
            current.children.add(
              TextSpan(text: chunk, style: _styleForAttrs(baseStyle, attrs)),
            );
          }

          if (i < segments.length - 1) {
            current.listType = _extractListType(attrs);
            lines.add(current);
            current = _DeltaLine();
          }
        }
      }

      if (current.children.isNotEmpty || lines.isEmpty) {
        lines.add(current);
      }
    } catch (_) {
      return null;
    }

    if (lines.isEmpty) return null;

    final rendered = <InlineSpan>[];
    var orderedIndex = 1;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final listType = line.listType;
      final lineChildren = <InlineSpan>[];

      if (listType == 'bullet') {
        orderedIndex = 1;
        lineChildren.add(
          TextSpan(
            text: '\u2022 ',
            style: baseStyle.copyWith(fontWeight: FontWeight.w600),
          ),
        );
      } else if (listType == 'ordered') {
        lineChildren.add(
          TextSpan(
            text: '$orderedIndex. ',
            style: baseStyle.copyWith(fontWeight: FontWeight.w600),
          ),
        );
        orderedIndex += 1;
      } else {
        orderedIndex = 1;
      }

      if (line.children.isEmpty) {
        lineChildren.add(TextSpan(text: '', style: baseStyle));
      } else {
        lineChildren.addAll(line.children);
      }

      rendered.add(TextSpan(style: baseStyle, children: lineChildren));
      if (i != lines.length - 1) {
        rendered.add(const TextSpan(text: '\n'));
      }
    }

    return rendered;
  }

  TextStyle _styleForAttrs(TextStyle base, Map<String, dynamic> attrs) {
    var style = base;
    if (attrs['bold'] == true) {
      style = style.copyWith(fontWeight: FontWeight.w700);
    }
    if (attrs['italic'] == true) {
      style = style.copyWith(fontStyle: FontStyle.italic);
    }
    return style;
  }

  String? _extractListType(Map<String, dynamic> attrs) {
    final list = attrs['list'];
    if (list == 'bullet' || list == 'ordered') {
      return list as String;
    }
    return null;
  }
}

class _DeltaLine {
  final List<InlineSpan> children = <InlineSpan>[];
  String? listType;
}
