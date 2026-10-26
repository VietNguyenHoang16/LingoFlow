# APK VocabPro (Android)

Thư mục phát hành APK. Tải file `.apk` bằng điện thoại rồi mở lên để cài.

## Bản phát hành

| File | Dung lượng | Kiến trúc | Dùng cho |
|---|---|---|---|
| **`vocab-arm64-release.apk`** | **20.0 MB** | arm64-v8a | Gần như mọi điện thoại Android từ ~2016 đến nay |

Link tải nhanh:
<https://github.com/VietNguyenHoang16/LingoFlow/raw/main/apk/vocab-arm64-release.apk>

## Thông tin bản phát hành

- Kích thước: `20,968,454 bytes` (20.0 MB)
- SHA256: `0AA615BA70C11EAD99D521D783C24C43827E06F8D2CBAF1D55268F41AA006AAE`
- Ngày build: `27/10/2026` — đổi tên app thành **VocabPro**, thêm **intro động 2.2s**
  (artwork VocabPro bay nhẹ + sparkles, chạm để bỏ qua) và **thiết kế lại màn đăng nhập**:
  nền gradient chuyển động, logo + tên app trượt vào theo từng chữ cái, segmented toggle
  Đăng nhập/Đăng ký trượt, ô số điện thoại có vòng sáng khi focus + dấu check khi đủ 9 số,
  nút gradient có vệt sáng chạy, sai số thì rung (shake) + báo lỗi ngay dưới ô nhập.
  Vẫn giữ bảng màu emerald + kem ấm. Splash native đổi sang xanh brand `#1E7FE6` với badge tròn.
- Yêu cầu: Android 7.0 (API 24) trở lên, CPU arm64-v8a
- Version: `1.0.0` (versionCode 1)
- Chữ ký: debug keystore (cùng khoá với các bản trước) nên cài đè trực tiếp, không cần gỡ app cũ

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
- Bản arm64 chỉ chứa 1 ABI (`libflutter.so` ~11.1 MB + `libapp.so` ~5.4 MB) nên nhẹ hơn
  APK universal gộp 4 ABI.
- File giải mã crash log khi cần debug: `build/symbols/app.android-arm64.symbols`
  (không đưa vào repo; cần giữ lại sau mỗi lần build obfuscate).
