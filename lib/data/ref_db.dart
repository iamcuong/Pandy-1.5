import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Offset;

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'text_norm.dart';

/// DB tham chiếu chỉ đọc, đóng gói sẵn trong assets (sinh bởi tool/build_db.py).
/// Tách riêng với DB người dùng để cập nhật dữ liệu không làm mất tiến độ.
class RefDb {
  /// Tăng cùng lúc với REF_DB_VERSION trong tool/build_db.py.
  static const version = 1;
  static const _asset = 'assets/db/hanzi_ref.db';

  late final Database _db;

  Future<void> open() async {
    final dir = await getDatabasesPath();
    await Directory(dir).create(recursive: true);
    final path = p.join(dir, 'hanzi_ref.db');
    final marker = File(p.join(dir, 'hanzi_ref.version'));

    var needCopy = !File(path).existsSync();
    if (!needCopy) {
      final v = marker.existsSync() ? int.tryParse(marker.readAsStringSync().trim()) : null;
      needCopy = v != version;
    }
    if (needCopy) {
      final data = await rootBundle.load(_asset);
      final tmp = File('$path.tmp');
      await tmp.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      await tmp.rename(path);
      await marker.writeAsString('$version', flush: true);
    }
    _db = await openDatabase(path, readOnly: true, singleInstance: true);
  }

  // ---------------------------------------------------------------- bộ thủ
  Future<List<Radical>> radicals() async {
    final rows = await _db.query('radicals', orderBy: 'id');
    return rows
        .map((r) => Radical(
              id: r['id'] as int,
              char: r['char'] as String,
              hanViet: r['han_viet'] as String,
              meaning: (r['meaning'] as String?) ?? '',
              strokes: r['strokes'] as int,
              variant: r['variant'] as String?,
              pinyin: (r['pinyin'] as String?) ?? '',
            ))
        .toList();
  }

  /// Chữ (kể cả dạng biến thể) → số bộ thủ.
  Future<Map<String, int>> radicalLookup() async {
    final rows = await _db.query('radical_lookup');
    return {for (final r in rows) r['char'] as String: r['radical_id'] as int};
  }

  // ---------------------------------------------------------------- 3000 từ
  Future<List<VocabItem>> vocab() async {
    final comps = <int, List<VocabComp>>{};
    for (final r in await _db.query('vocab_components', orderBy: 'vocab_id, seq')) {
      comps.putIfAbsent(r['vocab_id'] as int, () => []).add(VocabComp(r['char'] as String, r['radical_id'] as int?));
    }
    final related = <int, List<VocabRelated>>{};
    for (final r in await _db.query('vocab_related', orderBy: 'vocab_id, seq')) {
      related.putIfAbsent(r['vocab_id'] as int, () => []).add(VocabRelated(
            char: r['char'] as String,
            traditional: r['traditional'] as String?,
            pinyin: (r['pinyin'] as String?) ?? '',
            hanViet: (r['han_viet'] as String?) ?? '',
            meaning: (r['meaning'] as String?) ?? '',
          ));
    }
    final rows = await _db.query('vocab', orderBy: 'id');
    return rows.map((r) {
      final id = r['id'] as int;
      return VocabItem(
        id: id,
        char: r['char'] as String,
        pinyin: (r['pinyin'] as String?) ?? '',
        hanViet: (r['han_viet'] as String?) ?? '',
        meaning: (r['meaning'] as String?) ?? '',
        hsk: r['hsk'] as int?,
        mnemonic: r['mnemonic'] as String?,
        giaiThich: r['giai_thich'] as String?,
        image: r['image_asset'] as String?,
        searchHv: (r['hv_lc'] as String?) ?? '',
        searchPy: (r['py_lc'] as String?) ?? '',
        searchPyPlain: (r['py_plain'] as String?) ?? '',
        comps: comps[id] ?? const [],
        related: related[id] ?? const [],
      );
    }).toList();
  }

  // ---------------------------------------------------------------- từ điển
  static String _esc(String s) => s.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');

