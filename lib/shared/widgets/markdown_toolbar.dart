import 'package:flutter/material.dart';

/// Text controller that renders markdown styling directly in [TextField]/
/// [TextFormField] while keeping the raw markdown text.
class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    return TextSpan(
      style: baseStyle,
      children: _buildMarkdownSpans(text, baseStyle),
    );
  }

  List<InlineSpan> _buildMarkdownSpans(String raw, TextStyle base) {
    final spans = <InlineSpan>[];
    final lines = raw.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final unorderedMatch = RegExp(r'^\s*([-*]\s+)').firstMatch(line);
      final orderedMatch = RegExp(r'^\s*(\d+\.\s+)').firstMatch(line);

      if (unorderedMatch != null) {
        final prefix = unorderedMatch.group(1) ?? '';
        spans.add(
          TextSpan(
            text: prefix,
            style: base.copyWith(fontWeight: FontWeight.w600),
          ),
        );
        spans.addAll(_parseInline(line.substring(prefix.length), base));
      } else if (orderedMatch != null) {
        final prefix = orderedMatch.group(1) ?? '';
        spans.add(
          TextSpan(
            text: prefix,
            style: base.copyWith(fontWeight: FontWeight.w600),
          ),
        );
        spans.addAll(_parseInline(line.substring(prefix.length), base));
      } else {
        spans.addAll(_parseInline(line, base));
      }

      if (i != lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    return spans;
  }

  List<InlineSpan> _parseInline(String input, TextStyle base) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'(\*\*[^*\n]+\*\*|\*[^*\n]+\*)');
    var cursor = 0;

    for (final match in regex.allMatches(input)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: input.substring(cursor, match.start), style: base),
        );
      }

      final token = input.substring(match.start, match.end);
      if (token.startsWith('**') && token.endsWith('**') && token.length >= 4) {
        spans.add(TextSpan(text: '**', style: base));
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        );
        spans.add(TextSpan(text: '**', style: base));
      } else if (token.startsWith('*') &&
          token.endsWith('*') &&
          token.length >= 3) {
        spans.add(TextSpan(text: '*', style: base));
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
        spans.add(TextSpan(text: '*', style: base));
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

/// Compact markdown toolbar for content creation.
/// Actions: bold, italic, unordered list, ordered list.
class MarkdownToolbar extends StatelessWidget {
  final TextEditingController controller;

  const MarkdownToolbar({super.key, required this.controller});

  void _toggleInline(String left, String right) {
    final value = controller.value;
    final text = value.text;
    final selection = value.selection;

    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final selStart = start < end ? start : end;
    final selEnd = end > start ? end : start;

    final hasSelection = selStart != selEnd;
    final isWrapped = _isWrapped(text, selStart, selEnd, left, right);

    if (hasSelection && isWrapped) {
      final updated = text.replaceRange(selEnd, selEnd + right.length, '');
      final updatedWithoutLeft = updated.replaceRange(
        selStart - left.length,
        selStart,
        '',
      );
      controller.value = value.copyWith(
        text: updatedWithoutLeft,
        selection: TextSelection(
          baseOffset: selStart - left.length,
          extentOffset: selEnd - left.length - right.length,
        ),
        composing: TextRange.empty,
      );
      return;
    }

    if (!hasSelection) {
      final canUnwrapAtCursor =
          selStart >= left.length &&
          selStart + right.length <= text.length &&
          text.substring(selStart - left.length, selStart) == left &&
          text.substring(selStart, selStart + right.length) == right;
      if (canUnwrapAtCursor) {
        final updated = text.replaceRange(
          selStart,
          selStart + right.length,
          '',
        );
        final updatedWithoutLeft = updated.replaceRange(
          selStart - left.length,
          selStart,
          '',
        );
        controller.value = value.copyWith(
          text: updatedWithoutLeft,
          selection: TextSelection.collapsed(offset: selStart - left.length),
          composing: TextRange.empty,
        );
        return;
      }
      final replacement = '$left$right';
      final updated = text.replaceRange(selStart, selEnd, replacement);
      controller.value = value.copyWith(
        text: updated,
        selection: TextSelection.collapsed(offset: selStart + left.length),
        composing: TextRange.empty,
      );
      return;
    }

    final selected = text.substring(selStart, selEnd);
    final replacement = '$left$selected$right';
    final updated = text.replaceRange(selStart, selEnd, replacement);
    controller.value = value.copyWith(
      text: updated,
      selection: TextSelection(
        baseOffset: selStart + left.length,
        extentOffset: selEnd + left.length,
      ),
      composing: TextRange.empty,
    );
  }

  void _applyList({required bool ordered}) {
    final value = controller.value;
    final text = value.text;
    final selection = value.selection;

    final selStart = selection.start < 0 ? text.length : selection.start;
    final selEnd = selection.end < 0 ? text.length : selection.end;

    final blockStart = text.lastIndexOf('\n', selStart > 0 ? selStart - 1 : 0);
    final from = blockStart == -1 ? 0 : blockStart + 1;
    final blockEnd = text.indexOf('\n', selEnd);
    final to = blockEnd == -1 ? text.length : blockEnd;

    final segment = text.substring(from, to);
    final lines = segment.split('\n');
    final listPrefixPattern = RegExp(r'^\s*(?:[-*]|\d+\.)\s+');
    final orderedPrefixPattern = RegExp(r'^\s*\d+\.\s+');
    final unorderedPrefixPattern = RegExp(r'^\s*[-*]\s+');

    final nonEmptyLines = lines.where((line) => line.trim().isNotEmpty);
    final shouldRemove =
        nonEmptyLines.isNotEmpty &&
        nonEmptyLines.every(
          (line) => ordered
              ? orderedPrefixPattern.hasMatch(line)
              : unorderedPrefixPattern.hasMatch(line),
        );

    final transformed = <String>[];

    var orderIndex = 1;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        transformed.add(line);
      } else if (shouldRemove) {
        transformed.add(line.replaceFirst(listPrefixPattern, ''));
      } else if (ordered) {
        final content = line.replaceFirst(listPrefixPattern, '');
        transformed.add('${orderIndex++}. $content');
      } else {
        final content = line.replaceFirst(listPrefixPattern, '');
        transformed.add('- $content');
      }
    }

    final replacement = transformed.join('\n');
    final updated = text.replaceRange(from, to, replacement);
    final newSelectionEnd = from + replacement.length;

    controller.value = value.copyWith(
      text: updated,
      selection: TextSelection(baseOffset: from, extentOffset: newSelectionEnd),
      composing: TextRange.empty,
    );
  }

  bool _isWrapped(
    String text,
    int selStart,
    int selEnd,
    String left,
    String right,
  ) {
    if (selStart < left.length || selEnd + right.length > text.length) {
      return false;
    }
    return text.substring(selStart - left.length, selStart) == left &&
        text.substring(selEnd, selEnd + right.length) == right;
  }

  bool _isInlineActive(String left, String right) {
    final value = controller.value;
    final text = value.text;
    final selection = value.selection;
    if (!selection.isValid) return false;

    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final selStart = start < end ? start : end;
    final selEnd = end > start ? end : start;

    if (selStart != selEnd) {
      return _isWrapped(text, selStart, selEnd, left, right);
    }

    return selStart >= left.length &&
        selStart + right.length <= text.length &&
        text.substring(selStart - left.length, selStart) == left &&
        text.substring(selStart, selStart + right.length) == right;
  }

  bool _isListActive({required bool ordered}) {
    final value = controller.value;
    final text = value.text;
    final selection = value.selection;
    if (!selection.isValid) return false;

    final cursor = selection.start < 0 ? text.length : selection.start;
    final blockStart = text.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0);
    final from = blockStart == -1 ? 0 : blockStart + 1;
    final blockEnd = text.indexOf('\n', cursor);
    final to = blockEnd == -1 ? text.length : blockEnd;
    final line = text.substring(from, to);

    return ordered
        ? RegExp(r'^\s*\d+\.\s+').hasMatch(line)
        : RegExp(r'^\s*[-*]\s+').hasMatch(line);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, _, _) {
        final defaultIconColor = Theme.of(context).iconTheme.color;
        final activeColor = Theme.of(context).colorScheme.primary;
        return Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Bold',
              icon: const Icon(Icons.format_bold_rounded),
              color: _isInlineActive('**', '**')
                  ? activeColor
                  : defaultIconColor,
              onPressed: () => _toggleInline('**', '**'),
            ),
            IconButton(
              tooltip: 'Italic',
              icon: const Icon(Icons.format_italic_rounded),
              color: _isInlineActive('*', '*') ? activeColor : defaultIconColor,
              onPressed: () => _toggleInline('*', '*'),
            ),
            IconButton(
              tooltip: 'Bullet list',
              icon: const Icon(Icons.format_list_bulleted_rounded),
              color: _isListActive(ordered: false)
                  ? activeColor
                  : defaultIconColor,
              onPressed: () => _applyList(ordered: false),
            ),
            IconButton(
              tooltip: 'Numbered list',
              icon: const Icon(Icons.format_list_numbered_rounded),
              color: _isListActive(ordered: true)
                  ? activeColor
                  : defaultIconColor,
              onPressed: () => _applyList(ordered: true),
            ),
          ],
        );
      },
    );
  }
}
