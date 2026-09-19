import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/save_word_sheet.dart';

/// Module Flashcard — trang đầu: danh sách collection.
class FlashcardHomeScreen extends StatelessWidget {
  const FlashcardHomeScreen({super.key});

  Future<void> _create(BuildContext context, AppState s) async {
    final name = await promptCollectionName(context);
    if (name == null) return;
    final id = await s.createCollection(name);
    if (id != null) s.showToast('Đã tạo "$name". Thêm từ bằng nút lưu ở Từ điển, Bộ thủ, 3000 từ.');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return ListView(
      key: const PageStorageKey('flashcard-home'),
      padding: pagePad,
      children: [
        PageTitle(
          'Flashcard',
          trailing: IconButton(
            onPressed: () => s.openReports(back: Module.flashcard),
            icon: const Icon(Icons.bar_chart, color: C.primary, size: 22),
            tooltip: 'Báo cáo',
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(height: 2),
        Text('Học thẻ theo từng collection trong Từ cá nhân.', style: ts(11, c: C.ink500)),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.today_outlined, size: 20, color: C.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(TextSpan(style: ts(12, c: C.ink700), children: [
                const TextSpan(text: 'Thẻ mới còn lại hôm nay: '),
                TextSpan(text: '${s.newRemainingToday}/${s.newPerDay}', style: ts(12, w: w700)),
              ])),
            ),
            InkWell(
              onTap: () => s.go(Module.settings),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text('Đổi', style: ts(12, w: w700, c: C.primary)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        if (s.notebook.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            child: Column(children: [
              const Icon(Icons.style_outlined, size: 44, color: C.border),
              const SizedBox(height: 10),
              Text('Chưa có từ nào để học', style: ts(13, w: w700)),
              const SizedBox(height: 4),
              Text(
                'Mở Từ điển, Bộ thủ hoặc 3000 từ và nhấn "Thêm vào từ cá nhân". Từ đã lưu sẽ thành thẻ học ở đây.',
                textAlign: TextAlign.center,
                style: ts(12, c: C.ink500, h: 1.5),
              ),
            ]),
          )
        else ...[
          const SectionLabel('Collection'),
          _CollectionCard(id: allCollectionId, icon: Icons.bookmarks_outlined),
          for (final c in s.collections) _CollectionCard(id: c.id, icon: Icons.folder_outlined),
        ],
        const SizedBox(height: 6),
        Btn.outline('Tạo collection mới', icon: Icons.create_new_folder_outlined, full: true, onTap: () => _create(context, s)),
      ],
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.id, required this.icon});
  final String id;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final st = s.statsIn(id);
    final due = s.dueCountIn(id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => s.openCollection(id),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: C.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(s.collectionName(id),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, w: w700)),
            ),
            if (due > 0)
              Pill('$due cần học', bg: C.amberBg, fg: C.amberText, fontSize: 10)
            else if (st.total > 0)
              const Pill('Xong hôm nay', bg: C.greenBg, fg: C.green, fontSize: 10),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20, color: C.ink500),
          ]),
          const SizedBox(height: 8),
          Text(
            '${st.total} từ · ${st.mastered} thành thục · ${st.learning} đang học · ${st.fresh} chưa học',
            style: ts(11, c: C.ink500),
          ),
          const SizedBox(height: 8),
          _StatusBar(st),
        ]),
      ),
    );
  }
}

/// Thanh tỉ lệ Thành thục / Đang học / Chưa học.
class _StatusBar extends StatelessWidget {
  const _StatusBar(this.st, {this.height = 6});
  final CollectionStats st;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: st.total == 0
              ? const ColoredBox(color: C.tableHeader, child: SizedBox.expand())
              : Row(children: [
                  if (st.mastered > 0) Expanded(flex: st.mastered, child: ColoredBox(color: statusMeta['mastered']!.dot)),
                  if (st.learning > 0) Expanded(flex: st.learning, child: ColoredBox(color: statusMeta['learning']!.dot)),
                  if (st.fresh > 0) Expanded(flex: st.fresh, child: const ColoredBox(color: C.tableHeader)),
                ]),
        ),
      );
}

// ---------------------------------------------------------------- chi tiết collection
class CollectionDetailScreen extends StatelessWidget {
  const CollectionDetailScreen({super.key});

