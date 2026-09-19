import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final week = s.last7Days;
    final maxCount = week.fold<int>(0, (a, b) => math.max(a, b.count));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TỔNG QUAN', style: ts(12, w: w700, c: C.ink500, ls: 0.6)),
              Text('Học tiếng Trung', style: ts(24, w: w700, h: 1.3)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: C.amberBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.amber.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.local_fire_department_outlined, size: 16, color: C.amberText),
              const SizedBox(width: 6),
              Text('${s.streakDays} ngày', style: ts(14, w: w700, c: C.amberText)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _Stat('${s.notebook.length}', 'Từ đã lưu')),
          const SizedBox(width: 10),
          Expanded(child: _Stat('${s.notebookLearned}', 'Đã học')),
          const SizedBox(width: 10),
          Expanded(child: _Stat('${s.retentionRateIn(allCollectionId)}%', 'Tỷ lệ nhớ', color: C.green)),
        ]),
        const SizedBox(height: 20),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Flashcard hôm nay', style: ts(14, w: w700)),
            const SizedBox(height: 2),
            _GoalRow(
              glyph: '卡',
              title: 'Tất cả từ cá nhân',
              sub: '${s.dueCountIn(allCollectionId)} thẻ cần học · mới còn ${s.newRemainingToday}/${s.newPerDay}',
              onReview: () => s.startFlashcard(allCollectionId),
              divider: s.collections.isNotEmpty,
            ),
            for (var i = 0; i < s.collections.length && i < 3; i++)
              _GoalRow(
                glyph: '集',
                title: s.collections[i].name,
                sub: '${s.dueCountIn(s.collections[i].id)} thẻ cần học',
                onReview: () => s.startFlashcard(s.collections[i].id),
                divider: i < s.collections.length - 1 && i < 2,
              ),
            const SizedBox(height: 6),
            Btn.outline('Mở Flashcard', icon: Icons.style_outlined, full: true, onTap: () => s.selectModule(Module.flashcard)),
          ]),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hoạt động 7 ngày qua', style: ts(14, w: w700)),
            const SizedBox(height: 14),
            SizedBox(
              height: 90,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final d in week)
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: math.max(0.08, maxCount == 0 ? 0.0 : d.count / maxCount),
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 22),
                          decoration: const BoxDecoration(
                            color: C.primary,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 6),
            Row(children: [
              for (final d in week)
                Expanded(child: Text(d.label, textAlign: TextAlign.center, style: ts(10, c: C.ink500))),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        Btn.outline('Xem báo cáo học tập chi tiết', icon: Icons.bar_chart, full: true, onTap: () => s.openReports()),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, {this.color = C.ink900});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(children: [
          Text(value, style: ts(24, w: w700, c: color)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: ts(10, w: w700, c: C.ink500, ls: 0.5), textAlign: TextAlign.center),
        ]),
      );
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.glyph, required this.title, required this.sub, required this.onReview, this.divider = false});
  final String glyph;
  final String title;
  final String sub;
  final VoidCallback onReview;
  final bool divider;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: divider ? const BoxDecoration(border: Border(bottom: BorderSide(color: C.borderLight))) : null,
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: C.tableHeader, borderRadius: BorderRadius.circular(8)),
            child: Hz(glyph, size: 16, weight: w700, color: C.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, w: w600)),
              Text(sub, style: ts(12, c: C.ink500)),
            ]),
          ),
          Btn('Ôn tập', onTap: onReview, fontSize: 12, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        ]),
      );
}
