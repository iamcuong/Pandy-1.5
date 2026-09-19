#!/usr/bin/env python3
"""
Build-time script: gộp toàn bộ dữ liệu tham chiếu thành 1 file SQLite đóng gói vào app.

    python3 tool/build_db.py            # -> assets/db/hanzi_ref.db

Nguồn:
  tool/data/radicals-full.json   214 bộ thủ
  tool/data/dict-chars.json      15.591 chữ đơn
  tool/data/dict-phrases.json    8.384 từ ghép
  tool/data/dict-detail.json     nghĩa chi tiết có cấu trúc
  tool/data/vocab.json           module "3000 từ" (hiện 16 từ mẫu — thay bằng bộ đầy đủ)
  tool/data/graphics.txt         makemeahanzi — nét viết (tự tải nếu thiếu)
  tool/data/dictionary.txt       makemeahanzi — cấu tạo chữ IDS (tự tải nếu thiếu)

Mỗi lần dữ liệu thay đổi, tăng REF_DB_VERSION (và hằng số cùng tên trong
lib/data/ref_db.dart) để app chép lại DB mới khi cập nhật.
"""
import json
import os
import sqlite3
import sys
import unicodedata
import urllib.request
import zlib

REF_DB_VERSION = 1

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "tool", "data")
OUT = os.path.join(ROOT, "assets", "db", "hanzi_ref.db")

MMAH_BASE = "https://raw.githubusercontent.com/skishore/makemeahanzi/master/"

# Biến thể bộ thủ không có trong radicals-full.json nhưng hay gặp trong cấu tạo chữ.
EXTRA_VARIANTS = {"⺮": 118, "⺌": 42, "⺍": 42, "⻊": 157, "⺼": 130, "⻏": 163, "⻖": 170}


def ensure_mmah(name):
    path = os.path.join(DATA, name)
    if not os.path.exists(path):
        print(f"Đang tải {name} từ makemeahanzi ...")
        urllib.request.urlretrieve(MMAH_BASE + name, path)
    return path


def load(name):
    with open(os.path.join(DATA, name), encoding="utf-8") as f:
        return json.load(f)


def lc(s):
    return (s or "").strip().lower()


def plain(s):
    """Bỏ dấu thanh pinyin: 'nǚ ér' -> 'nu er', 'lǜ' -> 'lu'."""
    s = unicodedata.normalize("NFD", lc(s))
    s = "".join(ch for ch in s if unicodedata.category(ch) != "Mn")
    return s.replace("ü", "u")


