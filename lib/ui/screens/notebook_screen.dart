import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/save_word_sheet.dart';

class NotebookScreen extends StatelessWidget {
  const NotebookScreen({super.key});

  static const _filters = {'all': 'Tất cả', 'dictionary': 'Từ điển', 'radical': 'Bộ thủ', 'vocab': '3000 từ'};

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final all = s.notebook;
    final inCollection = s.collectionExists(s.notebookCollection) ? s.entriesIn(s.notebookCollection) : all;
    final items = s.notebookFilter == 'all'
        ? inCollection
        : inCollection.where((n) => n.source == s.notebookFilter).toList();

    return ListView(
      key: const PageStorageKey('notebook-list'),
      padding: pagePad,
      children: [
        const PageTitle('Từ cá nhân'),
        const SizedBox(height: 2),
        Text('Từ bạn lưu từ Từ điển, Bộ thủ và 3000 từ. Chạm vào từ để xếp vào collection.',
            style: ts(11, c: C.ink500)),
        const SizedBox(height: 12),
        ProgressCard(
          learned: s.notebookLearned,
          total: all.length,
          rightLabel: 'Cần học hôm nay:',
          rightValue: '${s.dueCountIn(allCollectionId)}',
        ),
        const SizedBox(height: 12),
        Btn('Mở Flashcard', icon: Icons.style_outlined, full: true, onTap: () => s.selectModule(Module.flashcard)),
        const SizedBox(height: 14),
        if (s.collections.isNotEmpty) ...[
          HScroll(children: [
            FilterPill('Mọi collection',
                active: s.notebookCollection == allCollectionId,
                onTap: () => s.setNotebookCollection(allCollectionId)),
            for (final c in s.collections)
              FilterPill(c.name, active: s.notebookCollection == c.id, onTap: () => s.setNotebookCollection(c.id)),
          ]),
          const SizedBox(height: 8),
        ],
        HScroll(children: [
          for (final e in _filters.entries)
            FilterPill(e.value, active: s.notebookFilter == e.key, onTap: () => s.setNotebookFilter(e.key)),
        ]),
        const SizedBox(height: 12),
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            child: Column(children: [
              const Icon(Icons.bookmarks_outlined, size: 44, color: C.border),
              const SizedBox(height: 10),
              Text('Chưa lưu từ nào', style: ts(13, w: w700)),
              const SizedBox(height: 4),
              Text(
                'Mở Từ điển, Bộ thủ hoặc 3000 từ và nhấn "Thêm vào từ cá nhân" để lưu từ vào đây.',
                textAlign: TextAlign.center,
                style: ts(12, c: C.ink500, h: 1.5),
              ),
            ]),
          )
        else if (items.isEmpty)
          const EmptyNote('Không có từ nào phù hợp bộ lọc.')
        else
          for (final n in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                onTap: () => showCollectionSheet(context, n.id),
                child: Row(children: [
                  SizedBox(width: 44, child: Center(child: Hz(n.char, size: n.char.length > 1 ? 20 : 28))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(n.hanViet, style: ts(13, w: w700, c: C.primary)),
                        Pill(
                          (sourceMeta[n.source] ?? sourceMeta['dictionary']!).label,
                          bg: (sourceMeta[n.source] ?? sourceMeta['dictionary']!).bg,
                          fg: (sourceMeta[n.source] ?? sourceMeta['dictionary']!).fg,
                        ),
                      ]),
                      if (n.pinyin.isNotEmpty) Text(n.pinyin, style: ts(11, c: C.amberText, italic: true)),
                      if (n.meaning.isNotEmpty)
                        Text(n.meaning, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(11, c: C.ink700)),
                      if (s.collectionsOf(n.id).isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.folder_outlined, size: 12, color: C.ink500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(s.collectionsOf(n.id).map((c) => c.name).join(' · '),
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(10, c: C.ink500)),
                          ),
                        ]),
                      ],
                    ]),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: statusMeta[s.statusOf(n.key)]!.label,
                    child: Dot(statusMeta[s.statusOf(n.key)]!.dot),
                  ),
                  IconButton(
                    onPressed: () => s.removeFromNotebook(n.id),
                    icon: const Icon(Icons.delete_outline, size: 20, color: C.red),
                    tooltip: 'Xóa khỏi Từ cá nhân',
                  ),
                ]),
              ),
            ),
        if (all.isNotEmpty) ...[
          const SizedBox(height: 10),
          Btn.outline(
            'Xóa toàn bộ Từ cá nhân',
            icon: Icons.delete_outline,
            full: true,
            fg: C.red,
            border: C.red.withValues(alpha: 0.4),
            onTap: () async {
              if (await confirmDialog(context, 'Xóa toàn bộ Từ cá nhân? Các collection sẽ trống.')) await s.clearNotebook();
            },
          ),
        ],
      ],
    );
  }
}
