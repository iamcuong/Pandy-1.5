import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/listen_button.dart';
import '../widgets/radical_art.dart';
import '../widgets/save_word_sheet.dart';

class RadicalsListScreen extends StatelessWidget {
  const RadicalsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final filtered = s.radicalFilter == 'all'
        ? s.radicals
        : s.radicals.where((r) => s.charStatus(r.char) == s.radicalFilter).toList();
    final groups = <int, List<Radical>>{};
    for (final r in filtered) {
      groups.putIfAbsent(r.strokes, () => []).add(r);
    }
    final strokes = groups.keys.toList()..sort();

    return ListView(
      key: const PageStorageKey('radicals-list'),
      padding: pagePad,
      children: [
        PageTitle(
          '214 Bộ Thủ',
          trailing: IconButton(
            onPressed: () => s.go(Module.settings),
            icon: const Icon(Icons.tune, color: C.primary, size: 22),
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(height: 10),
        ProgressCard(
          learned: s.radicalsLearned,
          total: s.radicals.length,
          rightLabel: 'Đã lưu vào từ cá nhân:',
          rightValue: '${s.radicalsSaved}',
        ),
        const SizedBox(height: 14),
        HScroll(children: [
          FilterPill('Tất cả', active: s.radicalFilter == 'all', onTap: () => s.setRadicalFilter('all')),
          FilterPill('Chưa học',
              active: s.radicalFilter == 'new', color: statusMeta['new']!.dot, onTap: () => s.setRadicalFilter('new')),
          FilterPill('Đang học',
              active: s.radicalFilter == 'learning',
              color: statusMeta['learning']!.dot,
              onTap: () => s.setRadicalFilter('learning')),
          FilterPill('Thành thục',
              active: s.radicalFilter == 'mastered',
              color: statusMeta['mastered']!.dot,
              onTap: () => s.setRadicalFilter('mastered')),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _SmallBtn('Mở tất cả', s.expandAllGroups),
          const SizedBox(width: 6),
          _SmallBtn('Thu gọn tất cả', s.collapseAllGroups),
        ]),
        const SizedBox(height: 4),
        if (strokes.isEmpty) const EmptyNote('Không có bộ thủ nào trong mục này.'),
        for (final k in strokes) ...[
          _GroupHeader(
            stroke: k,
            count: groups[k]!.length,
            collapsed: s.radCollapsed.contains(k),
            onTap: () => s.toggleStrokeGroup(k),
          ),
          if (!s.radCollapsed.contains(k))
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.05,
              padding: const EdgeInsets.only(bottom: 6),
              children: [for (final r in groups[k]!) _RadicalTile(r)],
            ),
        ],
      ],
    );
  }
}

class _SmallBtn extends StatelessWidget {
  const _SmallBtn(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Box(
        borderColor: C.border,
        radius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        onTap: onTap,
        child: Text(label, style: ts(10, w: w700, c: C.primary)),
      );
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.stroke, required this.count, required this.collapsed, required this.onTap});
  final int stroke;
  final int count;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Icon(collapsed ? Icons.chevron_right : Icons.expand_more, size: 20, color: C.primary),
            const SizedBox(width: 4),
            Text('$stroke NÉT', style: ts(12, w: w700, c: C.primary, ls: 0.5)),
            const SizedBox(width: 8),
            Text('$count bộ', style: ts(11, c: C.ink500)),
            const SizedBox(width: 10),
            const Expanded(child: Divider(height: 1, thickness: 1, color: C.borderLight)),
          ]),
        ),
      );
}

class _RadicalTile extends StatelessWidget {
  const _RadicalTile(this.r);
  final Radical r;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final status = s.charStatus(r.char);
    return Stack(children: [
      Positioned.fill(
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          onTap: () => s.openRadical(r.id),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Hz(r.char, size: 26),
            const Spacer(),
            Text(r.hanViet, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11, w: w700, c: C.primary)),
            Text(r.meaning, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(10, c: C.ink500)),
          ]),
        ),
      ),
      Positioned(top: 8, right: 8, child: IgnorePointer(child: Dot(statusMeta[status]!.dot, size: 7))),
    ]);
  }
}

// ---------------------------------------------------------------- chi tiết
class RadicalDetailScreen extends StatelessWidget {
  const RadicalDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final r = s.selectedRadical;
    if (r == null) return const EmptyNote('Không tìm thấy bộ thủ.');
    final meta = statusMeta[s.charStatus(r.char)]!;
    final related = s.vocab.where((v) => v.comps.any((c) => c.char == r.char || c.radicalId == r.id)).toList();

    return ListView(
      padding: pagePad,
      children: [
        Row(children: [
          BackLink('Bộ thủ', onTap: () => s.selectModule(Module.radicals)),
          const Spacer(),
          IconSquare(Icons.chevron_left, size: 36, bg: C.surface, border: C.border, onTap: () => s.radicalStep(-1)),
          const SizedBox(width: 8),
          IconSquare(Icons.chevron_right, size: 36, bg: C.surface, border: C.border, onTap: () => s.radicalStep(1)),
        ]),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Pill('SỐ ${r.id}/214',
                    bg: C.tableHeader, fg: C.ink500, fontSize: 11, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3)),
                const SizedBox(width: 8),
                Pill(meta.label,
                    bg: meta.bg, fg: meta.text, fontSize: 11, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3)),
              ]),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Hz(r.char, size: 80),
                const SizedBox(width: 20),
                RadicalArt(r),
              ]),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(r.pinyin, style: ts(15, c: C.ink700, italic: true)),
                  ListenButton(text: r.char),
                ],
              ),
              const SizedBox(height: 4),
              Text(r.hanViet, style: ts(20, w: w700, c: C.primary, ls: 0.5)),
              const SizedBox(height: 4),
              Text(r.meaning, textAlign: TextAlign.center, style: ts(13, c: C.ink700)),
              if ((r.variant ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(style: ts(11, c: C.ink500), children: [
                    const TextSpan(text: 'Dạng viết khi ghép chữ: '),
                    TextSpan(text: r.variant, locale: const Locale('zh', 'CN')),
                  ]),
                ),
              ],
              const SizedBox(height: 4),
              Text('${r.strokes} nét', style: ts(11, c: C.ink500)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Btn('Tập viết', icon: Icons.edit_square, full: true, onTap: () => s.setWritingChar(r.char)),
        const SizedBox(height: 10),
        SaveWordButton(
          char: r.char,
          pinyin: r.pinyin,
          hanViet: r.hanViet,
          meaning: r.meaning,
          source: 'radical',
        ),
        if (related.isNotEmpty) ...[
          const SizedBox(height: 14),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Chữ Hán liên quan dùng bộ thủ này', style: ts(14, w: w700)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final v in related)
                  Box(
                    color: C.pageBg,
                    borderColor: C.borderLight,
                    radius: 8,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    onTap: () => s.openVocab(v.id),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Hz(v.char, size: 16),
                      const SizedBox(width: 6),
                      Text(v.hanViet, style: ts(11, w: w600, c: C.primary)),
                    ]),
                  ),
              ]),
            ]),
          ),
        ],
      ],
    );
  }
}
