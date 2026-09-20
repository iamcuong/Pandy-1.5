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

/// Trạng thái khung luyện viết — mỗi trạng thái chỉ có một nút chính.
enum _Phase { idle, writing, done }

class _WritingScreenState extends State<WritingScreen> {
  final _writer = StrokeWriterController();
  final _search = TextEditingController();
  String? _char;
  _Phase _phase = _Phase.idle;
  int _mistakes = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetFor(String ch) {
    _char = ch;
    _phase = _Phase.idle;
    _mistakes = 0;
  }

  /// Bắt đầu (hoặc bắt đầu lại) lượt viết: xoá nét cũ, khung trống.
  void _startQuiz(AppState s) {
    if (!_writer.hasData) {
      s.showToast('Chưa có dữ liệu nét viết cho chữ này');
      return;
    }
    setState(() {
      _phase = _Phase.writing;
      _mistakes = 0;
    });
    _writer.startQuiz(
      onMistake: (n) {
        if (mounted) setState(() => _mistakes = n);
      },
      onCorrectStroke: (n) {
        if (mounted) setState(() => _mistakes = n);
      },
      onComplete: (n) {
        if (!mounted) return;
        setState(() {
          _phase = _Phase.done;
          _mistakes = n;
        });
      },
    );
  }

  void _showModel() {
    _writer.animate();
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
    return ListView(
      padding: pagePad,
      // Khoá cuộn khi đang tô nét để thao tác vẽ dọc không làm trang cuộn.
      physics: _phase == _Phase.writing ? const NeverScrollableScrollPhysics() : null,
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
            _StatusLine(
              phase: _phase,
              mistakes: _mistakes,
              done: _writer.strokesDone,
              total: _writer.strokeCount,
            ),
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
                onLoaded: (_) {
                  if (mounted) setState(() {});
                },
              ),
            ),
            const SizedBox(height: 14),
            _actions(s),
            const SizedBox(height: 10),
            Text('Dữ liệu nét viết chuẩn từ Make Me a Hanzi.', style: ts(10, c: C.ink500)),
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

extension on _WritingScreenState {
  /// Nút theo trạng thái: luôn chỉ một nút chính (đặc) và tối đa một nút phụ.
  Widget _actions(AppState s) {
    const small = EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    switch (_phase) {
      case _Phase.idle:
        return Row(children: [
          Expanded(
            flex: 2,
            child: Btn.outline('Xem mẫu', icon: Icons.play_circle_outline, fontSize: 12, padding: small, onTap: _showModel),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Btn('Bắt đầu luyện viết', icon: Icons.edit_outlined, bg: C.green, onTap: () => _startQuiz(s)),
          ),
        ]);
      case _Phase.writing:
        return Row(children: [
          Expanded(
            child: Btn.outline(
              'Xoá & viết lại',
              icon: Icons.backspace_outlined,
              fg: C.ink700,
              fontSize: 12,
              padding: small,
              onTap: () => _startQuiz(s),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Btn(
              'Gợi ý nét',
              icon: Icons.lightbulb_outline,
              bg: C.amberBg,
              fg: C.amberText,
              fontSize: 12,
              padding: small,
              onTap: _writer.hint,
            ),
          ),
        ]);
      case _Phase.done:
        return Row(children: [
          Expanded(
            flex: 2,
            child: Btn.outline('Luyện lại', icon: Icons.replay, fontSize: 12, padding: small, onTap: () => _startQuiz(s)),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Btn('Chữ tiếp theo →', bg: C.green, onTap: s.nextWritingChar),
          ),
        ]);
    }
  }
}

/// Dòng trạng thái phía trên khung viết.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.phase, required this.mistakes, required this.done, required this.total});
  final _Phase phase;
  final int mistakes;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String title, String sub) = switch (phase) {
      _Phase.idle => (Icons.visibility_outlined, C.primary, 'Sẵn sàng', 'Xem mẫu thứ tự nét, rồi bắt đầu viết.'),
      _Phase.writing => (
          Icons.edit_outlined,
          C.amberText,
          'Đang viết · nét ${done < total ? done + 1 : total}/$total',
          mistakes == 0 ? 'Chưa sai nét nào' : 'Số lần sai: $mistakes',
        ),
      _Phase.done => (
          Icons.check_circle_outline,
          C.green,
          'Hoàn thành!',
          mistakes == 0 ? 'Không sai nét nào — rất tốt!' : 'Tổng số lần sai: $mistakes',
        ),
    };
    return Row(children: [
      Icon(icon, size: 22, color: color),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: ts(13, w: w700, c: color)),
          Text(sub, style: ts(11, c: C.ink500)),
        ]),
      ),
    ]);
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