  Future<void> _menu(BuildContext context, AppState s, String id, String action) async {
    if (action == 'rename') {
      final name = await promptCollectionName(context, initial: s.collectionName(id), title: 'Đổi tên collection');
      if (name != null) await s.renameCollection(id, name);
    } else if (action == 'delete') {
      final ok = await confirmDialog(
        context,
        'Xóa collection "${s.collectionName(id)}"? Các từ vẫn được giữ trong Từ cá nhân.',
      );
      if (ok) await s.deleteCollection(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final id = s.selectedCollectionId;
    final entries = s.entriesIn(id);
    final st = s.statsIn(id);
    final due = s.dueCountIn(id);
    final isAll = id == allCollectionId;

    return ListView(
      padding: pagePad,
      children: [
        Row(children: [
          BackLink('Flashcard', onTap: s.flashToList),
          const Spacer(),
          if (!isAll)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: C.ink700),
              color: C.surface,
              onSelected: (a) => _menu(context, s, id, a),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text('Đổi tên', style: ts(13))),
                PopupMenuItem(value: 'delete', child: Text('Xóa collection', style: ts(13, c: C.red))),
              ],
            ),
        ]),
        const SizedBox(height: 8),
        Text(s.collectionName(id), style: ts(20, w: w700)),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              _Num('${st.total}', 'Tổng', C.ink900),
              _Num('${st.fresh}', 'Chưa học', statusMeta['new']!.text),
              _Num('${st.learning}', 'Đang học', statusMeta['learning']!.text),
              _Num('${st.mastered}', 'Thành thục', statusMeta['mastered']!.text),
            ]),
            const SizedBox(height: 12),
            _StatusBar(st, height: 8),
          ]),
        ),
        const SizedBox(height: 12),
        Btn(
          due > 0 ? 'Học ngay ($due thẻ)' : 'Hôm nay đã học xong',
          icon: Icons.style_outlined,
          full: true,
          bg: due > 0 ? C.primary : C.border,
          onTap: due > 0 ? () => s.startFlashcard(id) : null,
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Btn.outline(
              'Ôn toàn bộ (${st.total})',
              icon: Icons.shuffle,
              fontSize: 12,
              onTap: st.total == 0 ? null : () => s.startFlashcard(id, all: true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Btn.outline(
              'Báo cáo',
              icon: Icons.bar_chart,
              fontSize: 12,
              onTap: () => s.openReports(collectionId: id, back: Module.flashcard),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        SectionLabel('Từ trong collection (${entries.length})'),
        if (entries.isEmpty)
          EmptyNote(isAll
              ? 'Chưa có từ nào. Hãy lưu từ ở Từ điển, Bộ thủ hoặc 3000 từ.'
              : 'Collection đang trống. Khi lưu từ ở Từ điển, Bộ thủ, 3000 từ, hãy tích chọn "${s.collectionName(id)}".'),
        for (final e in entries) _EntryRow(e),
      ],
    );
  }
}

class _Num extends StatelessWidget {
  const _Num(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: ts(18, w: w700, c: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: ts(10, c: C.ink500)),
        ]),
      );
}

class _EntryRow extends StatelessWidget {
  const _EntryRow(this.e);
  final NotebookEntry e;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final status = s.statusOf(e.key);
    final ret = s.retentionOf(e.key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        onTap: () => showCollectionSheet(context, e.id),
        child: Row(children: [
          SizedBox(width: 44, child: Center(child: FittedBox(child: Hz(e.char, size: e.char.length > 1 ? 20 : 26)))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.hanViet, style: ts(13, w: w700, c: C.primary)),
              if (e.pinyin.isNotEmpty) Text(e.pinyin, style: ts(11, c: C.amberText, italic: true)),
              if (e.meaning.isNotEmpty)
                Text(e.meaning, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11, c: C.ink700)),
            ]),
          ),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Pill(statusMeta[status]!.label, bg: statusMeta[status]!.bg, fg: statusMeta[status]!.text),
            if (ret != null) ...[
              const SizedBox(height: 4),
              Text('Nhớ $ret%', style: ts(10, c: ret >= 75 ? C.green : C.red)),
            ],
          ]),
        ]),
      ),
    );
  }
}
