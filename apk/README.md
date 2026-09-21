# APK LingoFlow (Android)

Thư mục phát hành APK. Tải file `.apk` bằng điện thoại rồi mở lên để cài.

## Chọn bản nào?

| File | Dung lượng | Kiến trúc | Dùng cho |
|---|---|---|---|
| **`vocab-arm64-release.apk`** | **20.2 MB** | arm64-v8a | **Khuyến nghị** — gần như mọi điện thoại Android từ ~2016 đến nay |
| `vocab-release.apk` | 53.8 MB | arm64-v8a + armeabi-v7a + x86 + x86_64 | Máy 32-bit đời cũ, máy giả lập (Nox / BlueStacks / LDPlayer) |

Link tải nhanh bản khuyến nghị:
<https://github.com/VietNguyenHoang16/LingoFlow/raw/main/apk/vocab-arm64-release.apk>

## Bản khuyến nghị (số liệu kiểm chứng)

- Kích thước: `21,173,352 bytes` (20.2 MB)
- SHA256: `3D5B946E5D6F62D412CF42419F34FA80A1DA5B3C0333C74B10EE345DAA5CAAF2`
- Yêu cầu: Android 7.0 (API 24) trở lên, CPU arm64-v8a
- Version: `1.0.0` (versionCode 1)

## Cách cài

1. Mở link tải APK bằng điện thoại (nên dùng Chrome).
2. Khi máy hỏi, bật **"Cho phép cài đặt ứng dụng từ nguồn không xác định"** cho trình duyệt
   (hoặc vào `Cài đặt` > `Bảo mật` > `Cài đặt ứng dụng không rõ nguồn gốc`).
3. Mở file vừa tải > **Cài đặt**.
4. Nếu Google Play Protect cảnh báo: chọn **"Vẫn cài đặt"** — APK ký bằng debug key và không phát hành qua Play Store.

## Ghi chú build

Lệnh tạo bản arm64 (nhẹ nhất):

```bash
flutter build apk --release --target-platform android-arm64 \
  --obfuscate --split-debug-info=build/symbols
```

- Đã bật sẵn `isMinifyEnabled` + `isShrinkResources` trong `android/app/build.gradle.kts`
  và tree-shake icon của Flutter.
- Bản arm64 chỉ chứa 1 ABI (`libflutter.so` ~11.1 MB + `libapp.so` ~5.4 MB) nên nhỏ hơn
  nhiều so với APK universal gộp 4 ABI.
- File giải mã crash log khi cần debug: `build/symbols/app.android-arm64.symbols`
  (không đưa vào repo; cần giữ lại sau mỗi lần build obfuscate).
