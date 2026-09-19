import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/listen_button.dart';
import '../widgets/stroke_writer.dart';

class WritingScreen extends StatefulWidget {
  const WritingScreen({super.key});

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen> {
  final _writer = StrokeWriterController();
  final _search = TextEditingController();
  String? _char;
  bool _active = false;
  bool _done = false;
  int _mistakes = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetFor(String ch) {
    _char = ch;
    _active = false;
    _done = false;
    _mistakes = 0;
  }

  void _startQuiz(AppState s) {
    if (!_writer.hasData) {
      s.showToast('Chưa có dữ liệu nét viết cho chữ này');
      return;
    }
    setState(() {
      _active = true;
      _done = false;
      _mistakes = 0;
    });
    _writer.startQuiz(
      onMistake: (n) => setState(() => _mistakes = n),
      onCorrectStroke: (n) => setState(() => _mistakes = n),
      onComplete: (n) {
        setState(() {
          _active = false;
          _done = true;
          _mistakes = n;
        });
        s.showToast('Hoàn thành luyện viết ${s.writingChar}');
      },
    );
  }

  void _reset() {
    _writer.cancelQuiz();
    setState(() {
      _active = false;
      _done = false;
      _mistakes = 0;
    });
  }

  Future<void> _openNotebookSheet(AppState s) async {
    final items = s.notebookSingleChars;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: C.overlay,
      builder: (_) => _NotebookPickerSheet(items: items),
    );
    if (!mounted || picked == null) return;
    s.setWritingChar(picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (_char != s.writingChar) _resetFor(s.writingChar);
    syncController(_search, s.writingQuery);
    final info = s.writingInfo(s.writingChar);
    final results = s.writingResults;
    final status = _done
        ? 'Đã hoàn thành'
        : (_active ? 'Đang luyện viết...' : 'Nhấn "Luyện viết theo nét" để bắt đầu');

    return ListView(
      padding: pagePad,
      // Khoá cuộn khi đang tô nét để thao tác vẽ dọc không làm trang cuộn.
      physics: _active ? const NeverScrollableScrollPhysics() : null,
      children: [
        Row(children: [
          Expanded(
            child: SearchField(
              controller: _search,
              hint: 'Tìm chữ Hán, âm Hán Việt hoặc pinyin',
              onChanged: s.setWritingQuery,
            ),
          ),
          const SizedBox(width: 8),
          IconSquare(
            Icons.bookmarks_outlined,
            size: 44,
            onTap: () => _openNotebookSheet(s),
          ),
        ]),
        if (s.writingQuery.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          if (s.writingSearching && results.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (results.isEmpty)
            Text('Không tìm thấy chữ phù hợp.', style: ts(12, c: C.ink500))
          else
            SizedBox(
              height: 62,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: results.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _ResultChip(entry: results[i], selected: results[i].word == s.writingChar),
              ),
            ),
        ],
        const SizedBox(height: 14),
        AppCard(
          child: Column(children: [
            Row(children: [
              Expanded(child: Text(status, style: ts(13, w: w700))),
              const SizedBox(width: 8),
              Btn(
                'Xem mẫu',
                icon: Icons.play_circle_outline,
                bg: C.tableHeader,
                fg: C.primary,
                fontSize: 11,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                onTap: () {
                  setState(() => _active = false);
                  _writer.animate();
                },
              ),
            ]),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (_, c) => StrokeWriter(
                char: s.writingChar,
                controller: _writer,
                size: c.maxWidth < 280 ? c.maxWidth : 280,
                padding: 24,
                drawingColor: C.primary,
                quizStrokeColor: C.primary,
                highlightColor: C.amber,
              ),
            ),
            const SizedBox(height: 8),
            Text('Dữ liệu nét viết chuẩn từ Make Me a Hanzi.', style: ts(10, c: C.ink500)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Btn.outline('Làm lại', icon: Icons.restart_alt, fg: C.ink700, onTap: _reset)),
              const SizedBox(width: 10),
              Expanded(child: Btn('Luyện viết theo nét', bg: C.green, onTap: () => _startQuiz(s))),
            ]),
            if (_active) ...[
              const SizedBox(height: 10),
              Text('Đang luyện — số lỗi: $_mistakes', style: ts(12, c: C.amberText)),
            ],
            if (_done) ...[
              const SizedBox(height: 10),
              Text('Hoàn thành! Tổng số lỗi: $_mistakes', style: ts(12, w: w700, c: C.green)),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (info != null) ...[
                  Text(info.hanViet, style: ts(13, w: w700, c: C.primary)),
                  const SizedBox(height: 2),
                  Text('${info.pinyin} · ${info.meaning}',
                      style: ts(11, c: C.ink500, italic: true)),
                ] else
                  Text('Chưa có thông tin cho chữ này', style: ts(12, c: C.ink500)),
              ]),
            ),
            const SizedBox(width: 8),
            ListenButton(text: s.writingChar),
            const SizedBox(width: 8),
            Btn.outline(
              'Từ điển',
              fontSize: 11,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              onTap: () => s.openDictDetail(s.writingChar),
            ),
          ]),
        ),
      ],
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.entry, required this.selected});
  final DictEntry entry;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final hv = splitReadings(entry.hv).firstOrNull ?? '';
    return Box(
      color: selected ? C.primary : C.surface,
      borderColor: selected ? C.primary : C.border,
      radius: 8,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      onTap: () => s.setWritingChar(entry.word),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Hz(entry.word, size: 22, color: selected ? Colors.white : C.ink900),
        Text(hv, style: ts(9, w: w600, c: selected ? Colors.white : C.ink500)),
      ]),
    );
  }
}

/// Chọn chữ từ Sổ từ vựng cá nhân để luyện viết.
class _NotebookPickerSheet extends StatelessWidget {
  const _NotebookPickerSheet({required this.items});
  final List<NotebookEntry> items;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7, maxWidth: 430),
      child: Container(
        decoration: const BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: modalShadow,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.borderLight))),
            child: Row(children: [
              Expanded(child: Text('Chọn chữ từ Sổ từ vựng', style: ts(15, w: w700))),
              IconSquare(
                Icons.close,
                size: 30,
                iconSize: 18,
                bg: C.pageBg,
                fg: C.ink700,
                onTap: () => Navigator.pop(context),
              ),
            ]),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: EmptyNote('Sổ từ vựng chưa có chữ đơn nào. Hãy thêm chữ từ Từ điển, Bộ thủ hoặc 3000 từ.'),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final n = items[i];
                  return AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    onTap: () => Navigator.pop(context, n.char),
                    child: Row(children: [
                      SizedBox(width: 40, child: Center(child: Hz(n.char, size: 24))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(n.hanViet, style: ts(12, w: w700, c: C.primary)),
                          if (n.meaning.isNotEmpty)
                            Text(n.meaning, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11, c: C.ink500)),
                        ]),
                      ),
                    ]),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }
}
