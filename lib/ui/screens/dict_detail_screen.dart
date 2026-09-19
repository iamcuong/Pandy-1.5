import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/listen_button.dart';
import '../widgets/stroke_writer.dart';

const _tabs = {'chitiet': 'Chi tiết', 'cachviet': 'Cách viết', 'phantich': 'Phân tích', 'tughep': 'Từ ghép'};

/// Ký tự toán tử IDS — chỉ là "keo" cấu trúc, không phải bộ phận.
const _idsOperators = '⿰⿱⿲⿳⿴⿵⿶⿷⿸⿹⿺⿻';

List<String> componentsFromIds(String ch, String? ids) => (ids ?? '')
    .runes
    .map(String.fromCharCode)
    .where((c) => !_idsOperators.contains(c) && c != '？' && c != '?' && c != ch && c.trim().isNotEmpty)
    .toList();

class DictDetailScreen extends StatefulWidget {
  const DictDetailScreen({super.key});

  @override
  State<DictDetailScreen> createState() => _DictDetailScreenState();
}

class _DictDetailScreenState extends State<DictDetailScreen> {
  String? _char;
  Future<CharDetail?>? _detail;
  Future<List<DictEntry>>? _phrases;
  Future<List<String>>? _comps;
  final _writer = StrokeWriterController();

  void _ensure(AppState s) {
    final ch = s.selectedDictChar;
    if (ch == null || ch == _char) return;
    _char = ch;
    _detail = s.ref.charDetail(ch);
    _phrases = s.ref.phrasesContaining(ch);
    _comps = s.ref.ids(ch).then((ids) => componentsFromIds(ch, ids));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    _ensure(s);
    final ch = _char;
    if (ch == null) return const EmptyNote('Chưa chọn chữ nào.');

    return Column(children: [
      Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: C.surface,
          border: Border(bottom: BorderSide(color: C.borderLight)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            for (final e in _tabs.entries) ...[
              _TabItem(label: e.value, active: s.dictDetailTab == e.key, onTap: () => s.setDictDetailTab(e.key)),
              const SizedBox(width: 18),
            ],
          ]),
        ),
      ),
      Expanded(
        child: switch (s.dictDetailTab) {
          'cachviet' => _WritingTab(char: ch, controller: _writer),
          'phantich' => _AnalysisTab(char: ch, comps: _comps!),
          'tughep' => _PhrasesTab(char: ch, phrases: _phrases!),
          _ => _InfoTab(char: ch, detail: _detail!),
        },
      ),
    ]);
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: active ? C.primary : Colors.transparent, width: 2)),
          ),
          child: Text(label, style: ts(13, w: active ? w700 : w600, c: active ? C.primary : C.ink500)),
        ),
      );
}

Widget _loading() => const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
    );

