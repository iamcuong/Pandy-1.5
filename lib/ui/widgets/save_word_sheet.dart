import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'common.dart';

/// Lưu từ vào Từ cá nhân (nếu chưa có) rồi mở bảng chọn collection.
/// Dùng chung cho Bộ thủ · 3000 từ · Từ điển.
Future<void> openSaveSheet(
  BuildContext context, {
  required String char,
  required String pinyin,
  required String hanViet,
  required String meaning,
  required String source,
}) async {
  final s = context.read<AppState>();
  final entry = await s.addToNotebook(char: char, pinyin: pinyin, hanViet: hanViet, meaning: meaning, source: source);
  if (!context.mounted) return;
  await showCollectionSheet(context, entry.id);
}

/// Bảng chọn collection cho một từ đã có trong Từ cá nhân.
Future<void> showCollectionSheet(BuildContext context, String entryId) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      barrierColor: C.overlay,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SaveWordSheet(entryId: entryId),
    );

class _SaveWordSheet extends StatelessWidget {
  const _SaveWordSheet({required this.entryId});
  final String entryId;

  Future<void> _create(BuildContext context, AppState s) async {
    final name = await promptCollectionName(context);
    if (name == null) return;
    final id = await s.createCollection(name);
    if (id != null) await s.setMember(id, entryId, true);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final entry = s.notebook.where((n) => n.id == entryId).firstOrNull;
    if (entry == null) return const SizedBox(height: 120, child: EmptyNote('Từ này đã bị xóa khỏi Từ cá nhân.'));
    final maxH = MediaQuery.sizeOf(context).height * 0.8;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: C.pageBg,
                  border: Border.all(color: C.borderLight),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FittedBox(child: Padding(padding: const EdgeInsets.all(4), child: Hz(entry.char, size: 30))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(entry.hanViet, style: ts(15, w: w700, c: C.primary)),
                  if (entry.pinyin.isNotEmpty) Text(entry.pinyin, style: ts(12, c: C.amberText, italic: true)),
                ]),
              ),
              const Pill('ĐÃ LƯU', bg: C.greenBg, fg: C.green, fontSize: 10),
            ]),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Thêm vào collection', style: ts(13, w: w700)),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Từ luôn nằm trong "Tất cả từ cá nhân". Chọn thêm collection nhỏ hơn để học theo chủ đề.',
                style: ts(11, c: C.ink500, h: 1.4)),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final c in s.collections)
                  _CheckRow(
                    label: c.name,
                    sub: '${s.entriesIn(c.id).length} từ',
                    checked: s.isMember(c.id, entryId),
                    onTap: () => s.setMember(c.id, entryId, !s.isMember(c.id, entryId)),
                  ),
                InkWell(
                  onTap: () => _create(context, s),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(children: [
                      const Icon(Icons.add_circle_outline, size: 22, color: C.primary),
                      const SizedBox(width: 12),
                      Text('Tạo collection mới', style: ts(13, w: w700, c: C.primary)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: C.borderLight),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(children: [
              Expanded(
                child: Btn.outline(
                  'Bỏ khỏi Từ cá nhân',
                  icon: Icons.delete_outline,
                  fg: C.red,
                  border: C.red.withValues(alpha: 0.4),
                  fontSize: 12,
                  onTap: () async {
                    Navigator.pop(context);
                    await s.removeFromNotebook(entryId);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Btn('Xong', onTap: () => Navigator.pop(context))),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.sub, required this.checked, required this.onTap});
  final String label;
  final String sub;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Icon(checked ? Icons.check_box : Icons.check_box_outline_blank,
                size: 22, color: checked ? C.primary : C.border),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: ts(13, w: w600))),
            Text(sub, style: ts(11, c: C.ink500)),
          ]),
        ),
      );
}

/// Hộp thoại nhập tên collection. Trả về null nếu huỷ.
Future<String?> promptCollectionName(BuildContext context, {String initial = '', String title = 'Collection mới'}) =>
    showDialog<String>(
      context: context,
      barrierColor: C.overlay,
      builder: (_) => _NameDialog(initial: initial, title: title),
    );

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial, required this.title});
  final String initial;
  final String title;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    if (v.isNotEmpty) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: C.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(widget.title, style: ts(16, w: w700)),
        content: TextField(
          controller: _c,
          autofocus: true,
          maxLength: 40,
          style: ts(14),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'VD: HSK1, Gia đình, Công việc…',
            hintStyle: ts(13, c: C.ink500),
            isDense: true,
            border: const OutlineInputBorder(),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: C.primary)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Hủy', style: ts(13, w: w700, c: C.ink700))),
          TextButton(onPressed: _submit, child: Text('Lưu', style: ts(13, w: w700, c: C.primary))),
        ],
      );
}

/// Nút "Thêm vào từ cá nhân" dạng full-width cho màn chi tiết Bộ thủ / 3000 từ.
class SaveWordButton extends StatelessWidget {
  const SaveWordButton({
    super.key,
    required this.char,
    required this.pinyin,
    required this.hanViet,
    required this.meaning,
    required this.source,
  });

  final String char;
  final String pinyin;
  final String hanViet;
  final String meaning;
  final String source;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final entry = s.entryForChar(char);
    void open() =>
        openSaveSheet(context, char: char, pinyin: pinyin, hanViet: hanViet, meaning: meaning, source: source);
    if (entry == null) {
      return Btn.outline('Thêm vào từ cá nhân', icon: Icons.bookmark_add_outlined, full: true, onTap: open);
    }
    final cols = s.collectionsOf(entry.id);
    final label = cols.isEmpty ? 'Đã lưu · Chọn collection' : 'Đã lưu · ${cols.map((c) => c.name).join(', ')}';
    return Btn(label, icon: Icons.bookmark, full: true, bg: C.greenBg, fg: C.green, onTap: open);
  }
}
