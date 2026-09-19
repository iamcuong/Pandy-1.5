import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

const _zh = Locale('zh', 'CN');

/// Chữ Hán — locale zh-CN để Android chọn glyph giản thể (Noto Sans CJK SC).
class Hz extends StatelessWidget {
  const Hz(this.text, {super.key, this.size = 16, this.color = C.ink900, this.weight = w400, this.maxLines});
  final String text;
  final double size;
  final Color color;
  final FontWeight weight;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
        text,
        locale: _zh,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: TextStyle(fontSize: size, color: color, fontWeight: weight, height: 1.2),
      );
}

/// Khối nền + viền + bo góc + ripple.
class Box extends StatelessWidget {
  const Box({
    super.key,
    required this.child,
    this.color = C.surface,
    this.borderColor,
    this.borderWidth = 1,
    this.radius = 4,
    this.padding,
    this.onTap,
    this.shadow,
    this.width,
    this.height,
    this.center = false,
  });

  final Widget child;
  final Color color;
  final Color? borderColor;
  final double borderWidth;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadow;
  final double? width;
  final double? height;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: borderColor == null ? BorderSide.none : BorderSide(color: borderColor!, width: borderWidth),
    );
    Widget inner = padding == null ? child : Padding(padding: padding!, child: child);
    if (center) inner = Center(child: inner);
    Widget m = Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? inner : InkWell(onTap: onTap, child: inner),
    );
    if (width != null || height != null) m = SizedBox(width: width, height: height, child: m);
    if (shadow != null) {
      m = DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: shadow),
        child: m,
      );
    }
    return m;
  }
}

/// Card trắng viền #C5C5D3, bo 4px, shadow nhẹ.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.margin});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Box(borderColor: C.border, radius: 4, padding: padding, shadow: cardShadow, onTap: onTap, child: child);
    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}

class Btn extends StatelessWidget {
  const Btn(
    this.label, {
    super.key,
    this.icon,
    this.onTap,
    this.bg = C.primary,
    this.fg = Colors.white,
    this.border,
    this.full = false,
    this.fontSize = 13,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.radius = 8,
  });

  /// Nút viền (outline).
  const Btn.outline(
    this.label, {
    super.key,
    this.icon,
    this.onTap,
    this.fg = C.primary,
    this.border = C.border,
    this.full = false,
    this.fontSize = 13,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.radius = 8,
  }) : bg = C.surface;

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color bg;
  final Color fg;
  final Color? border;
  final bool full;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: fontSize + 5, color: fg), const SizedBox(width: 6)],
        Flexible(
          child: Text(label, textAlign: TextAlign.center, style: ts(fontSize, w: w700, c: fg)),
        ),
      ],
    );
    return Box(
      color: bg,
      borderColor: border,
      radius: radius,
      padding: padding,
      onTap: onTap,
      shadow: border == null ? cardShadow : null,
      width: full ? double.infinity : null,
      child: content,
    );
  }
}

class IconSquare extends StatelessWidget {
  const IconSquare(this.icon,
      {super.key, this.onTap, this.bg = C.tableHeader, this.fg = C.primary, this.size = 40, this.iconSize = 22, this.radius = 8, this.border});
  final IconData icon;
  final VoidCallback? onTap;
  final Color bg;
  final Color fg;
  final double size;
  final double iconSize;
  final double radius;
  final Color? border;

  @override
  Widget build(BuildContext context) => Box(
        color: bg,
        borderColor: border,
        radius: radius,
        width: size,
        height: size,
        center: true,
        onTap: onTap,
        child: Icon(icon, size: iconSize, color: fg),
      );
}

class Pill extends StatelessWidget {
  const Pill(this.label,
      {super.key, required this.bg, required this.fg, this.fontSize = 9, this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2), this.border});
  final String label;
  final Color bg;
  final Color fg;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: border == null ? null : Border.all(color: border!),
        ),
        child: Text(label, style: ts(fontSize, w: w700, c: fg)),
      );
}

