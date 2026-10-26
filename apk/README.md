# APK VocabPro (Android)

Thư mục phát hành APK. Tải file `.apk` bằng điện thoại rồi mở lên để cài.

## Bản phát hành

| File | Dung lượng | Kiến trúc | Dùng cho |
|---|---|---|---|
| **`vocab-arm64-release.apk`** | **20.0 MB** | arm64-v8a | Gần như mọi điện thoại Android từ ~2016 đến nay |

> Bản này cập nhật thêm: import dán từ + AI lấy nghĩa/phân loại, AI sửa nghĩa & phân loại
> lại khi đổi từ ở màn Ôn tập, và ô tìm kiếm quét toàn bộ từ đã lưu (chi tiết ở dưới).

Link tải nhanh:
<https://github.com/VietNguyenHoang16/LingoFlow/raw/main/apk/vocab-arm64-release.apk>

## Thông tin bản phát hành

- Kích thước: `20,968,594 bytes` (20.0 MB)
- SHA256: `68E4B334ACE05FE1EFBC9081A60AF343F3BB8F9753B465B0C717CD5BBDFD38A2`
- Ngày build: `27/10/2026` — bản mới nhất với AI:
  1. **Import từ hàng loạt chỉ cần dán từ ngăn cách dấu phẩy** (bỏ định dạng
     `số_POS :: từ :: nghĩa`). Bấm "Phân tích bằng AI" để AI lấy **nghĩa tiếng Việt** +
     **phân loại loại từ** cho từng từ, xem trước rồi mới Import; ví dụ câu vẫn tự sinh
     khi lưu. Từ nào AI không lấy được nghĩa sẽ bị bỏ qua và báo rõ số lượng.
  2. **Sửa từ trong màn Ôn tập (Review)**: khi đổi Từ, AI tự lấy **nghĩa mới** +
     **phân loại lại loại từ** (nghĩa cũ bị thay), từ điển vẫn lấy phát âm/chi tiết;
     ô Nghĩa được để trống (để trống = AI điền). AI lỗi thì không lưu, có báo.
  3. **Ô tìm kiếm ở trang chính quét toàn bộ từ đã lưu** (khớp từ / nghĩa / nhãn chủ đề),
     không chỉ lọc trong 20 từ gần nhất; sửa từ ngay trong kết quả tìm cũng áp dụng
     AI lấy nghĩa + phân loại như trên. Tối đa 200 kết quả/lần.
  4. API mới: action `enrichWords` (nghĩa + loại từ từ AI, tái dùng chuỗi provider AI
     đã cấu hình trong Hồ sơ / `GEMINI_API_KEY`), mức chữ ký giữ nguyên 1.0.0.
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