SCHEMA = """
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);

CREATE TABLE radicals (
  id INTEGER PRIMARY KEY,
  char TEXT NOT NULL,
  han_viet TEXT NOT NULL,
  meaning TEXT,
  strokes INTEGER NOT NULL,
  variant TEXT,
  pinyin TEXT
);
CREATE TABLE radical_lookup (char TEXT PRIMARY KEY, radical_id INTEGER NOT NULL);

CREATE TABLE chars (
  char TEXT PRIMARY KEY,
  pinyin TEXT, han_viet TEXT, short_mean TEXT,
  radical_id INTEGER, stroke_count INTEGER,
  hv_lc TEXT, py_lc TEXT, py_plain TEXT
);
CREATE INDEX idx_chars_radical ON chars(radical_id);

CREATE TABLE phrases (
  id INTEGER PRIMARY KEY,
  word TEXT NOT NULL,
  pinyin TEXT, han_viet TEXT, short_mean TEXT, simplified TEXT,
  hv_lc TEXT, py_lc TEXT, py_plain TEXT
);

CREATE TABLE char_detail (
  char TEXT PRIMARY KEY,
  pinyin TEXT, han_viet TEXT, radical_id INTEGER, stroke_count INTEGER
);
CREATE TABLE char_detail_blocks (
  char TEXT NOT NULL,
  seq INTEGER NOT NULL,
  type TEXT NOT NULL,
  text TEXT, ex_char TEXT, ex_han_viet TEXT, ex_mean TEXT,
  PRIMARY KEY (char, seq)
);

CREATE TABLE decomposition (char TEXT PRIMARY KEY, ids TEXT NOT NULL);

-- data = zlib(JSON {"s":[svg path...], "m":[[[x,y],...],...]})
CREATE TABLE strokes (char TEXT PRIMARY KEY, data BLOB NOT NULL);

CREATE TABLE vocab (
  id INTEGER PRIMARY KEY,
  char TEXT NOT NULL,
  pinyin TEXT, han_viet TEXT, meaning TEXT,
  hsk INTEGER, mnemonic TEXT, giai_thich TEXT, image_asset TEXT,
  hv_lc TEXT, py_lc TEXT, py_plain TEXT
);
CREATE TABLE vocab_components (vocab_id INTEGER, seq INTEGER, char TEXT, radical_id INTEGER);
CREATE TABLE vocab_related (
  vocab_id INTEGER, seq INTEGER,
  char TEXT, traditional TEXT, pinyin TEXT, han_viet TEXT, meaning TEXT
);
"""


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    if os.path.exists(OUT):
        os.remove(OUT)
    db = sqlite3.connect(OUT)
    db.executescript(SCHEMA)

    db.execute("INSERT INTO meta VALUES ('version', ?)", (str(REF_DB_VERSION),))

    # --- radicals
    radicals = load("radicals-full.json")
    lookup = {}
    for r in radicals:
        db.execute(
            "INSERT INTO radicals VALUES (?,?,?,?,?,?,?)",
            (r["id"], r["char"], r["hanViet"], r["meaning"], r["strokes"], r["variant"] or None, r["pinyin"]),
        )
        lookup.setdefault(r["char"], r["id"])
        for v in (r["variant"] or "").split(","):
            v = v.strip()
            if v:
                lookup.setdefault(v, r["id"])
    for ch, rid in EXTRA_VARIANTS.items():
        lookup.setdefault(ch, rid)
    db.executemany("INSERT INTO radical_lookup VALUES (?,?)", lookup.items())

    # --- chars
    for c in load("dict-chars.json"):
        db.execute(
            "INSERT INTO chars VALUES (?,?,?,?,?,?,?,?,?)",
            (c["w"], c["py"], c["hv"], c["m"], c.get("r"), c.get("s"), lc(c["hv"]), lc(c["py"]), plain(c["py"])),
        )

    # --- phrases
    for p in load("dict-phrases.json"):
        db.execute(
            "INSERT INTO phrases (word,pinyin,han_viet,short_mean,simplified,hv_lc,py_lc,py_plain) VALUES (?,?,?,?,?,?,?,?)",
            (p["w"], p["py"], p["hv"], p["m"], p.get("sp") or None, lc(p["hv"]), lc(p["py"]), plain(p["py"])),
        )

    # --- detail
    for d in load("dict-detail.json"):
        db.execute(
            "INSERT INTO char_detail VALUES (?,?,?,?,?)",
            (d["w"], d["py"], d["hv"], d.get("radicalId"), d.get("stroke")),
        )
        for i, b in enumerate(d["blocks"]):
            if b["type"] == "example":
                db.execute(
                    "INSERT INTO char_detail_blocks VALUES (?,?,?,?,?,?,?)",
                    (d["w"], i, "example", None, b.get("ch"), b.get("hv"), b.get("mean")),
                )
            else:
                db.execute(
                    "INSERT INTO char_detail_blocks VALUES (?,?,?,?,?,?,?)",
                    (d["w"], i, b["type"], b.get("text"), None, None, None),
                )

    # --- makemeahanzi
    with open(ensure_mmah("dictionary.txt"), encoding="utf-8") as f:
        for line in f:
            if not line.strip():
                continue
            o = json.loads(line)
            ids = o.get("decomposition") or ""
            if ids:
                db.execute("INSERT OR REPLACE INTO decomposition VALUES (?,?)", (o["character"], ids))
    n_strokes = 0
    with open(ensure_mmah("graphics.txt"), encoding="utf-8") as f:
        for line in f:
            if not line.strip():
                continue
            o = json.loads(line)
            blob = json.dumps({"s": o["strokes"], "m": o["medians"]}, separators=(",", ":"))
            db.execute(
                "INSERT OR REPLACE INTO strokes VALUES (?,?)",
                (o["character"], zlib.compress(blob.encode("utf-8"), 9)),
            )
            n_strokes += 1

    # --- vocab (module 3000 từ)
    vocab = load("vocab.json")
    for v in vocab:
        db.execute(
            "INSERT INTO vocab VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                v["id"], v["char"], v["pinyin"], v["hanViet"], v["meaning"], v.get("hsk"),
                v.get("mnemonic"), v.get("giaiThich"), v.get("image"),
                lc(v["hanViet"]), lc(v["pinyin"]), plain(v["pinyin"]),
            ),
        )
        for i, ch in enumerate(v.get("components") or []):
            db.execute(
                "INSERT INTO vocab_components VALUES (?,?,?,?)", (v["id"], i, ch, lookup.get(ch))
            )
        for i, r in enumerate(v.get("related") or []):
            db.execute(
                "INSERT INTO vocab_related VALUES (?,?,?,?,?,?,?)",
                (v["id"], i, r["char"], r.get("traditional"), r.get("pinyin"), r.get("hanViet"), r.get("meaning")),
            )

    db.commit()
    db.execute("VACUUM")
    db.close()
    size = os.path.getsize(OUT) / 1024 / 1024
    print(f"OK → {OUT} ({size:.1f} MB) · {len(radicals)} bộ thủ · {n_strokes} chữ có nét viết · {len(vocab)} từ vựng")


if __name__ == "__main__":
    sys.exit(main())
