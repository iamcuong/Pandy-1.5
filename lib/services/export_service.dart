import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../state/app_state.dart';
import 'platform_services.dart';

/// Xuất báo cáo: lưu vào thư mục Tải xuống (MediaStore, Android 10+) rồi mở share sheet.
class ExportService {
  static const MethodChannel nativeChannel = MethodChannel('vn.hoctiengtrung.app/export');
  /// Lưu vào thư mục Tải xuống (MediaStore) rồi mở menu chia sẻ.
  /// Trả về tên file đã lưu; null nếu máy chạy Android 9 trở xuống.
  static Future<String?> saveAndShare({
    required String fileName,
    required String mime,
    required Uint8List bytes,
  }) async {
    return nativeChannel.invokeMethod<String>('exportFile', {
      'name': fileName,
      'mime': mime,
      'bytes': bytes,
      'share': true,
    });
  }

  // ---------------------------------------------------------------- CSV
  static Uint8List buildCsv(List<ReportRow> rows) {
    String q(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    final lines = <String>[
      ['Nguồn', 'Ký tự', 'Pinyin', 'Âm Hán Việt', 'Trạng thái', 'Tỷ lệ nhớ'].map(q).join(','),
      for (final r in rows)
        [r.type, r.char, r.pinyin, r.hanViet, r.status, r.retention == null ? '' : '${r.retention}%'].map(q).join(','),
    ];
    // BOM để Excel đọc đúng tiếng Việt
    return Uint8List.fromList(utf8.encode('\uFEFF${lines.join('\r\n')}'));
  }

  // ---------------------------------------------------------------- PDF
  static const _primary = PdfColor.fromInt(0xFF00236F);
  static const _ink = PdfColor.fromInt(0xFF0B1C30);
  static const _muted = PdfColor.fromInt(0xFF6B7280);
  static const _line = PdfColor.fromInt(0xFFE2E8F0);
  static const _headerBg = PdfColor.fromInt(0xFFEFF4FF);
  static const _green = PdfColor.fromInt(0xFF006C49);
  static const _red = PdfColor.fromInt(0xFFBA1A1A);
  static const _bar = PdfColor.fromInt(0xFF1E3A8A);

  static Future<Uint8List> buildPdf(AppState s) async {
    Future<pw.Font> font(String path) async => pw.Font.ttf(await rootBundle.load(path));
    final base = await font('assets/fonts/PublicSans-Regular.ttf');
    final bold = await font('assets/fonts/PublicSans-Bold.ttf');
    final italic = await font('assets/fonts/PublicSans-Italic.ttf');
    // Font CJK rút gọn (~9.600 chữ thông dụng) để chữ Hán hiển thị trong PDF.
    final cjk = await font('assets/fonts/NotoSansSC-Report.ttf');

    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final dateText = '${two(now.day)}/${two(now.month)}/${now.year} ${two(now.hour)}:${two(now.minute)}';

    final cid = s.reportsCollection;
    final chart = s.reportChart(s.reportsRange, collectionId: cid);
    final maxCount = chart.fold<int>(1, (a, b) => b.count > a ? b.count : a);
    final split = s.retentionSplitIn(cid);
    final weak = s.weakListIn(cid, limit: 20);
    final rows = s.reportRowsIn(cid);
    final st = s.statsIn(cid);

    pw.Widget sectionTitle(String t) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
          child: pw.Text(t, style: pw.TextStyle(font: bold, fontSize: 13, color: _ink)),
        );

    pw.Widget stat(String value, String label, {PdfColor color = _ink}) => pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.symmetric(horizontal: 4),
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _line),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(children: [
              pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 18, color: color)),
              pw.SizedBox(height: 2),
              pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _muted)),
            ]),
          ),
        );

    final doc = pw.Document(
      title: 'Báo cáo học tập',
      theme: pw.ThemeData.withFont(base: base, bold: bold, italic: italic, fontFallback: [cjk]),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Trang ${ctx.pageNumber}/${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _muted)),
        ),
        build: (ctx) => [
          pw.Text('BÁO CÁO HỌC TẬP', style: pw.TextStyle(font: bold, fontSize: 20, color: _primary)),
          pw.SizedBox(height: 2),
          pw.Text('Collection: ${s.collectionName(cid)}', style: pw.TextStyle(font: bold, fontSize: 11, color: _ink)),
          pw.SizedBox(height: 2),
          pw.Text('Học tiếng Trung · Xuất lúc $dateText', style: const pw.TextStyle(fontSize: 9, color: _muted)),
          pw.SizedBox(height: 14),
          pw.Row(children: [
            stat('${st.total}', 'TỔNG SỐ TỪ'),
            stat('${st.learned}/${st.total}', 'ĐÃ HỌC'),
            stat('${st.mastered}', 'THÀNH THỤC', color: _green),
            stat('${s.retentionRateIn(cid)}%', 'TỶ LỆ NHỚ', color: _green),
            stat('${s.streakDays}', 'NGÀY LIÊN TIẾP'),
          ]),
          sectionTitle('Số từ đã ôn — theo ${(rangeLabels[s.reportsRange] ?? '').toLowerCase()}'),
          pw.SizedBox(
            height: 110,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                for (final b in chart)
                  pw.Expanded(
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Text('${b.count}', style: pw.TextStyle(font: bold, fontSize: 8)),
                        pw.SizedBox(height: 2),
                        pw.Container(
                          width: 22,
                          height: 80 * (b.count == 0 ? 0.04 : b.count / maxCount),
                          color: _bar,
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(b.label, style: const pw.TextStyle(fontSize: 8, color: _muted)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          sectionTitle('Tỷ lệ nhớ / quên (SRS)'),
          if (!split.hasData)
            pw.Text('Chưa có dữ liệu ôn tập.', style: const pw.TextStyle(fontSize: 10, color: _muted))
          else ...[
            pw.ClipRRect(
              horizontalRadius: 5,
              verticalRadius: 5,
              child: pw.Row(children: [
                if (split.good > 0) pw.Expanded(flex: split.good, child: pw.Container(height: 10, color: _green)),
                if (split.bad > 0) pw.Expanded(flex: split.bad, child: pw.Container(height: 10, color: _red)),
              ]),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Nhớ tốt — ${split.good}%      Cần ôn lại — ${split.bad}%', style: const pw.TextStyle(fontSize: 10)),
          ],
          sectionTitle('Từ còn yếu, cần ôn'),
          if (weak.isEmpty)
            pw.Text('Không có mục nào — tuyệt vời!', style: const pw.TextStyle(fontSize: 10, color: _muted))
          else
            pw.TableHelper.fromTextArray(
              headers: ['Ký tự', 'Âm Hán Việt', 'Nguồn', 'Tỷ lệ nhớ'],
              data: [for (final w in weak) [w.char, w.hanViet, w.typeLabel, '${w.retention}%']],
              headerStyle: pw.TextStyle(font: bold, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: _headerBg),
              cellStyle: const pw.TextStyle(fontSize: 10),
              border: pw.TableBorder.all(color: _line, width: 0.5),
            ),
          sectionTitle('Chi tiết tiến độ (${rows.length} mục)'),
          pw.TableHelper.fromTextArray(
            headers: ['Nguồn', 'Ký tự', 'Pinyin', 'Âm Hán Việt', 'Trạng thái', 'Nhớ'],
            data: [
              for (final r in rows)
                [r.type, r.char, r.pinyin, r.hanViet, r.status, r.retention == null ? '—' : '${r.retention}%'],
            ],
            headerStyle: pw.TextStyle(font: bold, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: _headerBg),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellHeight: 16,
            border: pw.TableBorder.all(color: _line, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.1),
              1: pw.FlexColumnWidth(0.8),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1.3),
              4: pw.FlexColumnWidth(1.3),
              5: pw.FlexColumnWidth(0.7),
            },
          ),
        ],
      ),
    );
    return doc.save();
  }
}
