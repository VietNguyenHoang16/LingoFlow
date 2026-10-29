# APK VocabPro (Android)

Thư mục phát hành APK. Tải file `.apk` bằng điện thoại rồi mở lên để cài.

## Bản phát hành

| File | Dung lượng | Kiến trúc | Dùng cho |
|---|---|---|---|
| **`vocab-arm64-release.apk`** | **20.2 MB** | arm64-v8a | Gần như mọi điện thoại Android từ ~2016 đến nay |

> Bản này cập nhật thêm: **chọn từ để luyện theo khoảng** — chạm từ đầu làm mốc,
> chạm từ cuối là chọn cả khoảng ở giữa (bấm lại một từ đã chọn để bỏ đúng từ
> đó), thay cho việc chạm từng từ; vẫn giữ **loại trừ từ khi import**,
> **Cài đặt → Cách AI sinh ví dụ** và việc **bỏ khoá trình độ A2–B1**.

Link tải nhanh:
<https://github.com/VietNguyenHoang16/LingoFlow/raw/main/apk/vocab-arm64-release.apk>

## Thông tin bản phát hành

- Kích thước: `21,165,614 bytes` (20.2 MB)
- SHA256: `06C70EAA0F6572EFE84B5602899E86EDB99F7D5F7230C6AB37F75654B4673006`
- Ngày build: `29/10/2026` — bản mới nhất:
  0. **Chọn từ để luyện theo khoảng**: ở màn Gần đây bấm ▶ rồi chạm từ đầu,
     chạm từ cuối là chọn cả khoảng ở giữa; chạm lại một từ đã chọn để bỏ đúng
     từ đó. Dòng nhắc dưới tiêu đề hướng dẫn thao tác, áp dụng cả khi đang tìm
     kiếm.
  1. **Loại trừ từ khi import hàng loạt**: ở bước xem trước, mỗi dòng hợp lệ có
     nút ⊘ để bỏ từ đó khỏi lần import. Từ bị loại vẫn hiện (mờ, gạch ngang) và
     bấm lại là hoàn tác; số trên nút Import và thống kê cập nhật theo, màn kết
     quả ghi rõ đã loại trừ bao nhiêu từ.
  2. **Cài đặt → Cách AI sinh ví dụ**: chọn nghĩa phổ biến thay vì nghĩa hiếm
     (`concrete` → “cụ thể, rõ ràng”, `harness` → “tận dụng, khai thác”), chọn
     bối cảnh câu ví dụ (đời sống, công việc, IT, du lịch…), thêm yêu cầu riêng
     và xem trước đúng chỉ dẫn gửi AI. Lưu theo tài khoản, dùng ngay cho lần tạo
     nghĩa/ví dụ kế tiếp. Câu ví dụ không còn bị giới hạn trình độ A2–B1.
  3. **Mất mạng không còn làm mất tiến độ ôn tập**: mỗi lượt chấm điểm chỉ
     chuyển sang từ tiếp theo sau khi server đã ghi xong SRS. Nếu lưu thất bại,
     app chặn lại bằng hộp thoại **"Mất kết nối mạng"** với hai lựa chọn
     **Thử lại** / **Thoát** — lượt ôn đó không bị đánh rơi âm thầm.
  4. **Mở màn Ôn tập / Luyện tập khi offline** hiện đúng trạng thái
     **"Cần kết nối mạng"** + nút **Thử lại**, không còn hiện nhầm
     "All caught up!" / "No words to study".
  5. **Sửa từ ở mọi màn** (Ôn tập, Luyện tập, Gần đây, danh mục, bộ từ, tìm
     kiếm) có lớp phủ mờ khoá thao tác **"Đang lưu…"**, xong đổi thành dấu tick
     **"Đã lưu" + tên từ** rồi tan dần (blur nhẹ, spring, rung haptic). Không
     còn bấm nhầm trong lúc chờ.
  6. **Hết giật sau khi sửa từ**: màn danh mục / bộ từ cập nhật tại chỗ thay vì
     tải lại cả danh sách (nguyên nhân màn hình nhảy một cái).
  7. Giữ nguyên các cải tiến trước: import dán từ ngăn cách dấu phẩy + AI lấy
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
