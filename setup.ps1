# Chạy 1 lần sau khi giải nén (Windows PowerShell):  .\setup.ps1
# Sinh các file Android mà Flutter tự tạo (gradle wrapper, icon, theme...) — KHÔNG ghi đè file đã có.
$ErrorActionPreference = "Stop"
# Dọn file Gradle kiểu Groovy cũ (nếu có)
foreach ($f in @("android/build.gradle", "android/settings.gradle", "android/app/build.gradle")) { if (Test-Path $f) { Remove-Item -Force $f } }
flutter create --platforms=android --org vn.hoctiengtrung --project-name hoc_tieng_trung .
# flutter create sinh thêm MainActivity mặc định ở package khác — bỏ đi, app dùng vn.hoctiengtrung.app
$extra = "android/app/src/main/kotlin/vn/hoctiengtrung/hoc_tieng_trung"
if (Test-Path $extra) { Remove-Item -Recurse -Force $extra }
if (Test-Path "test/widget_test.dart") { Remove-Item "test/widget_test.dart" }
flutter pub get
Write-Host "Xong. Chạy: flutter run   hoặc   flutter build apk --release"
