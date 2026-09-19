import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_tieng_trung/data/models.dart';
import 'package:hoc_tieng_trung/data/srs.dart';
import 'package:hoc_tieng_trung/data/text_norm.dart';

void main() {
  group('SRS', () {
    final now = DateTime(2026, 9, 17, 9);

    test('mục mới: khoảng ôn khớp prototype', () {
      expect(Srs.rate(null, 'vocab:1', 'again', now).label, 'Ôn lại sau 10 phút');
      expect(Srs.rate(null, 'vocab:1', 'hard', now).label, 'Ôn lại sau 1 ngày');
      expect(Srs.rate(null, 'vocab:1', 'good', now).label, 'Ôn lại sau 3 ngày');
      expect(Srs.rate(null, 'vocab:1', 'easy', now).label, 'Ôn lại sau 7 ngày');
    });

    test('chuyển trạng thái theo bảng README', () {
      expect(Srs.rate(null, 'k', 'good', now).progress.status, 'learning');
      const learning = Progress(key: 'k', status: 'learning', intervalDays: 3);
      expect(Srs.rate(learning, 'k', 'good', now).progress.status, 'mastered');
      expect(Srs.rate(learning, 'k', 'again', now).progress.status, 'learning');
      expect(Srs.rate(null, 'k', 'easy', now).progress.retention, 97);
    });

    test('khoảng ôn giãn dần', () {
      const p = Progress(key: 'k', status: 'mastered', intervalDays: 3, ease: 2.5);
      final r = Srs.rate(p, 'k', 'good', now).progress;
      expect(r.intervalDays, closeTo(7.5, 0.001));
      expect(r.dueAt, now.millisecondsSinceEpoch + (7.5 * Duration.millisecondsPerDay).round());
    });
  });

  group('Chuẩn hoá tìm kiếm', () {
    test('kiểu bỏ dấu cũ → mới', () {
      expect(normalizeViQuery('hoà'), 'hòa');
      expect(normalizeViQuery('thuỷ'), 'thủy');
      expect(normalizeViQuery('quý'), 'quý');
    });

    test('bỏ dấu thanh pinyin', () {
      expect(stripTones('nǚ ér'), 'nu er');
      expect(stripTones('shàolínsì'), 'shaolinsi');
    });

    test('tách âm Hán Việt', () {
      expect(splitReadings('khuyển chó'), ['khuyển', 'chó']);
      expect(splitReadings('  '), isEmpty);
    });
  });
}
