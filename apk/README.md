# APK VocabPro (Android)

Thư mục phát hành APK. Tải file `.apk` bằng điện thoại rồi mở lên để cài.

## Bản phát hành

| File | Dung lượng | Kiến trúc | Dùng cho |
|---|---|---|---|
| **`vocab-arm64-release.apk`** | **20.0 MB** | arm64-v8a | Gần như mọi điện thoại Android từ ~2016 đến nay |

> Bản này cập nhật thêm: **chặn ôn tập khi mất mạng** (không còn làm xong rồi
> mất tiến độ) và **lớp phủ "Đang lưu… → Đã lưu"** khi sửa từ, bỏ hiện tượng
> màn hình giật sau khi lưu.

Link tải nhanh:
<https://github.com/VietNguyenHoang16/LingoFlow/raw/main/apk/vocab-arm64-release.apk>

## Thông tin bản phát hành

- Kích thước: `20,968,734 bytes` (20.0 MB)
- SHA256: `4D8D0BACEF958D6EB891F6F852FE42AF0C7A18DE31DA0ADC7B237154223A7CE1`
- Ngày build: `28/10/2026` — bản mới nhất:
  1. **Mất mạng không còn làm mất tiến độ ôn tập**: mỗi lượt chấm điểm chỉ
     chuyển sang từ tiếp theo sau khi server đã ghi xong SRS. Nếu lưu thất bại,
     app chặn lại bằng hộp thoại **"Mất kết nối mạng"** với hai lựa chọn
     **Thử lại** / **Thoát** — lượt ôn đó không bị đánh rơi âm thầm.
  2. **Mở màn Ôn tập / Luyện tập khi offline** hiện đúng trạng thái
     **"Cần kết nối mạng"** + nút **Thử lại**, không còn hiện nhầm
     "All caught up!" / "No words to study".
  3. **Sửa từ ở mọi màn** (Ôn tập, Luyện tập, Gần đây, danh mục, bộ từ, tìm
     kiếm) có lớp phủ mờ khoá thao tác **"Đang lưu…"**, xong đổi thành dấu tick
     **"Đã lưu" + tên từ** rồi tan dần (blur nhẹ, spring, rung haptic). Không
     còn bấm nhầm trong lúc chờ.
  4. **Hết giật sau khi sửa từ**: màn danh mục / bộ từ cập nhật tại chỗ thay vì
     tải lại cả danh sách (nguyên nhân màn hình nhảy một cái).
  5. Giữ nguyên các cải tiến trước: import dán từ ngăn cách dấu phẩy + AI lấy
     nghĩa/phân loại, sửa từ trong Ôn tập, tìm kiếm toàn bộ từ, thẻ học hiển thị
     trọn vẹn ví dụ dài.
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
