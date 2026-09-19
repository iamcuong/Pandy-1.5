import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/listen_button.dart';
import '../widgets/mnemonic_text.dart';
import '../widgets/save_word_sheet.dart';

String hskLabel(int? hsk) => hsk == null ? 'TỪ ĐIỂN' : 'HSK$hsk';
Pair hskPair(int? hsk) => hskColors[hsk ?? 0] ?? hskColors[0]!;

class VocabListScreen extends StatefulWidget {
  const VocabListScreen({super.key});

  @override
  State<VocabListScreen> createState() => _VocabListScreenState();
}

class _VocabListScreenState extends State<VocabListScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.text = context.read<AppState>().vocabSearch;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final items = s.filteredVocab;

    return ListView(
      key: const PageStorageKey('vocab-list'),
      padding: pagePad,
      children: [
        PageTitle(
          '3000 Từ',
          trailing: IconButton(
            onPressed: () => s.go(Module.settings),
            icon: const Icon(Icons.tune, color: C.primary, size: 22),
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(height: 10),
        SearchField(controller: _search, hint: 'Tìm theo chữ Hán, pinyin, Hán Việt...', onChanged: s.setVocabSearch),
        const SizedBox(height: 12),
        ProgressCard(
          learned: s.vocabLearned,
          total: s.vocab.length,
          rightLabel: 'Đã lưu vào từ cá nhân:',
          rightValue: '${s.vocabSaved}',
        ),
        const SizedBox(height: 14),
        HScroll(children: [
          FilterPill('Tất cả', active: s.vocabHsk == null, onTap: () => s.setVocabHsk(null)),
          for (var h = 1; h <= 6; h++) FilterPill('HSK$h', active: s.vocabHsk == h, onTap: () => s.setVocabHsk(h)),
        ]),
        const SizedBox(height: 12),
        if (items.isEmpty) const EmptyNote('Không có từ nào phù hợp.'),
        for (final v in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              onTap: () => s.openVocab(v.id),
              child: Row(children: [
                SizedBox(width: 44, child: Center(child: Hz(v.char, size: 28))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(v.hanViet, style: ts(13, w: w700, c: C.primary))),
                      const SizedBox(width: 6),
                      Pill(hskLabel(v.hsk), bg: hskPair(v.hsk).bg, fg: hskPair(v.hsk).fg),
                    ]),
                    const SizedBox(height: 2),
                    Text('${v.pinyin} · ${v.meaning}',
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(11, c: C.ink500, italic: true)),
                  ]),
                ),
                const SizedBox(width: 8),
                Dot(statusMeta[s.charStatus(v.char)]!.dot),
              ]),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- chi tiết
class VocabDetailScreen extends StatelessWidget {
  const VocabDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final v = s.selectedVocab;
    if (v == null) return const EmptyNote('Không tìm thấy từ.');
    final hc = hskPair(v.hsk);

