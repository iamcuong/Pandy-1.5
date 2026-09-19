import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/text_norm.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/save_word_sheet.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openRadicalSheet(AppState s) async {
    s.setDictInputMode('radical');
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: C.overlay,
      builder: (_) => RadicalPickerSheet(radicals: s.radicals),
    );
    if (!mounted) return;
    if (id != null) {
      s.selectDictRadical(id);
    } else {
      s.setDictInputMode('keyboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    syncController(_search, s.dictSearch);
    final selectedRadical = s.dictRadical == null ? null : s.radicalById[s.dictRadical];
    final res = s.dictResult;
    final query = normalizeViQuery(s.dictSearch.trim().toLowerCase());

    return ListView(
      key: const PageStorageKey('dict-list'),
      padding: pagePad,
      children: [
        const PageTitle('Từ điển'),
        const SizedBox(height: 12),
        SearchField(controller: _search, hint: 'Nhập từ cần tìm', onChanged: s.setDictSearch),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _Select(
              value: s.dictField,
              items: const {'hanviet': 'Hán Việt', 'char': 'Chữ Hán', 'pinyin': 'Pinyin'},
              prefix: 'Tra theo: ',
              onChanged: s.setDictField,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Select(
              value: s.dictType,
              items: const {'all': 'Tất cả', 'chars': 'Chữ đơn', 'phrases': 'Từ ghép'},
              prefix: 'Loại: ',
              onChanged: s.setDictType,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _ModeButton(
            icon: Icons.keyboard_outlined,
            active: s.dictInputMode == 'keyboard',
            onTap: () => s.setDictInputMode('keyboard'),
          ),
          const SizedBox(width: 10),
          _ModeButton(icon: Icons.draw_outlined, active: false, onTap: () => s.setDictInputMode('handwriting')),
          const SizedBox(width: 10),
          _ModeButton(
            icon: Icons.grid_view,
            active: s.dictInputMode == 'radical',
            onTap: () => _openRadicalSheet(s),
          ),
        ]),
        if (selectedRadical != null) ...[
          const SizedBox(height: 12),
          Box(
            color: C.tableHeader,
            radius: 8,
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(children: [
              Expanded(
                child: Text.rich(
                  TextSpan(style: ts(12, w: w700, c: C.primary), children: [
                    const TextSpan(text: 'Lọc theo bộ thủ: '),
                    TextSpan(text: selectedRadical.char, locale: const Locale('zh', 'CN')),
                    TextSpan(text: ' (${selectedRadical.hanViet})'),
                  ]),
                ),
              ),
              IconButton(
                onPressed: s.clearDictRadical,
                icon: const Icon(Icons.close, size: 18, color: C.primary),
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        if (s.dictPromptEmpty)
          const EmptyNote('Nhập từ khóa hoặc chọn bộ thủ để tra cứu trong từ điển 15.591 chữ đơn và 8.384 từ ghép.')
        else if (s.dictLoading && res.items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (res.items.isEmpty)
          const EmptyNote('Không tìm thấy kết quả phù hợp.')
        else ...[
          for (final e in res.items) _ResultCard(entry: e, query: query, byHanViet: s.dictField == 'hanviet'),
          if (res.total > res.items.length)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'và ${res.total - res.items.length} kết quả khác — thu hẹp tìm kiếm để xem thêm',
                textAlign: TextAlign.center,
                style: ts(11, c: C.ink500),
              ),
            ),
        ],
      ],
    );
  }
}

class _Select extends StatelessWidget {
  const _Select({required this.value, required this.items, required this.onChanged, required this.prefix});
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;
  final String prefix;

  @override
  Widget build(BuildContext context) => Box(
        borderColor: C.border,
        radius: 4,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            isDense: false,
            itemHeight: 48,
            icon: const Icon(Icons.expand_more, size: 18, color: C.ink700),
            style: ts(12, c: C.ink900),
            dropdownColor: C.surface,
            borderRadius: BorderRadius.circular(4),
            selectedItemBuilder: (_) => [
              for (final e in items.entries)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('$prefix${e.value}', overflow: TextOverflow.ellipsis, style: ts(12, c: C.ink900)),
                ),
            ],
            items: [
              for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value, style: ts(13))),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.icon, required this.active, required this.onTap});
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconSquare(
        icon,
        onTap: onTap,
        bg: active ? C.primary : C.tableHeader,
        fg: active ? Colors.white : C.primary,
      );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.entry, required this.query, required this.byHanViet});
  final DictEntry entry;
  final String query;
  final bool byHanViet;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final inNb = context.select<AppState, bool>((st) => st.inNotebook(entry.word));

    // Chữ đơn: hv chứa NHIỀU âm cách nhau khoảng trắng → tách âm chính / âm khác.
    // Từ ghép: hv là MỘT âm đọc nhiều âm tiết → giữ nguyên.
    var primary = entry.hv;
    var others = '';
    if (!entry.isPhrase) {
      final readings = splitReadings(entry.hv);
      if (readings.isNotEmpty) {
        final matched = byHanViet && query.isNotEmpty
            ? readings.where((r) => r.toLowerCase().contains(query)).firstOrNull
            : null;
        primary = matched ?? readings.first;
        others = readings.where((r) => r != primary).join(', ');
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: InkWell(
              onTap: entry.isPhrase ? null : () => s.openDictDetail(entry.word),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Row(children: [
                  SizedBox(
                    width: entry.isPhrase ? null : 44,
                    child: Center(child: Hz(entry.word, size: entry.isPhrase ? 22 : 28)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 2, children: [
                        Text(primary, style: ts(13, w: w700, c: C.primary)),
                        entry.isPhrase
                            ? const Pill('Từ ghép', bg: C.greenBg, fg: C.green)
                            : const Pill('Chữ đơn', bg: C.tableHeader, fg: C.primary),
                      ]),
                      if (entry.pinyin.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(entry.pinyin, style: ts(11, c: C.amberText, italic: true)),
                      ],
                      if (others.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Âm khác: $others', style: ts(10, c: C.ink500)),
                      ],
                      if (entry.meaning.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(entry.meaning, maxLines: 3, overflow: TextOverflow.ellipsis, style: ts(11, c: C.ink700, h: 1.4)),
                      ],
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: inNb
                ? IconSquare(
                    Icons.bookmark,
                    size: 34,
                    iconSize: 18,
                    bg: C.greenBg,
                    fg: C.green,
                    onTap: () => openSaveSheet(
                      context,
                      char: entry.word,
                      pinyin: entry.pinyin,
                      hanViet: primary,
                      meaning: entry.meaning,
                      source: 'dictionary',
                    ),
                  )
                : Btn(
                    'Thêm',
                    icon: Icons.bookmark_add_outlined,
                    fontSize: 11,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    onTap: () => openSaveSheet(
                      context,
                      char: entry.word,
                      pinyin: entry.pinyin,
                      hanViet: primary,
                      meaning: entry.meaning,
                      source: 'dictionary',
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

/// Bottom sheet "Chọn bộ thủ" — nhóm theo số nét. Trả về id bộ thủ đã chọn.
class RadicalPickerSheet extends StatelessWidget {
  const RadicalPickerSheet({super.key, required this.radicals});
  final List<Radical> radicals;

  @override
  Widget build(BuildContext context) {
    final groups = <int, List<Radical>>{};
    for (final r in radicals) {
      groups.putIfAbsent(r.strokes, () => []).add(r);
    }
    final keys = groups.keys.toList()..sort();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75, maxWidth: 430),
      child: Container(
        decoration: const BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: modalShadow,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.borderLight))),
            child: Row(children: [
              Expanded(child: Text('Chọn bộ thủ', style: ts(15, w: w700))),
              IconSquare(
                Icons.close,
                size: 30,
                iconSize: 18,
                bg: C.pageBg,
                fg: C.ink700,
                onTap: () => Navigator.pop(context),
              ),
            ]),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                for (final k in keys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                        width: 20,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('$k', style: ts(13, w: w700, c: C.primary)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final r in groups[k]!)
                            Box(
                              width: 36,
                              height: 36,
                              radius: 6,
                              borderColor: C.border,
                              center: true,
                              onTap: () => Navigator.pop(context, r.id),
                              child: Hz(r.char, size: 16),
                            ),
                        ]),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
