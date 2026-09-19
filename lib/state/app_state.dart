import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;

import '../data/models.dart';
import '../data/ref_db.dart';
import '../data/srs.dart';
import '../data/text_norm.dart';
import '../data/user_db.dart';
import '../services/platform_services.dart';
import '../theme/tokens.dart';

enum Module { home, dictionary, radicals, vocab, notebook, flashcard, writing, reports, settings }

enum SubView { list, detail, review }

class ChartBar {
  final String label;
  final int count;
  const ChartBar(this.label, this.count);
}

class WeakItem {
  final String char;
  final String hanViet;
  final String typeLabel;
  final int retention;
  const WeakItem(this.char, this.hanViet, this.typeLabel, this.retention);
}

class ReportRow {
  final String type;
  final String char;
  final String pinyin;
  final String hanViet;
  final String status;
  final int? retention;
  const ReportRow(this.type, this.char, this.pinyin, this.hanViet, this.status, this.retention);
}

/// Số liệu tổng hợp của một collection.
class CollectionStats {
  final int total;
  final int fresh;
  final int learning;
  final int mastered;
  const CollectionStats(this.total, this.fresh, this.learning, this.mastered);
  int get learned => learning + mastered;
}

const rangeLabels = {'day': 'Ngày', 'week': 'Tuần', 'month': 'Tháng'};

/// Id của collection gốc "Tất cả từ cá nhân" (không lưu trong DB).
const allCollectionId = 'all';

class AppState extends ChangeNotifier {
  AppState({required this.ref, required this.user, required this.tts, required this.reminder});

  final RefDb ref;
  final UserDb user;
  final TtsService tts;
  final ReminderService reminder;

  // ------------------------------------------------------------ dữ liệu
  bool ready = false;
  String? loadError;

  List<Radical> radicals = [];
  Map<int, Radical> radicalById = {};
  Map<String, int> radicalLookup = {};
  List<VocabItem> vocab = [];
  Map<int, VocabItem> vocabById = {};
  Map<String, Progress> progress = {};
  List<NotebookEntry> notebook = [];
  Map<String, NotebookEntry> _entryByChar = {};
  List<WordCollection> collections = [];
  Map<String, Set<String>> collectionItems = {}; // collection id → id từ
  List<ReviewLogEntry> reviewLog = []; // ~40 ngày gần nhất, đủ cho báo cáo
  Set<int> activeDays = {};
  Settings settings = const Settings();

  /// Ảnh bộ thủ do người dùng thêm vào assets/radical_images/ (số bộ → đường dẫn asset).
  Map<int, String> radicalImages = {};

  Future<void> load() async {
    try {
      await ref.open();
      await user.open();
      radicals = await ref.radicals();
      radicalById = {for (final r in radicals) r.id: r};
      radicalLookup = await ref.radicalLookup();
      vocab = await ref.vocab();
      vocabById = {for (final v in vocab) v.id: v};
      progress = await user.loadProgress();
      notebook = await user.loadNotebook();
      _reindex();
      collections = await user.loadCollections();
      collectionItems = await user.loadCollectionItems();
      settings = await user.loadSettings();
      await _reloadLog();
      await _loadRadicalImages();
      if (radicals.isNotEmpty) writingChar = radicals.first.char;
      ready = true;
      notifyListeners();
    } catch (e, st) {
      debugPrint('Load failed: $e\n$st');
      loadError = '$e';
      notifyListeners();
      return;
    }
    unawaited(tts.init());
    await reminder.init();
    if (settings.remind) unawaited(reminder.enable());
  }

  Future<void> _reloadLog() async {
    final since = _day(DateTime.now()).subtract(const Duration(days: 40));
    reviewLog = await user.loadReviewLog(since: since.millisecondsSinceEpoch);
    activeDays = await user.activeDays();
  }