  /// [field]: hanviet | char | pinyin · [type]: all | chars | phrases
  Future<DictSearchResult> search({
    required String query,
    required String field,
    required String type,
    int? radicalId,
    int limit = 60,
  }) async {
    final raw = query.trim();
    if (raw.isEmpty && radicalId == null) return DictSearchResult.empty;

    final includeChars = type != 'phrases';
    final includePhrases = type != 'chars' && radicalId == null;
    if (!includeChars && !includePhrases) return DictSearchResult.empty;

    final q = field == 'char' ? raw : normalizeViQuery(raw.toLowerCase());
    final like = '%${_esc(q)}%';
    final prefix = '${_esc(q)}%';
    final qPlain = stripTones(q);

    // (where, whereArgs, rank, rankArgs) cho từng bảng
    ({String where, List<Object?> args, String rank, List<Object?> rankArgs}) part(String wordCol, bool isChar) {
      final conds = <String>[];
      final args = <Object?>[];
      var rank = '0';
      var rankArgs = <Object?>[];
      if (raw.isNotEmpty) {
        switch (field) {
          case 'char':
            conds.add("$wordCol LIKE ? ESCAPE '\\'");
            args.add(like);
            rank = 'CASE WHEN $wordCol = ? THEN 0 ELSE 1 END';
            rankArgs = [q];
          case 'pinyin':
            conds.add("(py_lc LIKE ? ESCAPE '\\' OR py_plain LIKE ? ESCAPE '\\')");
            args.addAll([like, '%${_esc(qPlain)}%']);
            rank = isChar
                ? "CASE WHEN (', '||py_lc||', ') LIKE ? ESCAPE '\\' THEN 0 WHEN py_plain = ? THEN 1 ELSE 2 END"
                : "CASE WHEN py_lc = ? OR py_plain = ? THEN 0 ELSE 2 END";
            rankArgs = isChar ? ['%, ${_esc(q)}, %', qPlain] : [q, qPlain];
          default: // hanviet
            conds.add("hv_lc LIKE ? ESCAPE '\\'");
            args.add(like);
            rank = isChar
                ? "CASE WHEN (' '||hv_lc||' ') LIKE ? ESCAPE '\\' THEN 0 WHEN hv_lc LIKE ? ESCAPE '\\' THEN 1 ELSE 2 END"
                : "CASE WHEN hv_lc = ? THEN 0 WHEN hv_lc LIKE ? ESCAPE '\\' THEN 1 ELSE 2 END";
            rankArgs = isChar ? ['% ${_esc(q)} %', prefix] : [q, prefix];
        }
      }
      if (isChar && radicalId != null) {
        conds.add('radical_id = ?');
        args.add(radicalId);
      }
      return (where: conds.isEmpty ? '1' : conds.join(' AND '), args: args, rank: rank, rankArgs: rankArgs);
    }

    final selects = <String>[];
    final selectArgs = <Object?>[];
    final counts = <String>[];
    final countArgs = <Object?>[];

    if (includeChars) {
      final c = part('char', true);
      selects.add('SELECT 0 AS kind, char AS w, pinyin, han_viet, short_mean, radical_id, '
          '${c.rank} AS rk, rowid AS rid FROM chars WHERE ${c.where}');
      selectArgs
        ..addAll(c.rankArgs)
        ..addAll(c.args);
      counts.add('(SELECT COUNT(*) FROM chars WHERE ${c.where})');
      countArgs.addAll(c.args);
    }
    if (includePhrases) {
      final ph = part('word', false);
      selects.add('SELECT 1 AS kind, word AS w, pinyin, han_viet, short_mean, NULL AS radical_id, '
          '${ph.rank} AS rk, id AS rid FROM phrases WHERE ${ph.where}');
      selectArgs
        ..addAll(ph.rankArgs)
        ..addAll(ph.args);
      counts.add('(SELECT COUNT(*) FROM phrases WHERE ${ph.where})');
      countArgs.addAll(ph.args);
    }

    final rows = await _db.rawQuery(
      '${selects.join(' UNION ALL ')} ORDER BY rk, kind, rid LIMIT ?',
      [...selectArgs, limit],
    );
    final total = Sqflite.firstIntValue(await _db.rawQuery('SELECT ${counts.join(' + ')}', countArgs)) ?? 0;

    return DictSearchResult(
      rows
          .map((r) => DictEntry(
                isPhrase: r['kind'] == 1,
                word: r['w'] as String,
                pinyin: (r['pinyin'] as String?) ?? '',
                hv: (r['han_viet'] as String?) ?? '',
                meaning: (r['short_mean'] as String?) ?? '',
                radicalId: r['radical_id'] as int?,
              ))
          .toList(),
      total,
    );
  }

