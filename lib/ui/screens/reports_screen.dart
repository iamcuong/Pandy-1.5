import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/export_service.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../widgets/common.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _busy = false;

  Future<void> _export(AppState s, {required bool pdf}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (pdf) s.showToast('Đang tạo báo cáo PDF...');
      final bytes = pdf ? await ExportService.buildPdf(s) : ExportService.buildCsv(s.reportRowsIn(s.reportsCollection));
      final name = pdf ? 'bao-cao-hoc-tap.pdf' : 'bao-cao-hoc-tap.csv';
      final saved = await ExportService.saveAndShare(
        fileName: name,
        mime: pdf ? 'application/pdf' : 'text/csv',
        bytes: bytes,
      );
      s.showToast(saved != null
          ? 'Đã lưu "$saved" vào Tải xuống'
          : 'Máy Android 9 trở xuống chưa lưu được vào Tải xuống');
    } catch (e) {
      s.showToast('Xuất báo cáo thất bại: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cid = s.reportsCollection;
    final chart = s.reportChart(s.reportsRange, collectionId: cid);
    final maxCount = chart.fold<int>(0, (a, b) => b.count > a ? b.count : a);
    final split = s.retentionSplitIn(cid);
    final weak = s.weakListIn(cid);
    final st = s.statsIn(cid);

    return ListView(
      padding: pagePad,
      children: [
        Row(children: [
          IconButton(
            onPressed: s.reportsGoBack,
            icon: const Icon(Icons.arrow_back, color: C.primary, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Text('Báo cáo học tập', style: ts(18, w: w700)),
        ]),
        const SizedBox(height: 10),
        HScroll(children: [
          FilterPill('Tất cả từ cá nhân', active: cid == allCollectionId, onTap: () => s.setReportsCollection(allCollectionId)),
          for (final c in s.collections)
            FilterPill(c.name, active: cid == c.id, onTap: () => s.setReportsCollection(c.id)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _StatTile('${st.total}', 'Tổng từ'),
          const SizedBox(width: 8),
          _StatTile('${st.learning}', 'Đang học', color: C.amberText),
          const SizedBox(width: 8),
          _StatTile('${st.mastered}', 'Thành thục', color: C.green),
          const SizedBox(width: 8),
          _StatTile('${s.retentionRateIn(cid)}%', 'Tỷ lệ nhớ', color: C.primary),
        ]),
        const SizedBox(height: 6),
        Text('${s.reviewsLast7DaysIn(cid)} lượt ôn trong 7 ngày qua · chuỗi ${s.streakDays} ngày học',
            style: ts(11, c: C.ink500)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: C.tableHeader, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            for (final e in rangeLabels.entries)
              Expanded(
                child: Box(
                  color: s.reportsRange == e.key ? C.primary : Colors.transparent,
                  radius: 6,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  onTap: () => s.setReportsRange(e.key),
                  child: Text(
                    e.value,
                    textAlign: TextAlign.center,
                    style: ts(12, w: w700, c: s.reportsRange == e.key ? Colors.white : C.ink700),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Số từ đã ôn', style: ts(14, w: w700)),
            const SizedBox(height: 14),
            SizedBox(
              height: 118,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final b in chart)
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('${b.count}', style: ts(10, w: w700, c: C.ink700)),
                      const SizedBox(height: 3),
                      Container(
                        width: 26,
                        height: 100 * (maxCount == 0 ? 0.08 : (b.count / maxCount).clamp(0.08, 1.0).toDouble()),
                        decoration: const BoxDecoration(
                          color: C.primaryDark,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 4),
            Row(children: [
              for (final b in chart)
                Expanded(child: Text(b.label, textAlign: TextAlign.center, style: ts(9, c: C.ink500))),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tỷ lệ nhớ / quên (SRS)', style: ts(14, w: w700)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                height: 14,
                child: split.hasData
                    ? Row(children: [
                        if (split.good > 0) Expanded(flex: split.good, child: const ColoredBox(color: C.green)),
                        if (split.bad > 0) Expanded(flex: split.bad, child: const ColoredBox(color: C.red)),
                      ])
                    : const ColoredBox(color: C.tableHeader, child: SizedBox.expand()),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 16, runSpacing: 4, children: [
              _legend(C.green, 'Nhớ tốt — ${split.good}%'),
              _legend(C.red, 'Cần ôn lại — ${split.bad}%'),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Từ còn yếu, cần ôn', style: ts(14, w: w700)),
            const SizedBox(height: 6),
            if (weak.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Không có mục nào — tuyệt vời!', style: ts(12, c: C.ink500)),
              ),
            for (var i = 0; i < weak.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: i == 0
                    ? null
                    : const BoxDecoration(border: Border(top: BorderSide(color: C.borderLight))),
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: C.pageBg,
                      border: Border.all(color: C.borderLight),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Hz(weak[i].char, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(weak[i].hanViet, style: ts(12, w: w600)),
                      Text(weak[i].typeLabel, style: ts(10, c: C.ink500)),
                    ]),
                  ),
                  Text('${weak[i].retention}%', style: ts(12, w: w700, c: C.red)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Btn.outline('Xuất CSV', icon: Icons.download, onTap: _busy ? null : () => _export(s, pdf: false)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Btn('Xuất PDF', icon: Icons.picture_as_pdf_outlined, onTap: _busy ? null : () => _export(s, pdf: true)),
          ),
        ]),
      ],
    );
  }

  static Widget _legend(Color c, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Dot(c),
        const SizedBox(width: 6),
        Text(text, style: ts(11, c: C.ink700)),
      ]);
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.value, this.label, {this.color = C.ink900});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Column(children: [
            FittedBox(child: Text(value, style: ts(18, w: w700, c: color))),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, maxLines: 1, style: ts(9, w: w600, c: C.ink500)),
          ]),
        ),
      );
}
