import 'package:flutter/material.dart';

import '../services/answer_comparison.dart';

/// Hiển thị một chuỗi kèm "dấu" từng ký tự cho thẻ đáp án màn Review:
/// - ký tự thiếu / gõ sai: gạch chân + màu nổi
/// - ký tự gõ thừa: gạch ngang + màu nổi
///
/// Không bao giờ crash: nếu [marks] không khớp [text] (dữ liệu lệch) thì render
/// chuỗi thường như [Text].
class AnswerDiffText extends StatelessWidget {
  final String text;

  /// Dấu theo từng ký tự, phải cùng thứ tự và cùng số ký tự với [text].
  final List<CharMark> marks;

  final TextStyle baseStyle;

  /// Màu cho ký tự lệch (mặc định đã đủ tương phản trên nền gradient).
  final Color mismatchColor;

  /// Cách gạch cho ký tự bị thay thế (đáp án: gạch chân, chuỗi đã gõ: gạch ngang).
  final TextDecoration replacedDecoration;

  final TextAlign textAlign;
  final int maxLines;

  const AnswerDiffText({
    super.key,
    required this.text,
    required this.marks,
    required this.baseStyle,
    required this.mismatchColor,
    this.replacedDecoration = TextDecoration.underline,
    this.textAlign = TextAlign.center,
    this.maxLines = 2,
  });

  /// Dấu chỉ dùng được khi dựng lại đúng chuỗi gốc (cùng số ký tự + cùng thứ tự).
  bool get _marksMatchText {
    if (marks.isEmpty) return false;
    if (marks.map((m) => m.char).join() != text) return false;
    return true;
  }

  TextStyle _styleFor(CharMarkKind kind) {
    switch (kind) {
      case CharMarkKind.keep:
        return baseStyle;
      case CharMarkKind.missing:
        return baseStyle.copyWith(
          color: mismatchColor,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.underline,
          decorationColor: mismatchColor,
          decorationThickness: 2,
          decorationStyle: TextDecorationStyle.dotted,
        );
      case CharMarkKind.extra:
        return baseStyle.copyWith(
          color: mismatchColor,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.lineThrough,
          decorationColor: mismatchColor,
          decorationThickness: 2,
        );
      case CharMarkKind.replaced:
        return baseStyle.copyWith(
          color: mismatchColor,
          fontWeight: FontWeight.w900,
          decoration: replacedDecoration,
          decorationColor: mismatchColor,
          decorationThickness: 2,
          decorationStyle: TextDecorationStyle.dotted,
        );
    }
  }

  /// Gom các ký tự liền kề cùng trạng thái thành 1 span để giảm số node
  /// (từ dài vẫn render mượt trên web/iPad).
  List<TextSpan> _buildSpans() {
    final spans = <TextSpan>[];
    var buffer = StringBuffer();
    var currentKind = marks.first.kind;

    void flush() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(text: buffer.toString(), style: _styleFor(currentKind)));
      buffer = StringBuffer();
    }

    for (final mark in marks) {
      if (mark.kind != currentKind) {
        flush();
        currentKind = mark.kind;
      }
      buffer.write(mark.char);
    }
    flush();
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    if (!_marksMatchText || marks.every((m) => m.kind == CharMarkKind.keep)) {
      return Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: _buildSpans()),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}