class Dot extends StatelessWidget {
  const Dot(this.color, {super.key, this.size = 8});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// Chip lọc (radius 12, padding 6×12, 11px/700).
class FilterPill extends StatelessWidget {
  const FilterPill(this.label, {super.key, required this.active, required this.onTap, this.color});
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// Màu trạng thái — nếu có: inactive chữ+viền màu đó, active nền màu đó.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color bg, fg, bd;
    if (color == null) {
      bg = active ? C.primary : C.surface;
      fg = active ? Colors.white : C.ink700;
      bd = active ? C.primary : C.border;
    } else {
      bg = active ? color! : C.surface;
      fg = active ? Colors.white : color!;
      bd = color!;
    }
    return Box(
      color: bg,
      borderColor: bd,
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      onTap: onTap,
      child: Text(label, style: ts(11, w: w700, c: fg)),
    );
  }
}

class HScroll extends StatelessWidget {
  const HScroll({super.key, required this.children, this.gap = 8});
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(width: gap), children[i]],
        ]),
      );
}

class Bar extends StatelessWidget {
  const Bar(this.value, {super.key, this.height = 6, this.bg = C.tableHeader, this.fg = C.primary});
  final double value; // 0..1
  final double height;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Container(
          height: height,
          color: bg,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.isNaN ? 0 : value.clamp(0.0, 1.0),
            heightFactor: 1,
            child: ColoredBox(color: fg),
          ),
        ),
      );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding = const EdgeInsets.only(bottom: 8)});
  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: padding, child: Text(text.toUpperCase(), style: ts(12, w: w700, c: C.ink500, ls: 0.5)));
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(text, style: ts(18, w: w700))),
        if (trailing != null) trailing!,
      ]);
}

/// Thẻ tiến độ: "Đã học n/total" + dòng phụ + progress bar.
class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key, required this.learned, required this.total, required this.rightLabel, required this.rightValue});
  final int learned;
  final int total;
  final String rightLabel;
  final String rightValue;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: Text.rich(TextSpan(style: ts(12, c: C.ink700), children: [
                const TextSpan(text: 'Đã học '),
                TextSpan(text: '$learned/$total', style: ts(12, w: w700)),
              ])),
            ),
            Text.rich(TextSpan(style: ts(12, c: C.ink700), children: [
              TextSpan(text: '$rightLabel '),
              TextSpan(text: rightValue, style: ts(12, w: w700)),
            ])),
          ]),
          const SizedBox(height: 10),
          Bar(total == 0 ? 0 : learned / total),
        ]),
      );
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.controller, required this.hint, required this.onChanged});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        style: ts(13),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: C.tableHeader,
          hintText: hint,
          hintStyle: ts(13, c: C.ink500),
          prefixIcon: const Icon(Icons.search, size: 16, color: C.ink700),
          prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 16),
          contentPadding: const EdgeInsets.fromLTRB(0, 11, 12, 11),
          suffixIcon: controller.text.isEmpty
              ? null
              : GestureDetector(
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  child: const Icon(Icons.close, size: 16, color: C.ink500),
                ),
          suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 16),
          border: _border(C.border),
          enabledBorder: _border(C.border),
          focusedBorder: _border(C.primary),
        ),
      );

  static OutlineInputBorder _border(Color c) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: c));
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        child: Text(text, textAlign: TextAlign.center, style: ts(12, c: C.ink500, h: 1.5)),
      );
}

/// Nút back + nhãn (13px/700 primary) như header màn chi tiết.
class BackLink extends StatelessWidget {
  const BackLink(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.arrow_back, size: 20, color: C.primary),
            const SizedBox(width: 6),
            Text(label, style: ts(13, w: w700, c: C.primary)),
          ]),
        ),
      );
}

Future<bool> confirmDialog(BuildContext context, String message, {String confirm = 'Xóa'}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierColor: C.overlay,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      content: Text(message, style: ts(14, c: C.ink900, h: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Hủy', style: ts(13, w: w700, c: C.ink700))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirm, style: ts(13, w: w700, c: C.red))),
      ],
    ),
  );
  return r ?? false;
}

/// Padding trang chuẩn 16/20/28.
const pagePad = EdgeInsets.fromLTRB(20, 16, 20, 28);

/// Ô tìm kiếm cần controller đồng bộ với state (khi state xoá từ khoá từ nơi khác).
/// Cập nhật sau frame để không gọi setState của TextField trong lúc build.
void syncController(TextEditingController c, String value) {
  if (c.text == value) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      if (c.text != value) {
        c.value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
      }
    } catch (_) {
      // controller đã dispose
    }
  });
}
