import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final st = s.settings;

    return ListView(
      padding: pagePad,
      children: [
        const PageTitle('Cài đặt'),
        const SizedBox(height: 16),
        const SectionLabel('Mục tiêu học tập hàng ngày'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            _Stepper(
              label: 'Thẻ Flashcard mới / ngày',
              value: st.vocabPerDay,
              onChanged: (v) => s.updateSettings(st.copyWith(vocabPerDay: v)),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Ôn tập & hiển thị'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            _ToggleRow(label: 'Nhắc nhở ôn tập hàng ngày', value: st.remind, onTap: s.toggleRemind),
            const Divider(height: 1, color: C.borderLight),
            _ToggleRow(
              label: 'Tự động phát âm',
              value: st.autoAudio,
              onTap: () => s.updateSettings(st.copyWith(autoAudio: !st.autoAudio)),
            ),
            const Divider(height: 1, color: C.borderLight),
            _ToggleRow(
              label: 'Hiện chữ phồn thể',
              value: st.showTraditional,
              onTap: () => s.updateSettings(st.copyWith(showTraditional: !st.showTraditional)),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Dữ liệu & báo cáo'),
        AppCard(
          child: Column(children: [
            Btn.outline('Xem & xuất báo cáo học tập', icon: Icons.bar_chart, full: true, onTap: () => s.openReports(back: Module.settings)),
            const SizedBox(height: 10),
            Btn.outline(
              'Đặt lại tiến độ Flashcard',
              icon: Icons.restart_alt,
              full: true,
              fg: C.red,
              border: C.red.withValues(alpha: 0.4),
              onTap: () async {
                final ok = await confirmDialog(
                  context,
                  'Đặt lại tiến độ Flashcard của mọi từ? Từ cá nhân và collection vẫn được giữ. Không thể hoàn tác.',
                  confirm: 'Đặt lại',
                );
                if (ok) await s.resetProgress();
              },
            ),
          ]),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            'Dữ liệu nét viết & cấu tạo chữ: Make Me a Hanzi (Arphic PL / LGPL)',
            textAlign: TextAlign.center,
            style: ts(10, c: C.ink500),
          ),
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.onChanged});
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Expanded(child: Text(label, style: ts(13, w: w600))),
          IconSquare(
            Icons.remove,
            size: 28,
            iconSize: 16,
            radius: 6,
            bg: C.pageBg,
            fg: C.ink700,
            border: C.border,
            onTap: value > 1 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 36,
            child: Text('$value', textAlign: TextAlign.center, style: ts(15, w: w700)),
          ),
          IconSquare(
            Icons.add,
            size: 28,
            iconSize: 16,
            radius: 6,
            bg: C.pageBg,
            fg: C.ink700,
            border: C.border,
            onTap: value < 30 ? () => onChanged(value + 1) : null,
          ),
        ]),
      );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.value, required this.onTap});
  final String label;
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            Expanded(child: Text(label, style: ts(13, w: w600))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 42,
              height: 24,
              decoration: BoxDecoration(
                color: value ? C.primary : C.border,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 120),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
          ]),
        ),
      );
}
