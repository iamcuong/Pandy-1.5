import 'dart:ui' show Offset;

class Radical {
  final int id; // số Khang Hi 1..214
  final String char;
  final String hanViet; // in hoa
  final String meaning;
  final int strokes;
  final String? variant;
  final String pinyin;

  const Radical({
    required this.id,
    required this.char,
    required this.hanViet,
    required this.meaning,
    required this.strokes,
    required this.variant,
    required this.pinyin,
  });

  String get key => 'radical:$id';
}

class VocabComp {
  final String char;
  final int? radicalId;
  const VocabComp(this.char, this.radicalId);
}

class VocabRelated {
  final String char;
  final String? traditional;
  final String pinyin;
  final String hanViet;
  final String meaning;
  const VocabRelated({
    required this.char,
    this.traditional,
    required this.pinyin,
    required this.hanViet,
    required this.meaning,
  });
}

class VocabItem {
  final int id;
  final String char;
  final String pinyin;
  final String hanViet;
  final String meaning;
  final int? hsk;
  final String? mnemonic;
  final String? giaiThich;
  final String? image;
  final String searchHv;
  final String searchPy;
  final String searchPyPlain;
  final List<VocabComp> comps;
  final List<VocabRelated> related;

  const VocabItem({
    required this.id,
    required this.char,
    required this.pinyin,
    required this.hanViet,
    required this.meaning,
    this.hsk,
    this.mnemonic,
    this.giaiThich,
    this.image,
    required this.searchHv,
    required this.searchPy,
    required this.searchPyPlain,
    required this.comps,
    required this.related,
  });

  String get key => 'vocab:$id';
}

class DictEntry {
  final bool isPhrase;
  final String word;
  final String pinyin;
  final String hv;
  final String meaning;
  final int? radicalId;
  const DictEntry({
    required this.isPhrase,
    required this.word,
    required this.pinyin,
    required this.hv,
    required this.meaning,
    this.radicalId,
  });
}

class DictSearchResult {
  final List<DictEntry> items;
  final int total;
  const DictSearchResult(this.items, this.total);
  static const empty = DictSearchResult([], 0);
}

class DetailBlock {
  final String type; // heading | sub | note | example
  final String? text;
  final String? exChar;
  final String? exHv;
  final String? exMean;
  const DetailBlock({required this.type, this.text, this.exChar, this.exHv, this.exMean});
}

class CharDetail {
  final String char;
  final String pinyin;
  final String hv; // nhiều âm, cách nhau khoảng trắng
  final String shortMean;
  final int? strokeCount;
  final int? radicalId;
  final List<DetailBlock> blocks;
  const CharDetail({
    required this.char,
    required this.pinyin,
    required this.hv,
    required this.shortMean,
    required this.strokeCount,
    required this.radicalId,
    required this.blocks,
  });

  List<String> get readings => splitReadings(hv);
}

List<String> splitReadings(String? hv) =>
    (hv ?? '').trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

class NotebookEntry {
  final String id;
  final String char;
  final String pinyin;
  final String hanViet;
  final String meaning;
  final String source; // dictionary | radical | vocab
  final int addedAt;

  const NotebookEntry({
    required this.id,
    required this.char,
    required this.pinyin,
    required this.hanViet,
    required this.meaning,
    required this.source,
    required this.addedAt,
  });

  String get key => 'notebook:$id';

  Map<String, Object?> toRow() => {
        'id': id,
        'char': char,
        'pinyin': pinyin,
        'han_viet': hanViet,
        'meaning': meaning,
        'source': source,
        'added_at': addedAt,
      };

  static NotebookEntry fromRow(Map<String, Object?> r) => NotebookEntry(
        id: r['id'] as String,
        char: r['char'] as String,
        pinyin: (r['pinyin'] as String?) ?? '',
        hanViet: (r['han_viet'] as String?) ?? '',
        meaning: (r['meaning'] as String?) ?? '',
        source: r['source'] as String,
        addedAt: r['added_at'] as int,
      );
}

/// Collection con trong Từ cá nhân — một từ có thể nằm trong nhiều collection.
class WordCollection {
  final String id;
  final String name;
  final int createdAt;

