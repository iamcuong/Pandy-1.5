# Học tiếng Trung — Flutter (Android, offline)

Bản dựng Flutter của thiết kế `Ứng dụng học tiếng Trung.dc.html`. App chạy **offline hoàn toàn**: từ điển, nét viết và cấu tạo chữ đều nằm trong `assets/db/hanzi_ref.db`.

## Chạy lần đầu

Yêu cầu: Flutter **3.27 trở lên** (Dart ≥ 3.5) và Android SDK.

```powershell
# Windows
.\setup.ps1
flutter run                     # chạy trên máy/giả lập
flutter build apk --release     # xuất APK: build/app/outputs/flutter-apk/app-release.apk
```

Trên macOS/Linux thì chạy `sh setup.sh` thay cho bước đầu.

`setup` gọi `flutter create .` để sinh các file Android chuẩn còn thiếu (gradle wrapper, icon, theme). Lệnh này **không ghi đè** các file đã có sẵn: `lib/`, `android/app/build.gradle.kts`, `AndroidManifest.xml`, `MainActivity.kt`.

Trước khi đưa lên Play Store, cần thay `signingConfig` ở `android/app/build.gradle.kts` bằng keystore thật.

## Cấu trúc

```
lib/
  main.dart                  khởi động, màn chờ copy DB
  theme/tokens.dart          design tokens (màu, chữ, shadow, badge HSK/trạng thái/nguồn)
  data/
    ref_db.dart              DB tham chiếu chỉ đọc (từ điển, bộ thủ, 3000 từ, nét viết, IDS)
    user_db.dart             DB người dùng (progress, notebook, review_log, settings)
    srs.dart                 lịch ôn kiểu SM-2, 4 mức Quên/Khó/Tốt/Dễ
    text_norm.dart           chuẩn hoá từ khoá (hoà→hòa, bỏ dấu pinyin)
    models.dart
  state/app_state.dart       toàn bộ state + điều hướng drawer/breadcrumb + nút Back
  services/
    export_service.dart      xuất CSV (có BOM) và PDF → Tải xuống + share sheet
    platform_services.dart   TTS zh-CN, nhắc ôn hằng ngày
  ui/
    shell.dart               app bar + breadcrumb, drawer, toast
    widgets/stroke_writer.dart   vẽ nét, hoạt hoạ thứ tự nét, chấm điểm tập viết
    widgets/common.dart      card, nút, pill, chip, progress bar, ô tìm kiếm...
    screens/                 12 màn hình theo README thiết kế
android/app/src/main/kotlin/.../MainActivity.kt   ghi file vào Tải xuống qua MediaStore
tool/
  build_db.py                JSON + makemeahanzi → assets/db/hanzi_ref.db
  build_pdf_font.sh          tạo font CJK rút gọn cho PDF
  data/                      dữ liệu nguồn (radicals, dict-*, vocab.json)
```

## Dữ liệu

`hanzi_ref.db` (~28 MB) được sinh sẵn bằng lệnh:

```bash
python3 tool/build_db.py
```

Script tự tải `graphics.txt` và `dictionary.txt` của makemeahanzi nếu thiếu. DB gồm 214 bộ thủ, 15.591 chữ đơn, 8.384 từ ghép, 11.184 chữ có nghĩa chi tiết, 9.574 chữ có nét viết (nén zlib) và cấu tạo IDS.

**Khi dữ liệu thay đổi**, tăng `REF_DB_VERSION` trong `tool/build_db.py` **và** `RefDb.version` trong `lib/data/ref_db.dart`. Khi cập nhật, app sẽ chép DB mới. Tiến độ học nằm ở `user.db` riêng nên không bị mất.

### Thêm bộ 3000 từ đầy đủ

Thay `tool/data/vocab.json` (hiện có 16 từ mẫu) theo đúng định dạng sau:

```json
{
  "id": 1, "char": "寺", "pinyin": "sì", "hanViet": "TỰ", "meaning": "chùa, nhà thờ",
  "hsk": 6,
  "mnemonic": "Đất (土) thốn (寸) không được xây chùa (寺)",
  "giaiThich": "…",
  "image": "0001.webp",
  "components": ["土", "寸"],
  "related": [{"char": "寺庙", "traditional": "寺廟", "pinyin": "sìmiào", "hanViet": "TỰ MIẾU", "meaning": "Đền miếu"}]
}
```

- Ảnh minh họa đặt vào `assets/vocab_images/` với tên khớp field `image`.
- Số bộ thủ của từng bộ phận được tự tra khi build, gồm cả dạng biến thể như 扌, 氵, ⺮.
- Nếu bộ chữ mới có chữ hiếm, chạy thêm `tool/build_pdf_font.sh` sau khi bổ sung chữ vào `tool/pdf_font_chars.txt`.

## Khác biệt so với prototype HTML

| Prototype | Bản Flutter |
|---|---|
| `fetch()` 9 MB JSON mỗi lần mở | SQLite đóng gói, chép một lần khi mở app lần đầu |
| hanzi-writer + dữ liệu nét từ CDN | `StrokeWriter` tự viết (CustomPainter), dữ liệu nét nằm trong DB |
| Cấu tạo chữ tải từ CDN | Bảng `decomposition` trong DB |
| SRS cố định (10 phút/1/3/7 ngày) | SM-2: lần đầu giữ nguyên các khoảng trên, sau đó giãn dần theo `ease`; hàng đợi = mục đến hạn + mục mới còn lại hôm nay |
| Dữ liệu tiến độ và streak giả | Tiến độ bắt đầu từ 0; streak và biểu đồ tính từ `review_log` |
| Xuất PDF chỉ mô phỏng | PDF thật (có chữ Hán), lưu vào Tải xuống và mở share sheet |
| Nút "Nghe" chỉ đổi icon | TTS zh-CN của máy; báo lỗi nếu máy chưa có giọng đọc tiếng Trung |
| Tìm kiếm Hán Việt bằng substring | Vẫn là substring, nhưng xếp **âm khớp chính xác lên đầu** (tra "khẩu" → 口 đứng đầu); pinyin tìm được cả khi gõ không dấu |
| — | Nút Back Android đi ngược breadcrumb; ở màn chi tiết từ điển, Back quay về chữ xem trước đó |

Không dùng FTS5 như gợi ý trong README thiết kế, vì SQLite hệ thống trên Android không chắc có FTS5. Truy vấn `LIKE` trên khoảng 24 nghìn dòng vẫn đủ nhanh.

## Việc còn lại

1. **Dữ liệu 3000 từ đầy đủ**: kèm HSK, mnemonic và hình minh họa.
2. **Giấy phép makemeahanzi**: dữ liệu nét dùng Arphic Public License (xem `licenses/`). Cần đọc kỹ trước khi phát hành thương mại.
3. **Nhận diện chữ viết tay** trong Từ điển: nút hiện đang báo "sẽ sớm ra mắt".
4. **Phát âm offline tuyệt đối**: hiện dùng TTS của máy. Nếu cần chắc chắn có tiếng trên mọi máy, phải bundle file audio.
5. **Kích thước APK**: nên cân nhắc `flutter build appbundle` kết hợp Play Asset Delivery.
6. **Nhắc ôn**: thông báo được đặt lại mỗi lần mở app, nên sẽ đến khoảng 24 giờ sau lần mở gần nhất.

## Giấy phép tài nguyên

- Public Sans và Noto Sans SC: SIL OFL.
- makemeahanzi: Arphic PL / LGPL.

Chi tiết xem thư mục `licenses/`.
