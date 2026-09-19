import 'dart:math' as math;

import 'models.dart';

/// SRS kiểu SM-2 rút gọn, 4 mức đánh giá như Anki.
///
/// - Trạng thái (new/learning/mastered) và điểm `retention` giữ đúng bảng trong
///   README để các dot màu, báo cáo hiển thị như thiết kế.
/// - Lịch ôn dùng `interval_days` + `ease` + `due_at`. Với một mục mới, khoảng
///   ôn đúng như prototype: Quên 10 phút · Khó 1 ngày · Tốt 3 ngày · Dễ 7 ngày;
///   các lần sau khoảng cách giãn dần theo `ease`.
class Srs {
  static const ratings = ['again', 'hard', 'good', 'easy'];

  static ({Progress progress, String label}) rate(Progress? old, String key, String rating, DateTime now) {
    final status = old?.status ?? 'new';
    var ease = old?.ease ?? 2.5;
    var interval = old?.intervalDays ?? 0;
    late String next;
    late int retention;

    switch (rating) {
      case 'again':
        interval = 10 / 1440;
        ease = math.max(1.3, ease - 0.2);
        next = 'learning';
        retention = 55;
      case 'hard':
        interval = interval < 1 ? 1 : interval * 1.2;
        ease = math.max(1.3, ease - 0.15);
        next = 'learning';
        retention = 72;
      case 'good':
        interval = interval < 3 ? 3 : interval * ease;
        next = status == 'new' ? 'learning' : 'mastered';
        retention = 88;
      default: // easy
        interval = interval < 7 ? 7 : interval * ease * 1.3;
        ease = ease + 0.15;
        next = 'mastered';
        retention = 97;
    }
    interval = math.min(interval, 365);

    final nowMs = now.millisecondsSinceEpoch;
    final progress = Progress(
      key: key,
      status: next,
      retention: retention,
      dueAt: nowMs + (interval * Duration.millisecondsPerDay).round(),
      intervalDays: interval,
      ease: ease,
      reviewedAt: nowMs,
      introducedAt: old?.introducedAt ?? nowMs,
    );
    return (progress: progress, label: 'Ôn lại sau ${formatInterval(interval)}');
  }

  static String formatInterval(double days) {
    final minutes = (days * 1440).round();
    if (minutes < 60) return '$minutes phút';
    if (minutes < 1440) return '${(minutes / 60).round()} giờ';
    if (days < 30) return '${days.round()} ngày';
    if (days < 365) return '${(days / 30).round()} tháng';
    return '${(days / 365).round()} năm';
  }
}
