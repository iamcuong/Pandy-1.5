import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Phát âm tiếng Trung bằng TTS của máy (locale zh-CN).
class TtsService {
  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<bool> speaking = ValueNotifier(false);
  bool _available = false;

  Future<void> init() async {
    try {
      _tts.setStartHandler(() => speaking.value = true);
      _tts.setCompletionHandler(() => speaking.value = false);
      _tts.setCancelHandler(() => speaking.value = false);
      _tts.setErrorHandler((_) => speaking.value = false);
      final ok = await _tts.isLanguageAvailable('zh-CN');
      _available = ok == true || ok == 1;
      if (_available) {
        await _tts.setLanguage('zh-CN');
        await _tts.setSpeechRate(0.42);
      }
    } catch (_) {
      _available = false;
    }
  }

  /// Trả về false nếu máy không có giọng đọc zh-CN.
  Future<bool> speak(String text) async {
    if (!_available || text.isEmpty) return false;
    try {
      await _tts.stop();
      speaking.value = true;
      final r = await _tts.speak(text);
      if (r != 1 && r != true) speaking.value = false;
      return true;
    } catch (_) {
      speaking.value = false;
      return false;
    }
  }
}

/// Nhắc ôn tập hằng ngày. Mỗi lần mở app lịch nhắc được đặt lại,
/// nên thông báo đến khoảng 24 giờ sau lần mở app gần nhất.
class ReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();
  static const _id = 1001;

  Future<void> init() async {
    try {
      await _plugin.initialize(
        const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      );
    } catch (_) {}
  }

  /// Trả về false nếu người dùng từ chối quyền thông báo.
  Future<bool> enable() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      if (granted == false) return false;
      await _plugin.cancel(_id);
      await _plugin.periodicallyShow(
        _id,
        'Đến giờ ôn tập tiếng Trung',
        'Mở app để ôn bộ thủ và từ vựng hôm nay.',
        RepeatInterval.daily,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_review',
            'Nhắc ôn tập hằng ngày',
            channelDescription: 'Thông báo nhắc bạn ôn tập mỗi ngày',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return true;
    } catch (e) {
      debugPrint('Reminder enable failed: $e');
      return false;
    }
  }

  Future<void> disable() async {
    try {
      await _plugin.cancel(_id);
    } catch (_) {}
  }
}
