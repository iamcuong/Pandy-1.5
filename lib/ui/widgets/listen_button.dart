import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'common.dart';
import 'save_word_sheet.dart';

/// Nút "Nghe" — phát âm chữ Hán bằng giọng đọc của máy.
class ListenButton extends StatelessWidget {
  const ListenButton({super.key, required this.text, this.compact = false});
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return ValueListenableBuilder<bool>(
      valueListenable: s.tts.speaking,
      builder: (_, playing, __) => Box(
        color: playing ? C.blue100 : C.tableHeader,
        radius: 12,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 9, vertical: 4),
        onTap: () => s.speak(text),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(playing ? Icons.graphic_eq : Icons.volume_up_outlined, size: 14, color: C.primary),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text('Nghe', style: ts(10, w: w700, c: C.primary)),
          ],
        ]),
      ),
    );
  }
}

/// Nút bookmark: lưu vào Từ cá nhân rồi mở bảng chọn collection. Đã lưu → icon xanh lá.
class BookmarkButton extends StatelessWidget {
  const BookmarkButton({
    super.key,
    required this.char,
    required this.pinyin,
    required this.hanViet,
    required this.meaning,
    required this.source,
    this.size = 38,
  });

  final String char;
  final String pinyin;
  final String hanViet;
  final String meaning;
  final String source;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final saved = s.inNotebook(char);
    return Tooltip(
      message: saved ? 'Đã lưu · Chọn collection' : 'Thêm vào từ cá nhân',
      child: Box(
        width: size,
        height: size,
        radius: 8,
        color: saved ? C.greenBg : C.tableHeader,
        center: true,
        onTap: () => openSaveSheet(
          context,
          char: char,
          pinyin: pinyin,
          hanViet: hanViet,
          meaning: meaning,
          source: source,
        ),
        child: Icon(
          saved ? Icons.bookmark : Icons.bookmark_add_outlined,
          size: 20,
          color: saved ? C.green : C.primary,
        ),
      ),
    );
  }
}