  const WordCollection({required this.id, required this.name, required this.createdAt});

  WordCollection copyWith({String? name}) => WordCollection(id: id, name: name ?? this.name, createdAt: createdAt);

  Map<String, Object?> toRow() => {'id': id, 'name': name, 'created_at': createdAt};

  static WordCollection fromRow(Map<String, Object?> r) => WordCollection(
        id: r['id'] as String,
        name: r['name'] as String,
        createdAt: r['created_at'] as int,
      );
}

class Progress {
  final String key;
  final String status; // new | learning | mastered
  final int? retention; // 0..100
  final int? dueAt; // epoch ms
  final double intervalDays;
  final double ease;
  final int? reviewedAt;
  final int? introducedAt; // lần đầu được học (để tính "mới còn lại hôm nay")

  const Progress({
    required this.key,
    required this.status,
    this.retention,
    this.dueAt,
    this.intervalDays = 0,
    this.ease = 2.5,
    this.reviewedAt,
    this.introducedAt,
  });

  Map<String, Object?> toRow() => {
        'item_key': key,
        'status': status,
        'retention': retention,
        'due_at': dueAt,
        'interval_days': intervalDays,
        'ease': ease,
        'reviewed_at': reviewedAt,
        'introduced_at': introducedAt,
      };

  static Progress fromRow(Map<String, Object?> r) => Progress(
        key: r['item_key'] as String,
        status: r['status'] as String,
        retention: r['retention'] as int?,
        dueAt: r['due_at'] as int?,
        intervalDays: ((r['interval_days'] as num?) ?? 0).toDouble(),
        ease: ((r['ease'] as num?) ?? 2.5).toDouble(),
        reviewedAt: r['reviewed_at'] as int?,
        introducedAt: r['introduced_at'] as int?,
      );
}

class ReviewLogEntry {
  final String key;
  final String rating;
  final int at;
  const ReviewLogEntry(this.key, this.rating, this.at);
}

class Settings {
  final int radicalsPerDay;
  final int vocabPerDay;
  final bool remind;
  final bool autoAudio;
  final bool showTraditional;

  const Settings({
    this.radicalsPerDay = 5,
    this.vocabPerDay = 10,
    this.remind = true,
    this.autoAudio = true,
    this.showTraditional = true,
  });

  Settings copyWith({int? radicalsPerDay, int? vocabPerDay, bool? remind, bool? autoAudio, bool? showTraditional}) =>
      Settings(
        radicalsPerDay: radicalsPerDay ?? this.radicalsPerDay,
        vocabPerDay: vocabPerDay ?? this.vocabPerDay,
        remind: remind ?? this.remind,
        autoAudio: autoAudio ?? this.autoAudio,
        showTraditional: showTraditional ?? this.showTraditional,
      );

  Map<String, String> toMap() => {
        'radicalsPerDay': '$radicalsPerDay',
        'vocabPerDay': '$vocabPerDay',
        'remind': remind ? '1' : '0',
        'autoAudio': autoAudio ? '1' : '0',
        'showTraditional': showTraditional ? '1' : '0',
      };

  static Settings fromMap(Map<String, String> m) {
    const d = Settings();
    int i(String k, int def) => int.tryParse(m[k] ?? '') ?? def;
    bool b(String k, bool def) => m[k] == null ? def : m[k] == '1';
    return Settings(
      radicalsPerDay: i('radicalsPerDay', d.radicalsPerDay),
      vocabPerDay: i('vocabPerDay', d.vocabPerDay),
      remind: b('remind', d.remind),
      autoAudio: b('autoAudio', d.autoAudio),
      showTraditional: b('showTraditional', d.showTraditional),
    );
  }
}

/// Dữ liệu nét viết (makemeahanzi): toạ độ 1024×1024, trục Y lật.
class StrokeData {
  final List<String> strokes;
  final List<List<Offset>> medians;
  const StrokeData(this.strokes, this.medians);
}

/// Thẻ ôn tập dùng chung cho 3 module.
class StudyItem {
  final String key;
  final String char;
  final String pinyin;
  final String hanViet;
  final String meaning;
  const StudyItem(this.key, this.char, this.pinyin, this.hanViet, this.meaning);
}