  Future<void> _loadRadicalImages() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final re = RegExp(r'^assets/radical_images/(\d{1,3})\.(png|jpe?g|webp)$', caseSensitive: false);
      for (final a in manifest.listAssets()) {
        final m = re.firstMatch(a);
        if (m != null) radicalImages[int.parse(m.group(1)!)] = a;
      }
    } catch (e) {
      debugPrint('radical images: $e');
    }
  }

  void _reindex() => _entryByChar = {for (final n in notebook) n.char: n};

  // ------------------------------------------------------------ toast
  String? toast;
  Timer? _toastTimer;

  void showToast(String msg) {
    _toastTimer?.cancel();
    toast = msg;
    notifyListeners();
    _toastTimer = Timer(const Duration(milliseconds: 2400), () {
      toast = null;
      notifyListeners();
    });
  }

  // ------------------------------------------------------------ điều hướng
  Module tab = Module.home;
  SubView radicalsView = SubView.list;
  SubView vocabView = SubView.list;
  SubView notebookView = SubView.list;
  SubView dictView = SubView.list;
  SubView flashView = SubView.list;

  void selectModule(Module m) {
    switch (m) {
      case Module.radicals:
        radicalsView = SubView.list;
      case Module.vocab:
        vocabView = SubView.list;
      case Module.notebook:
        notebookView = SubView.list;
      case Module.flashcard:
        if (flashView == SubView.review) _session++;
        flashView = SubView.list;
      case Module.reports:
        reportsBack = Module.home;
      case Module.dictionary:
        dictView = SubView.list;
        dictSearch = '';
        dictType = 'all';
        dictRadical = null;
        dictInputMode = 'keyboard';
        dictHistory.clear();
        dictResult = DictSearchResult.empty;
      default:
        break;
    }
    tab = m;
    notifyListeners();
  }

  void go(Module m) {
    tab = m;
    notifyListeners();
  }

  /// Nút Back của Android. Trả về false nếu đang ở gốc (thoát app).
  bool handleBack() {
    switch (tab) {
      case Module.home:
        return false;
      case Module.radicals:
        if (radicalsView == SubView.list) return _toHome();
        radicalsView = SubView.list;
      case Module.vocab:
        if (vocabView == SubView.list) return _toHome();
        vocabView = SubView.list;
      case Module.notebook:
        return _toHome();
      case Module.flashcard:
        switch (flashView) {
          case SubView.list:
            return _toHome();
          case SubView.detail:
            flashView = SubView.list;
          case SubView.review:
            reviewExit();
            return true;
        }
      case Module.reports:
        tab = reportsBack;
      case Module.dictionary:
        if (dictView == SubView.list) return _toHome();
        dictBack();
        return true;
      default:
        return _toHome();
    }
    notifyListeners();
    return true;
  }

  bool _toHome() {
    tab = Module.home;
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------ tiến độ
  String statusOf(String key) => progress[key]?.status ?? 'new';
  int? retentionOf(String key) => progress[key]?.retention;

  NotebookEntry? entryForChar(String char) => _entryByChar[char];

  /// Trạng thái học của một chữ = trạng thái flashcard của nó trong Từ cá nhân
  /// (chưa lưu vào Từ cá nhân thì coi như "Chưa học").
  String charStatus(String char) {
    final e = _entryByChar[char];
    return e == null ? 'new' : statusOf(e.key);
  }

  int get radicalsLearned => radicals.where((r) => charStatus(r.char) != 'new').length;
  int get vocabLearned => vocab.where((v) => charStatus(v.char) != 'new').length;
  int get radicalsSaved => radicals.where((r) => _entryByChar.containsKey(r.char)).length;
  int get vocabSaved => vocab.where((v) => _entryByChar.containsKey(v.char)).length;
  int get notebookLearned => notebook.where((n) => statusOf(n.key) != 'new').length;

  // ------------------------------------------------------------ collection
  WordCollection? collectionById(String id) => collections.where((c) => c.id == id).firstOrNull;

  bool collectionExists(String id) => id == allCollectionId || collectionById(id) != null;

  String collectionName(String id) =>
      id == allCollectionId ? 'Tất cả từ cá nhân' : (collectionById(id)?.name ?? 'Collection');

  List<NotebookEntry> entriesIn(String id) {
    if (id == allCollectionId) return notebook;
    final ids = collectionItems[id] ?? const <String>{};
    return notebook.where((n) => ids.contains(n.id)).toList();
  }

  Set<String> keysIn(String id) => {for (final e in entriesIn(id)) e.key};

  bool isMember(String collectionId, String entryId) => collectionItems[collectionId]?.contains(entryId) ?? false;

  List<WordCollection> collectionsOf(String entryId) =>
      collections.where((c) => isMember(c.id, entryId)).toList();

  CollectionStats statsIn(String id) {
    var fresh = 0, learning = 0, mastered = 0;
    final entries = entriesIn(id);
    for (final e in entries) {
      switch (statusOf(e.key)) {
        case 'learning':
          learning++;
        case 'mastered':
          mastered++;
        default:
          fresh++;
      }
    }
    return CollectionStats(entries.length, fresh, learning, mastered);
  }

  /// Tạo collection mới, trả về id (null nếu tên rỗng hoặc trùng).
  Future<String?> createCollection(String name) async {
    final n = name.trim();
    if (n.isEmpty) return null;
    if (collections.any((c) => c.name.toLowerCase() == n.toLowerCase())) {
      showToast('Đã có collection "$n"');
      return null;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final c = WordCollection(id: 'col-$now-${math.Random().nextInt(99999)}', name: n, createdAt: now);
    collections.add(c);
    notifyListeners();
    await user.saveCollection(c);
    return c.id;
  }

  Future<void> renameCollection(String id, String name) async {
    final n = name.trim();
    final i = collections.indexWhere((c) => c.id == id);
    if (n.isEmpty || i < 0) return;
    if (collections.any((c) => c.id != id && c.name.toLowerCase() == n.toLowerCase())) {
      showToast('Đã có collection "$n"');
      return;
    }
    collections[i] = collections[i].copyWith(name: n);
    notifyListeners();
    await user.saveCollection(collections[i]);
  }

  Future<void> deleteCollection(String id) async {
    final name = collectionName(id);
    collections.removeWhere((c) => c.id == id);
    collectionItems.remove(id);
    if (selectedCollectionId == id) {
      selectedCollectionId = allCollectionId;
      if (tab == Module.flashcard) flashView = SubView.list;
    }
    if (reportsCollection == id) reportsCollection = allCollectionId;
    if (notebookCollection == id) notebookCollection = allCollectionId;
    showToast('Đã xóa collection "$name" (các từ vẫn còn trong Từ cá nhân)');
    await user.deleteCollection(id);
  }

  Future<void> setMember(String collectionId, String entryId, bool member) async {
    final set = collectionItems.putIfAbsent(collectionId, () => <String>{});
    member ? set.add(entryId) : set.remove(entryId);
    notifyListeners();
    await user.setCollectionMember(collectionId, entryId, member);
  }

  // ------------------------------------------------------------ Flashcard
  String selectedCollectionId = allCollectionId;

  /// Số thẻ mới tối đa mỗi ngày (dùng chung cho mọi collection).
  int get newPerDay => settings.vocabPerDay;

  int get newIntroducedToday {
    final start = _day(DateTime.now()).millisecondsSinceEpoch;
    return progress.values.where((p) => p.key.startsWith('notebook:') && (p.introducedAt ?? 0) >= start).length;
  }

  int get newRemainingToday => math.max(newPerDay - newIntroducedToday, 0);

  List<String> dueKeysIn(String id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return entriesIn(id).map((e) => e.key).where((k) {
      final p = progress[k];
      return p != null && p.status != 'new' && (p.dueAt ?? 0) <= now;
    }).toList()
      ..sort((a, b) => (progress[a]!.dueAt ?? 0).compareTo(progress[b]!.dueAt ?? 0));
  }

  int newCountIn(String id) => entriesIn(id).where((e) => statusOf(e.key) == 'new').length;

  /// Thẻ cần học hôm nay: thẻ đến hạn + thẻ mới còn trong hạn mức ngày.
  int dueCountIn(String id) => dueKeysIn(id).length + math.min(newRemainingToday, newCountIn(id));

  void openCollection(String id) {
    if (!collectionExists(id)) id = allCollectionId;
    tab = Module.flashcard;
    flashView = SubView.detail;
    selectedCollectionId = id;
    notifyListeners();
  }

  void flashToList() {
    flashView = SubView.list;
    notifyListeners();
  }

  // ------------------------------------------------------------ phiên ôn flashcard
  String reviewCollectionId = allCollectionId;
  List<String> reviewQueue = [];
  int reviewIndex = 0;
  bool reviewFlipped = false;
  bool reviewDone = false;
  Map<String, int> reviewStats = {'again': 0, 'hard': 0, 'good': 0, 'easy': 0};
  int _session = 0;
  bool _rating = false;

  /// [all] = ôn toàn bộ từ trong collection (xáo trộn), không theo lịch SRS.
  void startFlashcard(String id, {bool all = false}) {
    if (!collectionExists(id)) id = allCollectionId;
    final entries = entriesIn(id);
    final List<String> queue;
    if (all) {
      queue = entries.map((e) => e.key).toList()..shuffle();
    } else {
      queue = [
        ...dueKeysIn(id),
        ...entries.where((e) => statusOf(e.key) == 'new').map((e) => e.key).take(newRemainingToday),
      ];
    }
    if (queue.isEmpty) {
      showToast(entries.isEmpty
          ? 'Collection này chưa có từ nào'
          : 'Hôm nay đã học xong. Muốn học thêm thì chọn "Ôn toàn bộ".');
      return;
    }
    _session++;
    _rating = false;
    reviewCollectionId = id;
    selectedCollectionId = id;
    reviewQueue = queue;
    reviewIndex = 0;
    reviewFlipped = false;
    reviewDone = false;
    reviewStats = {'again': 0, 'hard': 0, 'good': 0, 'easy': 0};
    tab = Module.flashcard;
    flashView = SubView.review;
    notifyListeners();
  }

  StudyItem? studyItem(String key) {
    final i = key.indexOf(':');
    final kind = key.substring(0, i);
    final id = key.substring(i + 1);
    switch (kind) {
      case 'radical':
        final r = radicalById[int.tryParse(id)];
        return r == null ? null : StudyItem(key, r.char, r.pinyin, r.hanViet, r.meaning);
      case 'vocab':
        final v = vocabById[int.tryParse(id)];
        return v == null ? null : StudyItem(key, v.char, v.pinyin, v.hanViet, v.meaning);
      default:
        final n = notebook.where((e) => e.id == id).firstOrNull;
        return n == null ? null : StudyItem(key, n.char, n.pinyin, n.hanViet, n.meaning);
    }
  }

  StudyItem? get currentCard =>
      reviewIndex < reviewQueue.length ? studyItem(reviewQueue[reviewIndex]) : null;

  void reviewFlip() {
    reviewFlipped = !reviewFlipped;
    notifyListeners();
    final c = currentCard;
    if (reviewFlipped && settings.autoAudio && c != null) tts.speak(c.char);
  }

  void reviewExit() {
    _session++;
    _rating = false;
    flashView = collectionExists(reviewCollectionId) ? SubView.detail : SubView.list;
    notifyListeners();
  }

  Future<void> rate(String rating) async {
    if (_rating || reviewDone || reviewIndex >= reviewQueue.length) return;
    _rating = true;
    final session = _session;
    final key = reviewQueue[reviewIndex];
    final now = DateTime.now();
    final r = Srs.rate(progress[key], key, rating, now);
    progress[key] = r.progress;
    reviewStats[rating] = (reviewStats[rating] ?? 0) + 1;
    reviewLog.add(ReviewLogEntry(key, rating, now.millisecondsSinceEpoch));
    activeDays.add(_dayKey(now));
    showToast(r.label);
    await user.saveProgress(r.progress);
    await user.logReview(key, rating, now.millisecondsSinceEpoch);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (session != _session) return;
    if (reviewIndex + 1 >= reviewQueue.length) {
      reviewDone = true;
    } else {
      reviewIndex++;
      reviewFlipped = false;
    }
    _rating = false;
    notifyListeners();
  }

  // ------------------------------------------------------------ Từ cá nhân (sổ từ vựng)
  String notebookFilter = 'all'; // nguồn: all | dictionary | radical | vocab
  String notebookCollection = allCollectionId;

  bool inNotebook(String char) => _entryByChar.containsKey(char);

  /// Lưu từ vào Từ cá nhân (nếu chưa có) và trả về mục tương ứng.
  Future<NotebookEntry> addToNotebook({
    required String char,
    required String pinyin,
    required String hanViet,
    required String meaning,
    required String source,
  }) async {
    final existing = _entryByChar[char];
    if (existing != null) return existing;
    final now = DateTime.now().millisecondsSinceEpoch;
    final e = NotebookEntry(
      id: 'nb-$now-${math.Random().nextInt(99999)}',
      char: char,
      pinyin: pinyin,
      hanViet: hanViet,
      meaning: meaning,
      source: source,
      addedAt: now,
    );
    notebook.add(e);
    _reindex();
    showToast('Đã lưu "$char" vào Từ cá nhân');
    await user.addNotebook(e);
    return e;
  }

  Future<void> removeFromNotebook(String id) async {
    notebook.removeWhere((n) => n.id == id);
    _reindex();
    progress.remove('notebook:$id');
    for (final set in collectionItems.values) {
      set.remove(id);
    }
    showToast('Đã xóa khỏi Từ cá nhân');
    await user.removeNotebook(id);
  }

  Future<void> clearNotebook() async {
    notebook.clear();
    _reindex();
    collectionItems.clear();
    progress.removeWhere((k, _) => k.startsWith('notebook:'));
    showToast('Đã xóa toàn bộ Từ cá nhân');
    await user.clearNotebook();
  }

  void setNotebookFilter(String f) {
    notebookFilter = f;
    notifyListeners();
  }

  void setNotebookCollection(String id) {
    notebookCollection = id;
    notifyListeners();
  }

  // ------------------------------------------------------------ bộ thủ
  String radicalFilter = 'all';
  Set<int> radCollapsed = {};
  int? selectedRadicalId;

  Radical? get selectedRadical => radicalById[selectedRadicalId];

  Radical? radicalForChar(String ch) => radicalById[radicalLookup[ch]];

  void setRadicalFilter(String f) {
    radicalFilter = f;
    notifyListeners();
  }

  void toggleStrokeGroup(int stroke) {
    radCollapsed.contains(stroke) ? radCollapsed.remove(stroke) : radCollapsed.add(stroke);
    notifyListeners();
  }

  void collapseAllGroups() {
    radCollapsed = radicals.map((r) => r.strokes).toSet();
    notifyListeners();
  }

  void expandAllGroups() {
    radCollapsed = {};
    notifyListeners();
  }

  void openRadical(int id) {
    tab = Module.radicals;
    radicalsView = SubView.detail;
    selectedRadicalId = id;
    notifyListeners();
  }

  void radicalStep(int dir) {
    if (radicals.isEmpty) return;
    final i = radicals.indexWhere((r) => r.id == selectedRadicalId);
    selectedRadicalId = radicals[(i + dir + radicals.length) % radicals.length].id;
    notifyListeners();
  }

  void jumpToRadicalByChar(String ch) {
    final r = radicalForChar(ch);
    if (r != null) openRadical(r.id);
  }

  // ------------------------------------------------------------ 3000 từ
  int? vocabHsk; // null = tất cả
  String vocabSearch = '';
  int? selectedVocabId;

  VocabItem? get selectedVocab => vocabById[selectedVocabId];

  void setVocabHsk(int? h) {
    vocabHsk = h;
    notifyListeners();
  }

  void setVocabSearch(String s) {
    vocabSearch = s;
    notifyListeners();
  }

  List<VocabItem> get filteredVocab {
    var list = vocab;
    if (vocabHsk != null) list = list.where((v) => v.hsk == vocabHsk).toList();
    final q = normalizeViQuery(vocabSearch.trim().toLowerCase());
    if (q.isNotEmpty) {
      final qp = stripTones(q);
      list = list
          .where((v) =>
              v.char.contains(vocabSearch.trim()) ||
              v.searchPy.contains(q) ||
              v.searchPyPlain.contains(qp) ||
              v.searchHv.contains(q))
          .toList();
    }
    return list;
  }

  void openVocab(int id) {
    tab = Module.vocab;
    vocabView = SubView.detail;
    selectedVocabId = id;
    notifyListeners();
    final v = vocabById[id];
    if (v != null && settings.autoAudio) tts.speak(v.char);
  }

  void vocabStep(int dir) {
    if (vocab.isEmpty) return;
    final i = vocab.indexWhere((v) => v.id == selectedVocabId);
    openVocab(vocab[(i + dir + vocab.length) % vocab.length].id);
  }

  VocabItem? vocabForChar(String ch) => vocab.where((v) => v.char == ch).firstOrNull;

  void jumpToVocabByChar(String ch) {
    final v = vocabForChar(ch);
    if (v != null) openVocab(v.id);
  }

  Future<void> speak(String text) async {
    final ok = await tts.speak(text);
    if (!ok) showToast('Máy chưa có giọng đọc tiếng Trung (zh-CN). Cài trong Cài đặt Android › Chuyển văn bản thành giọng nói.');
  }

  // ------------------------------------------------------------ từ điển
  String dictSearch = '';
  String dictField = 'hanviet'; // hanviet | char | pinyin
  String dictType = 'all'; // all | chars | phrases
  String dictInputMode = 'keyboard';
  int? dictRadical;
  DictSearchResult dictResult = DictSearchResult.empty;
  bool dictLoading = false;
  int _dictGen = 0;
  Timer? _dictDebounce;

  String? selectedDictChar;
  String dictDetailTab = 'chitiet';
  Set<String> decompExpanded = {};
  final List<String> dictHistory = [];

  bool get dictPromptEmpty => dictSearch.trim().isEmpty && dictRadical == null;

  void setDictSearch(String v) {
    dictSearch = v;
    _dictDebounce?.cancel();
    _dictDebounce = Timer(const Duration(milliseconds: 180), _runDictSearch);
    notifyListeners();
  }

  void setDictField(String v) {
    dictField = v;
    _runDictSearch();
  }

  void setDictType(String v) {
    dictType = v;
    _runDictSearch();
  }

  void setDictInputMode(String mode) {
    if (mode == 'handwriting') {
      showToast('Nhận diện chữ viết tay sẽ sớm ra mắt');
      return;
    }
    dictInputMode = mode;
    notifyListeners();
  }

  void selectDictRadical(int id) {
    dictRadical = id;
    dictType = 'chars';
    dictInputMode = 'keyboard';
    dictSearch = ''; // bắt buộc xoá, nếu không từ khoá cũ lọc tiếp → 0 kết quả
    _runDictSearch();
  }

  void clearDictRadical() {
    dictRadical = null;
    _runDictSearch();
  }

  Future<void> _runDictSearch() async {
    _dictDebounce?.cancel();
    final gen = ++_dictGen;
    if (dictPromptEmpty) {
      dictResult = DictSearchResult.empty;
      dictLoading = false;
      notifyListeners();
      return;
    }
    dictLoading = true;
    notifyListeners();
    try {
      final r = await ref.search(query: dictSearch, field: dictField, type: dictType, radicalId: dictRadical);
      if (gen != _dictGen) return;
      dictResult = r;
    } catch (e) {
      debugPrint('search failed: $e');
      if (gen != _dictGen) return;
      dictResult = DictSearchResult.empty;
    }
    dictLoading = false;
    notifyListeners();
  }

  void openDictDetail(String ch, {bool push = true}) {
    if (push && tab == Module.dictionary && dictView == SubView.detail && selectedDictChar != null) {
      dictHistory.add(selectedDictChar!);
    } else if (push) {
      dictHistory.clear();
    }
    tab = Module.dictionary;
    dictView = SubView.detail;
    selectedDictChar = ch;
    dictDetailTab = 'chitiet';
    decompExpanded = {};
    notifyListeners();
  }

  void dictBack() {
    if (dictHistory.isNotEmpty) {
      openDictDetail(dictHistory.removeLast(), push: false);
    } else {
      dictView = SubView.list;
      notifyListeners();
    }
  }

  void dictToList() {
    dictHistory.clear();
    dictView = SubView.list;
    notifyListeners();
  }

  void setDictDetailTab(String t) {
    dictDetailTab = t;
    notifyListeners();
  }

  void toggleDecomp(String path) {
    decompExpanded.contains(path) ? decompExpanded.remove(path) : decompExpanded.add(path);
    notifyListeners();
  }

  // ------------------------------------------------------------ tập viết
  String writingChar = '一';

  void setWritingChar(String ch) {
    writingChar = ch;
    tab = Module.writing;
    notifyListeners();
  }

  String writingQuery = '';
  List<DictEntry> writingResults = const [];
  bool writingSearching = false;
  Timer? _writingDebounce;
  int _writingGen = 0;

  void setWritingQuery(String q) {
    writingQuery = q;
    _writingDebounce?.cancel();
    _writingDebounce = Timer(const Duration(milliseconds: 180), _runWritingSearch);
    notifyListeners();
  }

  /// Tìm chữ đơn để luyện viết: gõ chữ Hán, âm Hán Việt hoặc pinyin đều được.
  Future<void> _runWritingSearch() async {
    _writingDebounce?.cancel();
    final gen = ++_writingGen;
    final q = writingQuery.trim();
    if (q.isEmpty) {
      writingResults = const [];
      writingSearching = false;
      notifyListeners();
      return;
    }
    writingSearching = true;
    notifyListeners();
    try {
      final hasHan = q.runes.any((r) => r >= 0x2E80 && r <= 0x9FFF);
      var res = await ref.search(query: q, field: hasHan ? 'char' : 'hanviet', type: 'chars', limit: 40);
      if (!hasHan && res.items.isEmpty) {
        res = await ref.search(query: q, field: 'pinyin', type: 'chars', limit: 40);
      }
      if (gen != _writingGen) return;
      writingResults = res.items;
    } catch (e) {
      debugPrint('writing search failed: $e');
      if (gen != _writingGen) return;
      writingResults = const [];
    }
    writingSearching = false;
    notifyListeners();
  }

  /// Chữ đơn trong Sổ từ vựng — nguồn thứ hai để chọn chữ tập viết.
  List<NotebookEntry> get notebookSingleChars =>
      notebook.where((n) => n.char.runes.length == 1).toList();

  ({String pinyin, String hanViet, String meaning})? writingInfo(String ch) {
    final r = radicals.where((x) => x.char == ch).firstOrNull;
    if (r != null) return (pinyin: r.pinyin, hanViet: r.hanViet, meaning: r.meaning);
    final v = vocabForChar(ch);
    if (v != null) return (pinyin: v.pinyin, hanViet: v.hanViet, meaning: v.meaning);
    final n = notebook.where((x) => x.char == ch).firstOrNull;
    if (n != null) return (pinyin: n.pinyin, hanViet: n.hanViet, meaning: n.meaning);
    final d = writingResults.where((x) => x.word == ch).firstOrNull;
    if (d != null) {
      final readings = splitReadings(d.hv);
      return (pinyin: d.pinyin, hanViet: readings.isEmpty ? '' : readings.first, meaning: d.meaning);
    }
    return null;
  }


  // ------------------------------------------------------------ thống kê theo thời gian
  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
  static int _dayKey(DateTime t) => t.year * 10000 + t.month * 100 + t.day;
  static int _daysBetween(DateTime a, DateTime b) => (_day(b).difference(_day(a)).inHours / 24).round();
  static const _weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  int get streakDays {
    var d = _day(DateTime.now());
    if (!activeDays.contains(_dayKey(d))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (activeDays.contains(_dayKey(d))) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  /// Đếm số từ khác nhau được ôn trong từng khoảng. [keys] = chỉ tính các từ này (null = tất cả).
  List<ChartBar> _buckets(
    List<String> labels,
    int Function(DateTime t) indexOf,
    bool Function(DateTime t) inRange, {
    Set<String>? keys,
  }) {
    final sets = List.generate(labels.length, (_) => <String>{});
    for (final e in reviewLog) {
      if (keys != null && !keys.contains(e.key)) continue;
      final t = DateTime.fromMillisecondsSinceEpoch(e.at);
      if (!inRange(t)) continue;
      final i = indexOf(t);
      if (i >= 0 && i < labels.length) sets[i].add(e.key);
    }
    return [for (var i = 0; i < labels.length; i++) ChartBar(labels[i], sets[i].length)];
  }

  List<ChartBar> get last7Days {
    final today = _day(DateTime.now());
    final start = DateTime(today.year, today.month, today.day - 6);
    final labels = [for (var i = 0; i < 7; i++) _weekdayLabels[DateTime(start.year, start.month, start.day + i).weekday - 1]];
    return _buckets(labels, (t) => _daysBetween(start, t), (t) => !t.isBefore(start));
  }

  // ------------------------------------------------------------ báo cáo (theo collection)
  String reportsRange = 'week';
  String reportsCollection = allCollectionId;
  Module reportsBack = Module.home;

  void setReportsRange(String r) {
    reportsRange = r;
    notifyListeners();
  }

  void setReportsCollection(String id) {
    reportsCollection = collectionExists(id) ? id : allCollectionId;
    notifyListeners();
  }

  /// Mở báo cáo của một collection; nút quay lại trở về [back].
  void openReports({String collectionId = allCollectionId, Module back = Module.home}) {
    reportsCollection = collectionExists(collectionId) ? collectionId : allCollectionId;
    reportsBack = back;
    tab = Module.reports;
    notifyListeners();
  }

  void reportsGoBack() {
    tab = reportsBack;
    notifyListeners();
  }

  String _typeLabel(NotebookEntry e) => (sourceMeta[e.source] ?? sourceMeta['dictionary']!).label;

  List<WeakItem> _retItems(String id) => [
        for (final e in entriesIn(id))
          if (retentionOf(e.key) != null) WeakItem(e.char, e.hanViet, _typeLabel(e), retentionOf(e.key)!),
      ];

  int retentionRateIn(String id) {
    final items = _retItems(id);
    if (items.isEmpty) return 0;
    return (items.fold<int>(0, (a, b) => a + b.retention) / items.length).round();
  }

  ({int good, int bad, bool hasData}) retentionSplitIn(String id) {
    final items = _retItems(id);
    if (items.isEmpty) return (good: 0, bad: 0, hasData: false);
    final good = (items.where((i) => i.retention >= 75).length / items.length * 100).round();
    return (good: good, bad: 100 - good, hasData: true);
  }

  List<WeakItem> weakListIn(String id, {int limit = 6}) {
    final items = _retItems(id).where((i) => i.retention < 75).toList()
      ..sort((a, b) => a.retention.compareTo(b.retention));
    return items.take(limit).toList();
  }

  List<ChartBar> reportChart(String range, {String collectionId = allCollectionId}) {
    final keys = keysIn(collectionId);
    final now = DateTime.now();
    final today = _day(now);
    switch (range) {
      case 'day':
        return _buckets(
          const ['6h', '9h', '12h', '15h', '18h', '21h'],
          (t) => t.hour < 8 ? 0 : t.hour < 11 ? 1 : t.hour < 14 ? 2 : t.hour < 17 ? 3 : t.hour < 20 ? 4 : 5,
          (t) => _day(t) == today,
          keys: keys,
        );
      case 'month':
        final start = DateTime(now.year, now.month, 1);
        return _buckets(
          const ['Tuần 1', 'Tuần 2', 'Tuần 3', 'Tuần 4'],
          (t) => math.min((t.day - 1) ~/ 7, 3),
          (t) => t.year == now.year && t.month == now.month && !t.isBefore(start),
          keys: keys,
        );
      default:
        final start = DateTime(today.year, today.month, today.day - (today.weekday - 1));
        return _buckets(_weekdayLabels, (t) => _daysBetween(start, t), (t) => !t.isBefore(start), keys: keys);
    }
  }

  /// Số lượt ôn (không phải số từ) của collection trong 7 ngày gần nhất.
  int reviewsLast7DaysIn(String id) {
    final keys = keysIn(id);
    final today = _day(DateTime.now());
    final start = DateTime(today.year, today.month, today.day - 6);
    return reviewLog
        .where((e) => keys.contains(e.key) && !DateTime.fromMillisecondsSinceEpoch(e.at).isBefore(start))
        .length;
  }

  List<ReportRow> reportRowsIn(String id) => [
        for (final e in entriesIn(id))
          ReportRow(_typeLabel(e), e.char, e.pinyin, e.hanViet, statusMeta[statusOf(e.key)]!.label, retentionOf(e.key)),
      ];

  // ------------------------------------------------------------ cài đặt
  Future<void> updateSettings(Settings s) async {
    settings = s;
    notifyListeners();
    await user.saveSettings(s);
  }

  Future<void> toggleRemind() async {
    if (settings.remind) {
      await updateSettings(settings.copyWith(remind: false));
      await reminder.disable();
      return;
    }
    await updateSettings(settings.copyWith(remind: true));
    final ok = await reminder.enable();
    if (!ok) {
      await updateSettings(settings.copyWith(remind: false));
      showToast('Chưa được cấp quyền gửi thông báo');
    }
  }

  Future<void> resetProgress() async {
    await user.resetStudyProgress();
    progress.clear();
    await _reloadLog();
    showToast('Đã đặt lại tiến độ Flashcard');
  }
}
