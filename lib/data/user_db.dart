import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// DB ghi runtime của người dùng: tiến độ, từ cá nhân, collection, nhật ký ôn tập, cài đặt.
class UserDb {
  late final Database _db;

  Future<void> open() async {
    final path = p.join(await getDatabasesPath(), 'user.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE progress (
            item_key TEXT PRIMARY KEY,
            status TEXT NOT NULL,
            retention INTEGER,
            due_at INTEGER,
            interval_days REAL,
            ease REAL,
            reviewed_at INTEGER,
            introduced_at INTEGER
          )''');
        await db.execute('''
          CREATE TABLE notebook (
            id TEXT PRIMARY KEY,
            char TEXT NOT NULL UNIQUE,
            pinyin TEXT, han_viet TEXT, meaning TEXT,
            source TEXT NOT NULL,
            added_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE review_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_key TEXT NOT NULL,
            rating TEXT NOT NULL,
            reviewed_at INTEGER NOT NULL
          )''');
        await db.execute('CREATE INDEX idx_review_log_at ON review_log(reviewed_at)');
        await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)');
        await _createCollectionTables(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await _createCollectionTables(db);
          // Flashcard giờ chỉ học từ trong Từ cá nhân — bỏ tiến độ flashcard cũ của Bộ thủ / 3000 từ.
          const where = "item_key LIKE 'radical:%' OR item_key LIKE 'vocab:%'";
          await db.delete('progress', where: where);
          await db.delete('review_log', where: where);
        }
      },
    );
  }

  static Future<void> _createCollectionTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS collections (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS collection_items (
        collection_id TEXT NOT NULL,
        entry_id TEXT NOT NULL,
        added_at INTEGER NOT NULL,
        PRIMARY KEY (collection_id, entry_id)
      )''');
  }

  // ---- progress
  Future<Map<String, Progress>> loadProgress() async {
    final rows = await _db.query('progress');
    return {for (final r in rows) r['item_key'] as String: Progress.fromRow(r)};
  }

  Future<void> saveProgress(Progress pr) =>
      _db.insert('progress', pr.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> deleteProgress(String key) => _db.delete('progress', where: 'item_key = ?', whereArgs: [key]);

  /// Xoá toàn bộ tiến độ flashcard và nhật ký ôn (giữ nguyên từ và collection).
  Future<void> resetStudyProgress() async {
    await _db.transaction((txn) async {
      await txn.delete('progress');
      await txn.delete('review_log');
    });
  }

  // ---- notebook
  Future<List<NotebookEntry>> loadNotebook() async {
    final rows = await _db.query('notebook', orderBy: 'added_at');
    return rows.map(NotebookEntry.fromRow).toList();
  }

  Future<void> addNotebook(NotebookEntry e) =>
      _db.insert('notebook', e.toRow(), conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<void> removeNotebook(String id) async {
    await _db.transaction((txn) async {
      await txn.delete('notebook', where: 'id = ?', whereArgs: [id]);
      await txn.delete('collection_items', where: 'entry_id = ?', whereArgs: [id]);
      await txn.delete('progress', where: 'item_key = ?', whereArgs: ['notebook:$id']);
      await txn.delete('review_log', where: 'item_key = ?', whereArgs: ['notebook:$id']);
    });
  }

  Future<void> clearNotebook() async {
    await _db.transaction((txn) async {
      await txn.delete('notebook');
      await txn.delete('collection_items');
      await txn.delete('progress', where: "item_key LIKE 'notebook:%'");
      await txn.delete('review_log', where: "item_key LIKE 'notebook:%'");
    });
  }

  // ---- collections
  Future<List<WordCollection>> loadCollections() async {
    final rows = await _db.query('collections', orderBy: 'created_at');
    return rows.map(WordCollection.fromRow).toList();
  }

  /// collection id → tập id các từ trong Từ cá nhân.
  Future<Map<String, Set<String>>> loadCollectionItems() async {
    final rows = await _db.query('collection_items', columns: ['collection_id', 'entry_id']);
    final m = <String, Set<String>>{};
    for (final r in rows) {
      m.putIfAbsent(r['collection_id'] as String, () => <String>{}).add(r['entry_id'] as String);
    }
    return m;
  }

  Future<void> saveCollection(WordCollection c) =>
      _db.insert('collections', c.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> deleteCollection(String id) async {
    await _db.transaction((txn) async {
      await txn.delete('collections', where: 'id = ?', whereArgs: [id]);
      await txn.delete('collection_items', where: 'collection_id = ?', whereArgs: [id]);
    });
  }

  Future<void> setCollectionMember(String collectionId, String entryId, bool member) async {
    if (member) {
      await _db.insert(
        'collection_items',
        {'collection_id': collectionId, 'entry_id': entryId, 'added_at': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } else {
      await _db.delete('collection_items',
          where: 'collection_id = ? AND entry_id = ?', whereArgs: [collectionId, entryId]);
    }
  }

  // ---- review log
  Future<void> logReview(String key, String rating, int at) =>
      _db.insert('review_log', {'item_key': key, 'rating': rating, 'reviewed_at': at});

  Future<List<ReviewLogEntry>> loadReviewLog({required int since}) async {
    final rows = await _db.query(
      'review_log',
      columns: ['item_key', 'rating', 'reviewed_at'],
      where: 'reviewed_at >= ?',
      whereArgs: [since],
      orderBy: 'reviewed_at',
    );
    return rows
        .map((r) => ReviewLogEntry(r['item_key'] as String, r['rating'] as String, r['reviewed_at'] as int))
        .toList();
  }

  /// Các ngày (yyyymmdd, giờ máy) có ít nhất một lượt ôn — để tính chuỗi ngày học.
  Future<Set<int>> activeDays() async {
    final rows = await _db.rawQuery(
      "SELECT DISTINCT CAST(strftime('%Y%m%d', reviewed_at / 1000, 'unixepoch', 'localtime') AS INTEGER) AS d "
      'FROM review_log',
    );
    return {for (final r in rows) r['d'] as int};
  }

  // ---- settings
  Future<Settings> loadSettings() async {
    final rows = await _db.query('settings');
    return Settings.fromMap({for (final r in rows) r['key'] as String: (r['value'] as String?) ?? ''});
  }

  Future<void> saveSettings(Settings s) async {
    final batch = _db.batch();
    s.toMap().forEach((k, v) {
      batch.insert('settings', {'key': k, 'value': v}, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await batch.commit(noResult: true);
  }
}