  Future<CharDetail?> charDetail(String ch) async {
    final compact = await _db.query('chars', where: 'char = ?', whereArgs: [ch], limit: 1);
    final rich = await _db.query('char_detail', where: 'char = ?', whereArgs: [ch], limit: 1);
    if (compact.isEmpty && rich.isEmpty) return null;
    final c = compact.isEmpty ? null : compact.first;
    final d = rich.isEmpty ? null : rich.first;

    var blocks = <DetailBlock>[];
    if (d != null) {
      final rows = await _db.query('char_detail_blocks', where: 'char = ?', whereArgs: [ch], orderBy: 'seq');
      blocks = rows
          .map((b) => DetailBlock(
                type: b['type'] as String,
                text: b['text'] as String?,
                exChar: b['ex_char'] as String?,
                exHv: b['ex_han_viet'] as String?,
                exMean: b['ex_mean'] as String?,
              ))
          .toList();
    } else if (c != null && ((c['short_mean'] as String?) ?? '').isNotEmpty) {
      blocks = [DetailBlock(type: 'heading', text: c['short_mean'] as String)];
    }

    return CharDetail(
      char: ch,
      pinyin: ((d ?? c)!['pinyin'] as String?) ?? '',
      hv: ((d ?? c)!['han_viet'] as String?) ?? '',
      shortMean: (c?['short_mean'] as String?) ?? '',
      strokeCount: (d?['stroke_count'] ?? c?['stroke_count']) as int?,
      radicalId: (d?['radical_id'] ?? c?['radical_id']) as int?,
      blocks: blocks,
    );
  }

  Future<List<DictEntry>> phrasesContaining(String ch, {int limit = 40}) async {
    final rows = await _db.query(
      'phrases',
      where: "word LIKE ? ESCAPE '\\'",
      whereArgs: ['%${_esc(ch)}%'],
      orderBy: 'id',
      limit: limit,
    );
    return rows
        .map((r) => DictEntry(
              isPhrase: true,
              word: r['word'] as String,
              pinyin: (r['pinyin'] as String?) ?? '',
              hv: (r['han_viet'] as String?) ?? '',
              meaning: (r['short_mean'] as String?) ?? '',
            ))
        .toList();
  }

  final _idsCache = <String, String?>{};
  Future<String?> ids(String ch) async {
    if (_idsCache.containsKey(ch)) return _idsCache[ch];
    final r = await _db.query('decomposition', columns: ['ids'], where: 'char = ?', whereArgs: [ch], limit: 1);
    return _idsCache[ch] = r.isEmpty ? null : r.first['ids'] as String;
  }

  final _hvCache = <String, String>{};
  Future<String> firstReading(String ch) async {
    final hit = _hvCache[ch];
    if (hit != null) return hit;
    final r = await _db.query('chars', columns: ['han_viet'], where: 'char = ?', whereArgs: [ch], limit: 1);
    final readings = r.isEmpty ? const <String>[] : splitReadings(r.first['han_viet'] as String?);
    return _hvCache[ch] = readings.isEmpty ? '' : readings.first;
  }

  final _strokeCache = <String, StrokeData?>{};
  Future<StrokeData?> strokes(String ch) async {
    if (_strokeCache.containsKey(ch)) return _strokeCache[ch];
    final r = await _db.query('strokes', columns: ['data'], where: 'char = ?', whereArgs: [ch], limit: 1);
    if (r.isEmpty) return _strokeCache[ch] = null;
    final bytes = r.first['data'] as List<int>;
    final json = jsonDecode(utf8.decode(zlib.decode(bytes))) as Map<String, dynamic>;
    final strokes = (json['s'] as List).cast<String>();
    final medians = (json['m'] as List)
        .map((stroke) => (stroke as List)
            .map((pt) => Offset(((pt as List)[0] as num).toDouble(), (pt[1] as num).toDouble()))
            .toList())
        .toList();
    return _strokeCache[ch] = StrokeData(strokes, medians);
  }
}