// ---------------------------------------------------------------- Chi tiết
class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.char, required this.detail});
  final String char;
  final Future<CharDetail?> detail;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return FutureBuilder<CharDetail?>(
      future: detail,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return _loading();
        final d = snap.data;
        if (d == null) return const EmptyNote('Không có dữ liệu cho chữ này.');
        final readings = d.readings;
        final radical = d.radicalId == null ? null : s.radicalById[d.radicalId];

        return ListView(
          padding: pagePad,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: C.surface,
                  border: Border.all(color: C.primary, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Hz(char, size: 40),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _kv('Hán Việt: ', readings.isEmpty ? '—' : readings.first, C.primary),
                  const SizedBox(height: 4),
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                    _kv('Pinyin: ', d.pinyin.isEmpty ? '—' : d.pinyin, C.amberText),
                    ListenButton(text: char),
                  ]),
                  if (readings.length > 1) ...[
                    const SizedBox(height: 3),
                    Text('Âm khác: ${readings.skip(1).join(', ')}', style: ts(12, c: C.ink500)),
                  ],
                  const SizedBox(height: 6),
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                    if (radical != null)
                      Box(
                        color: C.pageBg,
                        borderColor: C.borderLight,
                        radius: 8,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        onTap: () => s.openRadical(radical.id),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('bộ ', style: ts(11, c: C.ink500)),
                          Hz(radical.char, size: 14),
                          const SizedBox(width: 4),
                          Text(radical.hanViet.toLowerCase(), style: ts(11, w: w600, c: C.primary)),
                        ]),
                      ),
                    if (d.strokeCount != null) Text('${d.strokeCount} nét', style: ts(11, c: C.ink500)),
                  ]),
                ]),
              ),
              const SizedBox(width: 8),
              BookmarkButton(
                char: char,
                pinyin: d.pinyin,
                hanViet: readings.isEmpty ? '' : readings.first,
                meaning: d.shortMean,
                source: 'dictionary',
              ),
            ]),
            const SizedBox(height: 18),
            const SectionLabel('Nghĩa'),
            AppCard(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: d.blocks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text('Chưa có nghĩa chi tiết.', style: ts(12, c: C.ink500)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [for (final b in d.blocks) _block(b)],
                    ),
            ),
          ],
        );
      },
    );
  }

  static Widget _kv(String k, String v, Color c) => Text.rich(TextSpan(style: ts(14, c: C.ink700), children: [
        TextSpan(text: k),
        TextSpan(text: v, style: ts(14, w: w700, c: c)),
      ]));

  static Widget _block(DetailBlock b) {
    switch (b.type) {
      case 'heading':
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(b.text ?? '', style: ts(13, w: w700, h: 1.45)),
        );
      case 'sub':
        return Padding(
          padding: const EdgeInsets.only(top: 6, left: 8),
          child: Text(b.text ?? '', style: ts(12, w: w600, c: C.ink700, h: 1.45)),
        );
      case 'note':
        return Padding(
          padding: const EdgeInsets.only(top: 4, left: 8),
          child: Text('§ ${b.text ?? ''}', style: ts(11, c: C.ink500, h: 1.45)),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(top: 6, left: 8),
          child: Container(
            padding: const EdgeInsets.only(left: 8),
            decoration: const BoxDecoration(border: Border(left: BorderSide(color: C.borderLight, width: 2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ((b.exChar ?? '').isNotEmpty) Hz(b.exChar!, size: 14, color: C.redDark),
              if ((b.exHv ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(b.exHv!, style: ts(12, w: w600, c: C.primary, h: 1.4)),
                ),
              if ((b.exMean ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(b.exMean!, style: ts(11, c: C.ink700, italic: true, h: 1.4)),
                ),
            ]),
          ),
        );
    }
  }
}

// ---------------------------------------------------------------- Cách viết
class _WritingTab extends StatelessWidget {
  const _WritingTab({required this.char, required this.controller});
  final String char;
  final StrokeWriterController controller;

  @override
  Widget build(BuildContext context) => ListView(
        padding: pagePad,
        children: [
          AppCard(
            child: Column(children: [
              StrokeWriter(char: char, controller: controller, size: 240, padding: 20),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconSquare(Icons.restart_alt, bg: C.pageBg, fg: C.ink700, onTap: controller.showCharacter),
                const SizedBox(width: 12),
                IconSquare(Icons.play_arrow, bg: C.primary, fg: Colors.white, onTap: controller.animate),
              ]),
              const SizedBox(height: 10),
              Text('Dữ liệu nét viết chuẩn từ Make Me a Hanzi.', style: ts(10, c: C.ink500)),
            ]),
          ),
        ],
      );
}

// ---------------------------------------------------------------- Phân tích
class _AnalysisTab extends StatelessWidget {
  const _AnalysisTab({required this.char, required this.comps});
  final String char;
  final Future<List<String>> comps;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return FutureBuilder<List<String>>(
      future: comps,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return _loading();
        final kids = snap.data ?? const [];
        return ListView(
          padding: pagePad,
          children: [
            AppCard(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
              child: Column(children: [
                // Ô gốc — bấm để về tab Chi tiết
                InkWell(
                  onTap: () => s.setDictDetailTab('chitiet'),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: C.pageBg,
                      border: Border.all(color: C.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(children: [
                      Hz(char, size: 28, color: C.redDark),
                      _HvText(char: char, size: 11),
                    ]),
                  ),
                ),
                if (kids.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'Chữ này không phân tách được thành bộ phận nhỏ hơn.',
                      textAlign: TextAlign.center,
                      style: ts(12, c: C.ink500),
                    ),
                  )
                else
                  _Children(chars: kids, parentPath: 'L', depth: 1),
              ]),
            ),
            const SizedBox(height: 12),
            Text(
              'Nhấn chữ gốc để về Chi tiết · nhấn bộ phận để xem chữ đó · nhấn + để mở cấu tạo nhỏ hơn',
              textAlign: TextAlign.center,
              style: ts(11, c: C.ink500, h: 1.5),
            ),
          ],
        );
      },
    );
  }
}

/// Hàng con: vạch dọc nối từ ô cha + đường ngang (border-top) + các bộ phận XẾP NGANG.
class _Children extends StatelessWidget {
  const _Children({required this.chars, required this.parentPath, required this.depth});
  final List<String> chars;
  final String parentPath;
  final int depth;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 1, height: depth == 1 ? 14 : 12, color: C.border),
        Container(
          padding: const EdgeInsets.only(top: 14),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.border))),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: depth == 1 ? 12 : 8,
            runSpacing: 10,
            children: [
              for (var i = 0; i < chars.length; i++)
                _DecompNode(char: chars[i], path: '$parentPath>$i${chars[i]}', depth: depth),
            ],
          ),
        ),
      ]);
}

