import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';

bool _isHan(int rune) =>
    (rune >= 0x4E00 && rune <= 0x9FFF) || // chữ Hán thông dụng
    (rune >= 0x3400 && rune <= 0x4DBF) || // mở rộng A
    (rune >= 0x2E80 && rune <= 0x2FDF); // bộ thủ & biến thể

/// Câu chuyện ghi nhớ: tô màu các bộ phận trong ngoặc (thứ nhất đỏ, thứ hai
/// xanh lá, còn lại xanh dương) và cho bấm vào từng chữ Hán để mở từ điển.
class MnemonicText extends StatefulWidget {
  const MnemonicText(this.text, {super.key});
  final String text;

  @override
  State<MnemonicText> createState() => _MnemonicTextState();
}

class _MnemonicTextState extends State<MnemonicText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final base = ts(14, c: C.ink700, italic: true, h: 1.7);
    final chars = widget.text.runes.map(String.fromCharCode).toList();

    // Đánh số nhóm trong ngoặc để tô màu: nhóm 1 đỏ, nhóm 2 xanh lá, sau đó primary.
    var group = -1;
    var inGroup = false;
    final spans = <InlineSpan>[];
    final plain = StringBuffer();

    void flush() {
      if (plain.isEmpty) return;
      spans.add(TextSpan(text: plain.toString()));
      plain.clear();
    }

    for (final ch in chars) {
      if (ch == '(' || ch == '（') {
        inGroup = true;
        group++;
      }
      final color = !inGroup ? null : (group == 0 ? C.red : (group == 1 ? C.green : C.primary));
      if (_isHan(ch.runes.first)) {
        flush();
        final recognizer = TapGestureRecognizer()..onTap = () => s.openDictDetail(ch);
        _recognizers.add(recognizer);
        spans.add(TextSpan(
          text: ch,
          locale: const Locale('zh', 'CN'),
          recognizer: recognizer,
          style: base.copyWith(
            fontWeight: color == null ? w600 : w700,
            color: color ?? C.primary,
            decoration: TextDecoration.underline,
            decorationColor: (color ?? C.primary).withValues(alpha: 0.35),
          ),
        ));
      } else if (color != null) {
        flush();
        spans.add(TextSpan(text: ch, style: base.copyWith(fontWeight: w700, color: color)));
      } else {
        plain.write(ch);
      }
      if (ch == ')' || ch == '）') inGroup = false;
    }
    flush();

    return Text.rich(TextSpan(style: base, children: spans));
  }
}