    return ListView(
      padding: pagePad,
      children: [
        Row(children: [
          BackLink('3000 từ', onTap: () => s.selectModule(Module.vocab)),
          const Spacer(),
          IconSquare(Icons.chevron_left, size: 36, bg: C.surface, border: C.border, onTap: () => s.vocabStep(-1)),
          const SizedBox(width: 8),
          IconSquare(Icons.chevron_right, size: 36, bg: C.surface, border: C.border, onTap: () => s.vocabStep(1)),
        ]),
        const SizedBox(height: 12),
        AppCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Pill('#${v.id}', bg: C.pageBg, fg: C.ink700, border: C.borderLight, fontSize: 10),
                  const SizedBox(width: 6),
                  Pill(hskLabel(v.hsk), bg: hc.bg, fg: hc.fg, fontSize: 10),
                ]),
                const SizedBox(height: 4),
                Hz(v.char, size: 64),
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                  Text(v.pinyin, style: ts(15, c: C.ink700, italic: true)),
                  ListenButton(text: v.char),
                ]),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 3, 10, 4),
                  decoration: BoxDecoration(color: hc.bg, borderRadius: BorderRadius.circular(4)),
                  child: Text(v.hanViet, style: ts(16, w: w700, c: hc.fg, ls: 0.5)),
                ),
                const SizedBox(height: 6),
                Text(v.meaning, style: ts(12, c: C.ink700, h: 1.4)),
              ]),
            ),
            const SizedBox(width: 14),
            _Illustration(image: v.image),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Câu chuyện ghi nhớ', style: ts(14, w: w700)),
            if (v.comps.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in v.comps) _CompChip(comp: c),
              ]),
            ],
            if ((v.mnemonic ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              MnemonicText(v.mnemonic!),
            ],
            if ((v.giaiThich ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(v.giaiThich!, style: ts(12, c: C.ink700, h: 1.6)),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        _RelatedTable(v: v),
        const SizedBox(height: 12),
        Btn('Tập viết', icon: Icons.edit_square, full: true, onTap: () => s.setWritingChar(v.char)),
        const SizedBox(height: 10),
        SaveWordButton(
          char: v.char,
          pinyin: v.pinyin,
          hanViet: v.hanViet,
          meaning: v.meaning,
          source: 'vocab',
        ),
      ],
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({this.image});
  final String? image;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: C.pageBg,
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.image_outlined, size: 28, color: C.border),
        const SizedBox(height: 4),
        Text('Hình minh họa', style: ts(10, c: C.ink500)),
      ]),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 135,
        height: 134,
        decoration: BoxDecoration(border: Border.all(color: C.borderLight), borderRadius: BorderRadius.circular(6)),
        child: (image ?? '').isEmpty
            ? placeholder
            : Image.asset(
                'assets/vocab_images/$image',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}

class _CompChip extends StatelessWidget {
  const _CompChip({required this.comp});
  final VocabComp comp;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final radical = comp.radicalId == null ? s.radicalForChar(comp.char) : s.radicalById[comp.radicalId];
    return Box(
      color: C.pageBg,
      borderColor: C.borderLight,
      radius: 8,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      onTap: () {
        if (radical != null) {
          s.openRadical(radical.id);
        } else {
          s.openDictDetail(comp.char);
        }
      },
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Hz(comp.char, size: 15),
        if (radical != null) ...[
          const SizedBox(width: 6),
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: C.tableHeader, shape: BoxShape.circle),
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Text('${radical.id}', style: ts(9, w: w700, c: C.primary)),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

class _RelatedTable extends StatelessWidget {
  const _RelatedTable({required this.v});
  final VocabItem v;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final showTrad = s.settings.showTraditional;
    const flex = [10, 10, 10, 14];

    Widget row(List<Widget> cells, {Color bg = C.surface, bool top = true, VoidCallback? onTap}) => Material(
          color: bg,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: top ? const BoxDecoration(border: Border(top: BorderSide(color: C.borderLight))) : null,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    flex: flex[i],
                    child: Padding(padding: const EdgeInsets.only(right: 6), child: cells[i]),
                  ),
              ]),
            ),
          ),
        );

    Widget head(String t) => Text(t, style: ts(10, w: w700, c: C.ink700, ls: 0.3));

    Widget dataRow(String char, String pinyin, String hv, String meaning, {Color bg = C.surface, VoidCallback? onTap}) =>
        row([
          Hz(char, size: 14),
          Text(pinyin, style: ts(11, c: C.ink700, italic: true)),
          Text(hv, style: ts(11, w: w700, c: C.redDark)),
          Text(meaning, style: ts(11, c: C.ink700)),
        ], bg: bg, onTap: onTap);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: C.border),
          borderRadius: BorderRadius.circular(4),
          boxShadow: cardShadow,
        ),
        child: Column(children: [
          row([head('CHỮ'), head('PINYIN'), head('HÁN VIỆT'), head('NGHĨA')], bg: C.tableHeader, top: false),
          dataRow(v.char, v.pinyin, v.hanViet, v.meaning, bg: C.rowHighlight),
          for (final r in v.related)
            dataRow(
              showTrad && (r.traditional ?? '').isNotEmpty ? '${r.char} 【${r.traditional}】' : r.char,
              r.pinyin,
              r.hanViet,
              r.meaning,
              onTap: s.vocabForChar(r.char) == null ? null : () => s.jumpToVocabByChar(r.char),
            ),
        ]),
      ),
    );
  }
}
