import 'package:flutter/material.dart';

/// Design tokens — khớp mục "Design Tokens" trong README handoff.
class C {
  static const primary = Color(0xFF00236F);
  static const primaryDark = Color(0xFF1E3A8A);
  static const ink900 = Color(0xFF0B1C30);
  static const ink700 = Color(0xFF444651);
  static const ink500 = Color(0xFF6B7280);
  static const border = Color(0xFFC5C5D3);
  static const borderLight = Color(0xFFE2E8F0);
  static const surface = Color(0xFFFFFFFF);
  static const pageBg = Color(0xFFF8F9FF);
  static const tableHeader = Color(0xFFEFF4FF);
  static const blue100 = Color(0xFFD3E4FE);
  static const green = Color(0xFF006C49); // status-resolved
  static const red = Color(0xFFBA1A1A); // status-overdue
  static const redDark = Color(0xFF93000A);
  static const amber = Color(0xFFF59E0B); // status-warning
  static const info = Color(0xFF7DB8FC);
  static const amberText = Color(0xFF92610A);
  static const greenBg = Color(0xFFD9EFE5);
  static const amberBg = Color(0xFFFFF3CD);
  static const redBg = Color(0xFFFFD9D4);
  static const rowHighlight = Color(0xFFFFF8F5);
  static const overlay = Color(0x660B1C30); // rgba(11,28,48,0.4)
}

const kFont = 'PublicSans';

const cardShadow = [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))];
const modalShadow = [BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 4))];

TextStyle ts(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = C.ink900,
  double? ls,
  bool italic = false,
  double? h,
}) =>
    TextStyle(
      fontFamily: kFont,
      fontSize: size,
      fontWeight: w,
      color: c,
      letterSpacing: ls,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      height: h,
    );

const w400 = FontWeight.w400;
const w500 = FontWeight.w500;
const w600 = FontWeight.w600;
const w700 = FontWeight.w700;

// ---- Trạng thái học (dùng thống nhất toàn app)
class StatusMeta {
  final String label;
  final Color dot;
  final Color bg;
  final Color text;
  const StatusMeta(this.label, this.dot, this.bg, this.text);
}

const statusMeta = <String, StatusMeta>{
  'new': StatusMeta('Chưa học', C.info, C.tableHeader, C.primary),
  'learning': StatusMeta('Đang học', C.amber, C.amberBg, C.amberText),
  'mastered': StatusMeta('Đã thành thục', C.green, C.greenBg, C.green),
};

// ---- Badge HSK
class Pair {
  final Color bg;
  final Color fg;
  const Pair(this.bg, this.fg);
}

const hskColors = <int, Pair>{
  0: Pair(C.tableHeader, C.ink700),
  1: Pair(C.tableHeader, C.primary),
  2: Pair(C.blue100, C.primaryDark),
  3: Pair(C.greenBg, C.green),
  4: Pair(Color(0xFFFFF8E1), Color(0xFF78610A)),
  5: Pair(C.amberBg, C.amberText),
  6: Pair(C.redBg, C.redDark),
};

// ---- Nguồn của mục trong Sổ từ vựng
class SourceMeta {
  final String label;
  final Color bg;
  final Color fg;
  const SourceMeta(this.label, this.bg, this.fg);
}

const sourceMeta = <String, SourceMeta>{
  'dictionary': SourceMeta('Từ điển', C.tableHeader, C.primary),
  'radical': SourceMeta('Bộ thủ', C.amberBg, C.amberText),
  'vocab': SourceMeta('3000 từ', C.greenBg, C.green),
};

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: kFont,
    colorScheme: ColorScheme.fromSeed(seedColor: C.primary, primary: C.primary, surface: C.surface),
    scaffoldBackgroundColor: C.pageBg,
    splashFactory: InkRipple.splashFactory,
  );
  return base.copyWith(
    textSelectionTheme: const TextSelectionThemeData(cursorColor: C.primary),
  );
}