class _DecompNode extends StatefulWidget {
  const _DecompNode({required this.char, required this.path, required this.depth});
  final String char;
  final String path; // state mở/đóng theo đường dẫn node, không theo chữ
  final int depth;

  @override
  State<_DecompNode> createState() => _DecompNodeState();
}

class _DecompNodeState extends State<_DecompNode> {
  late Future<List<String>> _kids;

  @override
  void initState() {
    super.initState();
    _kids = _loadKids();
  }

  @override
  void didUpdateWidget(_DecompNode old) {
    super.didUpdateWidget(old);
    if (old.char != widget.char || old.depth != widget.depth) _kids = _loadKids();
  }

  Future<List<String>> _loadKids() async {
    if (widget.depth >= 4) return const [];
    final ref = context.read<AppState>().ref;
    return componentsFromIds(widget.char, await ref.ids(widget.char));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final d = widget.depth;
    final charSize = switch (d) { 1 => 22.0, 2 => 18.0, 3 => 16.0, _ => 14.0 };
    final bg = d == 1 ? C.surface : C.pageBg;
    final border = d == 1 ? C.border : C.borderLight;
    final color = d == 1 ? C.ink900 : C.red;
    final btn = d == 1 ? 20.0 : 16.0;

    return FutureBuilder<List<String>>(
      future: _kids,
      builder: (context, snap) {
        final kids = snap.data ?? const [];
        final expanded = kids.isNotEmpty && s.decompExpanded.contains(widget.path);
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Material(
              color: bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: border)),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => s.openDictDetail(widget.char),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: d == 1 ? 12 : 9, vertical: d == 1 ? 6 : 5),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Hz(widget.char, size: charSize, color: color),
                    _HvText(char: widget.char, size: d == 1 ? 10 : 9),
                  ]),
                ),
              ),
            ),
            if (kids.isNotEmpty)
              Positioned(
                top: d == 1 ? -8 : -7,
                right: d == 1 ? -8 : -7,
                child: GestureDetector(
                  onTap: () => s.toggleDecomp(widget.path),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: btn,
                    height: btn,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: C.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: C.primary),
                    ),
                    child: Icon(expanded ? Icons.remove : Icons.add, size: btn - 6, color: C.primary),
                  ),
                ),
              ),
          ]),
          if (expanded) _Children(chars: kids, parentPath: widget.path, depth: d + 1),
        ]);
      },
    );
  }
}

class _HvText extends StatefulWidget {
  const _HvText({required this.char, required this.size});
  final String char;
  final double size;

  @override
  State<_HvText> createState() => _HvTextState();
}

class _HvTextState extends State<_HvText> {
  String _hv = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_HvText old) {
    super.didUpdateWidget(old);
    if (old.char != widget.char) _load();
  }

  Future<void> _load() async {
    final s = context.read<AppState>();
    final ch = widget.char;
    var hv = await s.ref.firstReading(ch);
    if (hv.isEmpty) hv = s.radicalForChar(ch)?.hanViet.toLowerCase() ?? '';
    if (mounted && ch == widget.char) setState(() => _hv = hv);
  }

  @override
  Widget build(BuildContext context) => Text(_hv, style: ts(widget.size, c: C.ink700));
}

// ---------------------------------------------------------------- Từ ghép
class _PhrasesTab extends StatelessWidget {
  const _PhrasesTab({required this.char, required this.phrases});
  final String char;
  final Future<List<DictEntry>> phrases;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<DictEntry>>(
        future: phrases,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return _loading();
          final list = snap.data ?? const [];
          if (list.isEmpty) return const EmptyNote('Chưa tìm thấy từ ghép chứa chữ này.');
          return ListView.separated(
            padding: pagePad,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = list[i];
              return AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text.rich(
                      TextSpan(children: [
                        for (final c in p.word.runes.map(String.fromCharCode))
                          TextSpan(
                            text: c,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: w700,
                              color: c == char ? C.redDark : C.ink900,
                            ),
                          ),
                      ]),
                      locale: const Locale('zh', 'CN'),
                    ),
                    const SizedBox(height: 2),
                    Text(p.hv, style: ts(12, w: w600, c: C.primary)),
                    if (p.pinyin.isNotEmpty) Text(p.pinyin, style: ts(11, c: C.amberText, italic: true)),
                    if (p.meaning.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(p.meaning, style: ts(11, c: C.ink700, h: 1.4)),
                      ),
                  ]),
                ),
              );
            },
          );
        },
      );
}
