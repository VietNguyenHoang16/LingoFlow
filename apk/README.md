# APK VocabPro (Android)

Thư mục phát hành APK. Tải file `.apk` bằng điện thoại rồi mở lên để cài.

## Bản phát hành

| File | Dung lượng | Kiến trúc | Dùng cho |
|---|---|---|---|
| **`vocab-arm64-release.apk`** | **20.0 MB** | arm64-v8a | Gần như mọi điện thoại Android từ ~2016 đến nay |

> Bản này cập nhật thêm: thẻ học hiển thị **trọn vẹn ví dụ dài** (không còn cắt "…"),
> cùng các cải tiến AI ở bản trước (import dán từ, sửa từ ở màn Ôn tập, tìm kiếm toàn bộ).

Link tải nhanh:
<https://github.com/VietNguyenHoang16/LingoFlow/raw/main/apk/vocab-arm64-release.apk>

## Thông tin bản phát hành

- Kích thước: `20,968,594 bytes` (20.0 MB)
- SHA256: `2E3C13641422BD3B6D16F1C4B24D7B640049A770DB9E7557612E408006D78179`
- Ngày build: `27/10/2026` — bản mới nhất:
  1. **Thẻ học hiển thị trọn vẹn ví dụ dài**: bỏ giới hạn 3 dòng + "…" ở mặt sau thẻ
     (tab chính), ở panel ví dụ màn Ôn tập và ở thẻ ví dụ của màn Luyện tập / bộ từ;
     bản dịch cũng hiển thị đủ thay vì cắt 2 dòng. Cỡ chữ giữ nguyên (câu ví dụ 15px,
     bản dịch 13px) nên vẫn dễ đọc, chỉ tăng giãn dòng; thẻ tự cao lên và danh sách
     cuộn để đọc tiếp. Khối ví dụ có thêm nhãn "Ví dụ" + nền tint nhẹ để câu dài vẫn
     tách khỏi phần nghĩa; khi lật thẻ, chiều cao chạy mượt thay vì nhảy.
  2. **Import từ hàng loạt chỉ cần dán từ ngăn cách dấu phẩy** (bỏ định dạng
     `số_POS :: từ :: nghĩa`). Bấm "Phân tích bằng AI" để AI lấy **nghĩa tiếng Việt** +
     **phân loại loại từ** cho từng từ, xem trước rồi mới Import; ví dụ câu vẫn tự sinh
     khi lưu. Từ nào AI không lấy được nghĩa sẽ bị bỏ qua và báo rõ số lượng.
  3. **Sửa từ trong màn Ôn tập (Review)**: khi đổi Từ, AI tự lấy **nghĩa mới** +
     **phân loại lại loại từ** (nghĩa cũ bị thay), từ điển vẫn lấy phát âm/chi tiết;
     ô Nghĩa được để trống (để trống = AI điền). AI lỗi thì không lưu, có báo.
  4. **Ô tìm kiếm ở trang chính quét toàn bộ từ đã lưu** (khớp từ / nghĩa / nhãn chủ đề),
     không chỉ lọc trong 20 từ gần nhất; sửa từ ngay trong kết quả tìm cũng áp dụng
     AI lấy nghĩa + phân loại như trên. Tối đa 200 kết quả/lần.
  5. API: action `enrichWords` (nghĩa + loại từ từ AI, tái dùng chuỗi provider AI
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
