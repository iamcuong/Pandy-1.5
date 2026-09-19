import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'screens/dictionary_screen.dart';
import 'screens/dict_detail_screen.dart';
import 'screens/flashcard_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notebook_screen.dart';
import 'screens/radicals_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/review_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/vocab_screen.dart';
import 'screens/writing_screen.dart';

class _MenuItem {
  final Module module;
  final String label;
  final IconData icon;
  const _MenuItem(this.module, this.label, this.icon);
}

/// Danh sách module mở rộng được — thêm module mới chỉ cần thêm dòng ở đây.
const _menu = [
  _MenuItem(Module.home, 'Tổng quan', Icons.home_outlined),
  _MenuItem(Module.dictionary, 'Từ điển', Icons.travel_explore),
  _MenuItem(Module.radicals, 'Bộ thủ', Icons.apps),
  _MenuItem(Module.vocab, '3000 từ', Icons.menu_book_outlined),
  _MenuItem(Module.notebook, 'Từ cá nhân', Icons.bookmarks_outlined),
  _MenuItem(Module.flashcard, 'Flashcard', Icons.style_outlined),
  _MenuItem(Module.writing, 'Tập viết', Icons.edit_square),
  _MenuItem(Module.reports, 'Báo cáo học tập', Icons.bar_chart),
  _MenuItem(Module.settings, 'Cài đặt', Icons.settings_outlined),
];

class _Crumb {
  final String label;
  final VoidCallback? onTap;
  const _Crumb(this.label, [this.onTap]);
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  List<_Crumb> _crumbs(AppState s) {
    switch (s.tab) {
      case Module.home:
        return const [_Crumb('Tổng quan')];
      case Module.reports:
        return s.reportsBack == Module.flashcard
            ? [_Crumb('Flashcard', s.reportsGoBack), const _Crumb('Báo cáo học tập')]
            : [_Crumb('Tổng quan', () => s.go(Module.home)), const _Crumb('Báo cáo học tập')];
      case Module.radicals:
        final root = _Crumb('Bộ thủ', () => s.selectModule(Module.radicals));
        return s.radicalsView == SubView.list
            ? const [_Crumb('Bộ thủ')]
            : [root, _Crumb(s.selectedRadical?.hanViet ?? 'Chi tiết')];
      case Module.vocab:
        final root = _Crumb('3000 từ', () => s.selectModule(Module.vocab));
        return s.vocabView == SubView.list
            ? const [_Crumb('3000 từ')]
            : [root, _Crumb(s.selectedVocab?.hanViet ?? 'Chi tiết')];
      case Module.dictionary:
        if (s.dictView == SubView.detail) {
          return [_Crumb('Từ điển', s.dictToList), _Crumb(s.selectedDictChar ?? '')];
        }
        return const [_Crumb('Từ điển')];
      case Module.notebook:
        return const [_Crumb('Từ cá nhân')];
      case Module.flashcard:
        final root = _Crumb('Flashcard', () => s.selectModule(Module.flashcard));
        return switch (s.flashView) {
          SubView.list => const [_Crumb('Flashcard')],
          SubView.detail => [root, _Crumb(s.collectionName(s.selectedCollectionId))],
          SubView.review => [
              root,
              _Crumb(s.collectionName(s.reviewCollectionId), s.reviewExit),
              const _Crumb('Học'),
            ],
        };
      case Module.writing:
        return const [_Crumb('Tập viết')];
      case Module.settings:
        return const [_Crumb('Cài đặt')];
    }
  }

  (String, Widget) _body(AppState s) {
    switch (s.tab) {
      case Module.home:
        return ('home', const HomeScreen());
      case Module.reports:
        return ('reports', const ReportsScreen());
      case Module.radicals:
        return s.radicalsView == SubView.list
            ? ('rad-list', const RadicalsListScreen())
            : ('rad-detail', const RadicalDetailScreen());
      case Module.vocab:
        return s.vocabView == SubView.list
            ? ('voc-list', const VocabListScreen())
            : ('voc-detail', const VocabDetailScreen());
      case Module.dictionary:
        return s.dictView == SubView.detail
            ? ('dict-detail', const DictDetailScreen())
            : ('dict-list', const DictionaryScreen());
      case Module.notebook:
        return ('nb-list', const NotebookScreen());
      case Module.flashcard:
        return switch (s.flashView) {
          SubView.list => ('fc-list', const FlashcardHomeScreen()),
          SubView.detail => ('fc-detail-${s.selectedCollectionId}', const CollectionDetailScreen()),
          SubView.review => ('fc-review', const ReviewScreen()),
        };
      case Module.writing:
        return ('writing', const WritingScreen());
      case Module.settings:
        return ('settings', const SettingsScreen());
    }
  }

  void _onBack(AppState s) {
    final sc = _scaffoldKey.currentState;
    if (sc != null && sc.isDrawerOpen) {
      sc.closeDrawer();
      return;
    }
    if (!s.handleBack()) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final (bodyKey, body) = _body(s);
    final crumbs = _crumbs(s);
    final width = MediaQuery.sizeOf(context).width;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack(s);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: C.pageBg,
        drawerScrimColor: C.overlay,
        drawer: _AppDrawer(width: (width * 0.78).clamp(0.0, 300.0).toDouble(), onClose: () => _scaffoldKey.currentState?.closeDrawer()),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SafeArea(
              child: Column(children: [
                _AppBar(crumbs: crumbs, onMenu: () => _scaffoldKey.currentState?.openDrawer()),
                Expanded(
                  child: Stack(children: [
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 120),
                        child: KeyedSubtree(key: ValueKey(bodyKey), child: body),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: s.toast == null ? 0 : 1,
                          duration: const Duration(milliseconds: 120),
                          child: _Toast(s.toast ?? ''),
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.crumbs, required this.onMenu});
  final List<_Crumb> crumbs;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: C.surface,
        border: Border(bottom: BorderSide(color: C.borderLight)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
      child: Row(children: [
        IconButton(
          onPressed: onMenu,
          icon: const Icon(Icons.menu, size: 24, color: C.primary),
          tooltip: 'Chọn chức năng',
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 2),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var i = 0; i < crumbs.length; i++) ...[
                if (crumbs[i].onTap != null)
                  InkWell(
                    onTap: crumbs[i].onTap,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                      child: Text(crumbs[i].label, style: ts(13, w: w600, c: C.primary)),
                    ),
                  )
                else
                  Text(crumbs[i].label, style: ts(13, w: w700)),
                if (i < crumbs.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('/', style: ts(12, c: C.border)),
                  ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.width, required this.onClose});
  final double width;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Drawer(
      width: width,
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.borderLight))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Học tiếng Trung', style: ts(18, w: w700)),
              const SizedBox(height: 2),
              Text('Chọn chức năng', style: ts(12, c: C.ink500)),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (final m in _menu)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: s.tab == m.module ? C.tableHeader : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          onClose();
                          s.selectModule(m.module);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Row(children: [
                            Icon(m.icon, size: 22, color: s.tab == m.module ? C.primary : C.ink700),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                m.label,
                                style: ts(14, w: s.tab == m.module ? w700 : w600, c: s.tab == m.module ? C.primary : C.ink700),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast(this.msg);
  final String msg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: C.ink900, borderRadius: BorderRadius.circular(8), boxShadow: modalShadow),
        child: Text(msg, textAlign: TextAlign.center, style: ts(13, w: w600, c: Colors.white)),
      );
}
