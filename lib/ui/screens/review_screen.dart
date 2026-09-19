import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../widgets/common.dart';

const _rateButtons = [
  ('again', 'Quên', C.red),
  ('hard', 'Khó', C.amber),
  ('good', 'Tốt', C.green),
  ('easy', 'Dễ', C.primaryDark),
];

/// Phiên học Flashcard của một collection.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (s.reviewQueue.isEmpty) {
      return Padding(
        padding: pagePad,
        child: Column(children: [
          const EmptyNote('Không có mục nào cần ôn lúc này.'),
          Btn('Quay lại', onTap: s.reviewExit),
        ]),
      );
    }
    if (s.reviewDone) return _Done(stats: s.reviewStats, onDone: s.reviewExit);

    final total = s.reviewQueue.length;
    final card = s.currentCard;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconButton(
            onPressed: s.reviewExit,
            icon: const Icon(Icons.close, color: C.ink700),
            visualDensity: VisualDensity.compact,
            tooltip: 'Thoát',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(s.collectionName(s.reviewCollectionId),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, w: w700, c: C.primary)),
          ),
          Text('${s.reviewIndex + 1} / $total', style: ts(12, w: w700, c: C.ink500)),
        ]),
        const SizedBox(height: 6),
        Bar(s.reviewIndex / total, height: 5),
        const SizedBox(height: 16),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 280),
            child: Box(
              borderColor: C.border,
              radius: 8,
              shadow: cardShadow,
              onTap: s.reviewFlip,
              padding: const EdgeInsets.all(20),
              child: Center(
                child: card == null
                    ? Text('Mục này không còn tồn tại', style: ts(13, c: C.ink500))
                    : SingleChildScrollView(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          if (card.pinyin.isNotEmpty && !s.reviewFlipped)
                            Text(card.pinyin, style: ts(15, c: C.ink700, italic: true)),
                          FittedBox(child: Hz(card.char, size: 90)),
                          const SizedBox(height: 10),
                          if (!s.reviewFlipped)
                            Text('Chạm để lật thẻ', style: ts(12, c: C.ink500))
                          else ...[
                            if (card.pinyin.isNotEmpty) Text(card.pinyin, style: ts(15, c: C.ink700, italic: true)),
                            const SizedBox(height: 4),
                            Text(card.hanViet, textAlign: TextAlign.center, style: ts(19, w: w700, c: C.primary)),
                            const SizedBox(height: 4),
                            Text(card.meaning, textAlign: TextAlign.center, style: ts(13, c: C.ink700, h: 1.5)),
                          ],
                        ]),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 44,
          child: s.reviewFlipped
              ? Row(children: [
                  for (var i = 0; i < _rateButtons.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Btn(
                        _rateButtons[i].$2,
                        bg: _rateButtons[i].$3,
                        fontSize: 11,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                        onTap: () => s.rate(_rateButtons[i].$1),
                      ),
                    ),
                  ],
                ])
              : Center(child: Text('Lật thẻ để đánh giá mức độ nhớ', style: ts(11, c: C.ink500))),
        ),
      ]),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.stats, required this.onDone});
  final Map<String, int> stats;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 28),
        children: [
          const Icon(Icons.emoji_events_outlined, size: 52, color: C.green),
          const SizedBox(height: 10),
          Text('Hoàn thành phiên ôn tập!', textAlign: TextAlign.center, style: ts(17, w: w700)),
          const SizedBox(height: 20),
          AppCard(
            child: Row(children: [
              for (final b in _rateButtons)
                Expanded(
                  child: Column(children: [
                    Text('${stats[b.$1] ?? 0}', style: ts(18, w: w700, c: b.$3)),
                    const SizedBox(height: 2),
                    Text(b.$2, style: ts(10, c: C.ink500)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 20),
          Btn('Xong', full: true, onTap: onDone),
        ],
      );
}
