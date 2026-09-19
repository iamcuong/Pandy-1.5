#!/usr/bin/env sh
# Chạy 1 lần sau khi giải nén (macOS/Linux):  sh setup.sh
# Sinh các file Android còn thiếu (icon, theme, gradle wrapper). `flutter create` KHÔNG ghi đè file đã có,
# nên các file Gradle đã cố định phiên bản trong android/ được giữ nguyên.
set -e
# Dọn file Gradle kiểu Groovy cũ (nếu có) — trùng với bản .kts sẽ làm Gradle báo lỗi.
rm -f android/build.gradle android/settings.gradle android/app/build.gradle
flutter create --platforms=android --org vn.hoctiengtrung --project-name hoc_tieng_trung .
# flutter create sinh thêm MainActivity mặc định ở package khác — bỏ đi, app dùng vn.hoctiengtrung.app
rm -rf android/app/src/main/kotlin/vn/hoctiengtrung/hoc_tieng_trung
rm -f test/widget_test.dart
flutter pub get
echo "Xong. Chạy: flutter run   hoặc   flutter build apk --release"
