#!/usr/bin/env sh
# Tạo font CJK rút gọn cho file PDF báo cáo (chỉ cần chạy lại khi bộ chữ thay đổi).
# Cần: pip install fonttools
set -e
cd "$(dirname "$0")"
curl -sSfL -o /tmp/NotoSansSC-var.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf"
python3 -c "
from fontTools.varLib import instancer
from fontTools.ttLib import TTFont
instancer.instantiateVariableFont(TTFont('/tmp/NotoSansSC-var.ttf'), {'wght': 400}).save('/tmp/NotoSansSC-400.ttf')
"
# pdf_font_chars.txt: toàn bộ chữ có nét viết + bộ thủ + 3000 từ + chữ cái pinyin có dấu
pyftsubset /tmp/NotoSansSC-400.ttf --text-file=pdf_font_chars.txt \
  --output-file=../assets/fonts/NotoSansSC-Report.ttf \
  --layout-features='' --no-hinting --desubroutinize --drop-tables+=vhea,vmtx,BASE,STAT
echo "OK → assets/fonts/NotoSansSC-Report.ttf"
