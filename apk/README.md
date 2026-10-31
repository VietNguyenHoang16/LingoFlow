# APK VocabPro (Android)

Thư mục phát hành APK. Tải file `.apk` bằng điện thoại rồi mở lên để cài.

## Bản phát hành

| File | Dung lượng | Kiến trúc | Dùng cho |
|---|---|---|---|
| **`vocab-arm64-release.apk`** | **20.2 MB** | arm64-v8a | Gần như mọi điện thoại Android từ ~2016 đến nay |

> Bản này đổi màn **Phân loại từ vựng** sang duyệt lô 20 từ: nút lớn 2 bên Học
> ngay / Nên biết, copy nhanh 20 từ, **xoá từ không ưu tiên ngay trong lô**, nộp
> xong từ không hiện lại. Toàn bộ từ cũ đã reset về "chưa phân loại" để duyệt lại
> (lịch ôn giữ nguyên). Vẫn giữ 2 tab, ôn Nên biết 4 đáp án, import 3 nhãn và các
> cải tiến trước.

Link tải nhanh:
<https://github.com/VietNguyenHoang16/LingoFlow/raw/main/apk/vocab-arm64-release.apk>

## Thông tin bản phát hành

- Kích thước: `21,231,910 bytes` (20.2 MB)
- SHA256: `AC5AC4DB3EA1531DD1DDECFE0F2EF8E30188BE9ED4BA60E5543D6E8A7E936F5B`
- Ngày build: `31/10/2026` — bản mới nhất:
  0. **Phân loại từ vựng theo lô 20 từ**: mỗi từ có **nút lớn 2 bên Học ngay /
     Nên biết** (bấm bên nào sáng bên đó, bấm lại để bỏ chọn), **Copy N từ** (chỉ
     từ tiếng Anh, cách nhau dấu phẩy) để dán sang AI/chỗ khác, **AI gợi ý**,
     "Tất cả Học ngay/Nên biết". **Nộp N từ** lưu lô hiện tại; từ đã nộp không
     hiện lại. Mỗi dòng có nút **xoá (không ưu tiên)** — xoá xong số từ còn lại
     giảm ngay, snackbar sau khi nộp báo còn bao nhiêu từ chưa phân loại. Toàn bộ
     từ cũ đã được đưa về trạng thái "chưa phân loại" để duyệt lại từ đầu (không
     mất lịch ôn).
  1. **2 loại từ chạy đầy đủ**: trang chính có 2 tab **Học ngay / Nên biết** (đếm
     due riêng), thẻ có chip loại và long-press để chuyển loại. **Nên biết** ôn
     bằng **4 đáp án** (không gõ), lịch giãn 1→3→7→21→45 ngày, sai hẹn 1 ngày,
     vào từ nút **"Gặp lại nhẹ (M)"**. Cài đặt → **Phân loại lại từ vựng**: AI xếp
     lại toàn bộ từ cũ, bạn xem/sửa rồi áp dụng.
  2. **Hai loại từ — Học ngay / Nên biết (Phase 1)**: AI phân loại mỗi từ khi
     phân tích/import thành **Học ngay** (cần dùng được: email, họp, code),
     **Nên biết** (chỉ cần hiểu khi đọc/nghe) hoặc **Bỏ qua** (không ưu tiên).
     Bảng import hiện chip 3 trạng thái bấm để đổi, cụm từ đi kèm cho từ Học
     ngay (vd "comply with"), thống kê tách riêng; từ "Bỏ qua" không tick sẵn
     và không được lưu. (Phase sau: tab 2 loại ở trang chính, phiên ôn Nên
     biết bằng 4 đáp án, màn duyệt phân loại lại từ cũ.)
  3. **Luyện tập: kết quả gọn trong 1 khung** — trả lời xong thì phần gõ từ được
     ẩn đi, toàn bộ kết quả (đúng/sai, đáp án, phiên âm, "Bạn gõ", ví dụ, lịch
     ôn) nằm gọn trong một màn hình, **không phải kéo xuống**; nút Tiếp luôn ở
     đáy. Ví dụ trong khung kết quả giới hạn 3–4 dòng cho gọn.
  4. **Luyện tập: bỏ Multiple Choice, dọn giao diện**: màn luyện tập chỉ còn
     **gõ từ** (không còn chọn đáp án 4 lựa chọn / phím tắt 1–4). Bố cục gọn
     lại: thẻ chỉ còn mức ghi nhớ + nghĩa; đáp án/phát âm/ví dụ/SRS hiện một lần;
     màn kết thúc rút gọn còn **"Đúng X/Y"** + **Làm lại** / **Thoát**. Nhãn
     chuyển hết sang tiếng Việt (kể cả mức ghi nhớ: Mới / Đang học / Đang ôn /
     Đã thuộc).
  5. **Tìm kiếm không thay danh sách**: gõ vào ô tìm kiếm thì kết quả nằm trong
     panel riêng ngay dưới ô (cao tối đa ~38% màn hình, tự cuộn), còn danh sách
     từ bên dưới **giữ nguyên từ và vị trí cuộn** — nhìn được cả 2 phần để kiểm
     tra từ đã tồn tại chưa. Mỗi dòng kết quả có từ, loại từ, chip **"Đã có"**,
     phát âm, nghĩa và nút loa; chạm để nghe, nhấn giữ để mở menu sửa/xoá.
     Không có kết quả → hiện **"Chưa có từ này trong bộ từ của bạn"** + nút
     **Thêm từ** (mở import với từ điền sẵn, AI lấy nghĩa/loại từ ngay, thêm
     xong tự đóng).
  6. **Import — loại trừ & trùng từ**:
     - Từ bạn bấm ⊘ loại trừ **không còn xuất hiện (và không bị tick)** ở danh sách
       đang lưu trong lúc import; danh sách chỉ còn đúng số từ sẽ được thêm.
     - Từ **trùng với bộ từ đã lưu** hiện luôn **nghĩa + loại từ** đã lưu ngay trong
       bảng import (dòng tô teal thay vì đỏ như lỗi); từ trùng ngay trong danh sách
       dán vào cũng hiện nghĩa của dòng đầu tiên.
  7. **Bỏ số thứ tự khi import**: dán danh sách đánh số (`29. asset`,
     `3) give up`, `29 - take off`) thì số thứ tự bị bỏ, từ lưu vào chỉ còn
     `asset`; số không phải thứ tự (`8-bit`, `3.14`, `24/7`) giữ nguyên. Áp
     dụng cả ở màn Import hàng loạt lẫn dialog Thêm từ (nhập nhiều dòng).
  8. **Chọn từ để luyện theo khoảng**: ở màn Gần đây bấm ▶ rồi chạm từ đầu,
     chạm từ cuối là chọn cả khoảng ở giữa; chạm lại một từ đã chọn để bỏ đúng
     từ đó. Dòng nhắc dưới tiêu đề hướng dẫn thao tác, áp dụng cả khi đang tìm
     kiếm.
  9. **Loại trừ từ khi import hàng loạt**: ở bước xem trước, mỗi dòng hợp lệ có
     nút ⊘ để bỏ từ đó khỏi lần import. Từ bị loại vẫn hiện (mờ, gạch ngang) và
     bấm lại là hoàn tác; số trên nút Import và thống kê cập nhật theo, màn kết
     quả ghi rõ đã loại trừ bao nhiêu từ.
  10. **Cài đặt → Cách AI sinh ví dụ**: chọn nghĩa phổ biến thay vì nghĩa hiếm
     (`concrete` → “cụ thể, rõ ràng”, `harness` → “tận dụng, khai thác”), chọn
     bối cảnh câu ví dụ (đời sống, công việc, IT, du lịch…), thêm yêu cầu riêng
     và xem trước đúng chỉ dẫn gửi AI. Lưu theo tài khoản, dùng ngay cho lần tạo
     nghĩa/ví dụ kế tiếp. Câu ví dụ không còn bị giới hạn trình độ A2–B1.
  11. **Mất mạng không còn làm mất tiến độ ôn tập**: mỗi lượt chấm điểm chỉ
     chuyển sang từ tiếp theo sau khi server đã ghi xong SRS. Nếu lưu thất bại,
     app chặn lại bằng hộp thoại **"Mất kết nối mạng"** với hai lựa chọn
     **Thử lại** / **Thoát** — lượt ôn đó không bị đánh rơi âm thầm.
  12. **Mở màn Ôn tập / Luyện tập khi offline** hiện đúng trạng thái
     **"Cần kết nối mạng"** + nút **Thử lại**, không còn hiện nhầm
     "All caught up!" / "No words to study".
  13. **Sửa từ ở mọi màn** (Ôn tập, Luyện tập, Gần đây, danh mục, bộ từ, tìm
     kiếm) có lớp phủ mờ khoá thao tác **"Đang lưu…"**, xong đổi thành dấu tick
     **"Đã lưu" + tên từ** rồi tan dần (blur nhẹ, spring, rung haptic). Không
     còn bấm nhầm trong lúc chờ.
  14. **Hết giật sau khi sửa từ**: màn danh mục / bộ từ cập nhật tại chỗ thay vì
     tải lại cả danh sách (nguyên nhân màn hình nhảy một cái).
  15. Giữ nguyên các cải tiến trước: import dán từ ngăn cách dấu phẩy + AI lấy
     nghĩa/phân loại, sửa từ trong Ôn tập, tìm kiếm toàn bộ từ, thẻ học hiển thị
     trọn vẹn ví dụ dài, và TTS trên iPad Safari tự phục hồi sau khi chuyển app.
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
