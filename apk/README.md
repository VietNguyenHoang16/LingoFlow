# APK VocabPro (Android)

Thư mục phát hành APK. Tải file `.apk` bằng điện thoại rồi mở lên để cài.

## Bản phát hành

| File | Dung lượng | Kiến trúc | Dùng cho |
|---|---|---|---|
| **`vocab-arm64-release.apk`** | **20.3 MB** | arm64-v8a (+ armeabi-v7a, x86_64) | Gần như mọi điện thoại Android từ ~2016 đến nay |

> Bản này **gộp các từ đồng nghĩa khi import thành 1 card** (viết `verbose/wordy`, hoặc để AI tự gộp khi hai từ cùng nghĩa) và **sửa từ luôn lưu được** kể cả khi AI trả câu ví dụ lỗi — không còn cảnh sửa xong mà thẻ không đổi. Vẫn giữ mục **Cỡ chữ** trong Settings (Chuẩn / Lớn / Rất lớn / Tối đa): trên iPad và màn hình rộng chữ mặc định to hơn hẳn nên đọc dễ hơn nhiều, chọn cỡ nào cũng được lưu lại. Vẫn giữ **widget "Từ cần ôn"** trên màn hình chính Android: hiện số từ đến hạn ngay ngoài app, chạm vào là mở app. Đồng thời vẫn giữ việc **gỡ mô hình 2 loại từ**: mọi từ đều là từ muốn học, không còn tab Học ngay / Nên biết, chip loại, ôn Nên biết hay màn phân loại; toàn bộ từ về 1 danh sách như cũ, không mất lịch ôn. Muốn ôn kĩ từ nào thì dùng ▶ chọn từ để luyện. Vẫn giữ **cụm từ đi kèm** (hiện ở mặt sau thẻ) và các cải tiến trước.

Link tải nhanh:
<https://github.com/VietNguyenHoang16/LingoFlow/raw/main/apk/vocab-arm64-release.apk>

## Thông tin bản phát hành

- Kích thước: `21,233,910 bytes` (20.3 MB)
- SHA256: `5A7388925D73063BC9ACCBC40633114F7DEA138DCAFB280DF3118B4B1705632C`
- Ngày build: `03/11/2026` — bản mới nhất:
  - **Gộp từ đồng nghĩa khi import** — viết `verbose/wordy` (hoặc `verbose = wordy`)
    trên cùng một dòng là ra **1 card**: `verbose` là từ chính, `wordy` vào
    **Common synonyms**. Không viết gì đặc biệt thì AI vẫn tự gộp: hai từ cùng
    nghĩa (AI báo là đồng nghĩa, hoặc nghĩa tiếng Việt giống nhau) thành 1 card.
    Ở bước xem trước, dòng bị gộp tô màu riêng và ghi **Gộp vào "verbose"**,
    thống kê có ô **Gộp nghĩa**; mỗi nhóm tối đa 4 từ (1 từ chính + 3 synonyms).
  - **Sửa từ không còn thất bại vì câu ví dụ** — trước đây AI trả câu ví dụ thiếu
    từ khoá là cả lần sửa bị huỷ, thẻ giữ nguyên từ cũ. Giờ từ vẫn được lưu; câu
    ví dụ lỗi thì dùng câu mẫu an toàn, và vẫn bấm tạo lại ví dụ được như thường.
  0. **Cỡ chữ trong Settings** — mở bánh răng → mục **Cỡ chữ**, chọn
     **Chuẩn / Lớn / Rất lớn / Tối đa** (có ô xem trước chữ Aa). Áp dụng ngay
     cho toàn app, lưu lại cho lần mở sau. Trên iPad / web màn hình rộng chữ
     mặc định là **Rất lớn** và cột app nới rộng theo, nên không còn cảnh chữ
     nhỏ xíu giữa màn hình; điện thoại giữ nguyên cỡ cũ.
  1. **Widget "Từ cần ôn" ngoài màn hình chính** (chỉ Android): thêm widget hiện
     **số từ đến hạn** ngay trên màn hình chính, không cần mở app. Số to ở giữa,
     dòng chữ "từ cần ôn"; 0 từ thì ghi "Hôm nay xong hết 🎉"; chưa cập nhật lần
     nào thì hiện `--` + "Mở app để cập nhật"; chạm widget là mở app. Số tự cập
     nhật mỗi lần bạn mở app (widget cố ý không chạy nền/không đánh thức máy để
     đỡ tốn pin). Cách thêm: nhấn giữ màn hình chính → **Widget** → **VocabPro**
     → kéo **Từ cần ôn** ra chỗ trống.
  1. **Từ yêu thích** — chạm tim ở danh sách trang chủ, kết quả tìm kiếm, thẻ ôn tập, chủ đề, bộ từ, flashcard và luyện tập. Nút tim ở header trang chủ mở trang **Từ yêu thích** (có số lượng) và luyện đúng các từ đó. Cột "từ khó" cũ được bỏ, dữ liệu đánh dấu khó được reset.
  1. **Flashcard: phím tắt 1 / 2 / 3 / Enter** — bản web và máy có bàn phím cứng:
     bấm **1** = Chưa biết, **2** = Đã biết, **3** = Nghe từ, **Enter** = Tiếp.
     Nút loa có chip **3**; dòng gợi ý phím nằm ngay dưới 2 nút.
  1. **Flashcard: nút loa to, đặt dưới thẻ** — loa không còn nằm cạnh từ; giờ là
     nút tròn lớn căn giữa, nằm giữa khung thẻ và 2 nút **Chưa biết / Đã biết**,
     bấm là đọc từ ngay. Hai nút to rõ hơn, bố cục kín, không còn khoảng trống.
  2. **Luyện tập: chế độ Flashcard biết/chưa biết** — bấm **Luyện tập** rồi chọn
     **Flashcard**; thẻ hiện từ tiếng Anh + phiên âm + loa. Bấm **Đã biết** để bỏ
     thẻ, **Chưa biết** để xem nghĩa/ví dụ/cụm từ (có loa đọc) rồi **Tiếp** — thẻ
     chưa biết quay lại hàng đợi đến khi tất cả đều biết. Chế độ này không ghi
     SRS, không ảnh hưởng lịch ôn tập hằng ngày.
  3. **Luyện tập: khung đáp án phủ kín màn hình** — khi hiện đáp án, bàn phím tự
     đóng nên khung đáp án dùng trọn chiều cao màn hình từ trên xuống dưới
     (không còn bị bóp nhỏ), chữ to hơn (đáp án 44 → 48, nghĩa 18 → 20), nội
     dung canh giữa nên nhìn cân đối. Kết quả vẫn hiện **ngay lập tức** (không
     chờ mạng); PC / iPad có bàn phím cứng thì Enter vẫn sang câu tiếp, còn lại
     bấm nút **Tiếp**.
     **Xoá từ ngay trong kết quả tìm kiếm**: từ vừa xoá biến mất tức thì ở cả
     panel kết quả lẫn danh sách từ bên dưới (trước đây danh sách bên dưới vẫn
     giữ từ đã xoá cho tới khi tải lại trang).
  4. **Gỡ mô hình 2 loại** (theo yêu cầu): mọi từ đã thêm đều là từ muốn học,
     nên đã bỏ tab Học ngay / Nên biết, chip loại, phiên ôn Nên biết 4 đáp án và
     màn Phân loại lô 20 từ. Toàn bộ từ về 1 danh sách như trước (không xoá từ,
     không mất lịch ôn). Muốn ôn kĩ từ nào thì bấm ▶ ở màn chính rồi chạm chọn từ
     → Luyện tập. **Cụm từ đi kèm** vẫn được AI gợi ý 2–3 cụm/từ và hiện ở mặt
     sau thẻ ("Cụm từ: …").
  5. **Luyện tập: kết quả gọn trong 1 khung** — trả lời xong thì phần gõ từ được
     ẩn đi, toàn bộ kết quả (đúng/sai, đáp án, phiên âm, "Bạn gõ", ví dụ, lịch
     ôn) nằm gọn trong một màn hình, **không phải kéo xuống**; nút Tiếp luôn ở
     đáy. Ví dụ trong khung kết quả giới hạn 5–6 dòng cho gọn.
  6. **Luyện tập: bỏ Multiple Choice, dọn giao diện**: màn luyện tập chỉ còn
     **gõ từ** (không còn chọn đáp án 4 lựa chọn / phím tắt 1–4). Bố cục gọn
     lại: thẻ chỉ còn mức ghi nhớ + nghĩa; đáp án/phát âm/ví dụ/SRS hiện một lần;
     màn kết thúc rút gọn còn **"Đúng X/Y"** + **Làm lại** / **Thoát**. Nhãn
     chuyển hết sang tiếng Việt (kể cả mức ghi nhớ: Mới / Đang học / Đang ôn /
     Đã thuộc).
  7. **Tìm kiếm không thay danh sách**: gõ vào ô tìm kiếm thì kết quả nằm trong
     panel riêng ngay dưới ô (cao tối đa ~38% màn hình, tự cuộn), còn danh sách
     từ bên dưới **giữ nguyên từ và vị trí cuộn** — nhìn được cả 2 phần để kiểm
     tra từ đã tồn tại chưa. Mỗi dòng kết quả có từ, loại từ, chip **"Đã có"**,
     phát âm, nghĩa và nút loa; chạm để nghe, nhấn giữ để mở menu sửa/xoá.
     Không có kết quả → hiện **"Chưa có từ này trong bộ từ của bạn"** + nút
     **Thêm từ** (mở import với từ điền sẵn, AI lấy nghĩa/loại từ ngay, thêm
     xong tự đóng).
  8. **Import — loại trừ & trùng từ**:
     - Từ bạn bấm ⊘ loại trừ **không còn xuất hiện (và không bị tick)** ở danh sách
       đang lưu trong lúc import; danh sách chỉ còn đúng số từ sẽ được thêm.
     - Từ **trùng với bộ từ đã lưu** hiện luôn **nghĩa + loại từ** đã lưu ngay trong
       bảng import (dòng tô teal thay vì đỏ như lỗi); từ trùng ngay trong danh sách
       dán vào cũng hiện nghĩa của dòng đầu tiên.
  9. **Bỏ số thứ tự khi import**: dán danh sách đánh số (`29. asset`,
     `3) give up`, `29 - take off`) thì số thứ tự bị bỏ, từ lưu vào chỉ còn
     `asset`; số không phải thứ tự (`8-bit`, `3.14`, `24/7`) giữ nguyên. Áp
     dụng cả ở màn Import hàng loạt lẫn dialog Thêm từ (nhập nhiều dòng).
  10. **Chọn từ để luyện theo khoảng**: ở màn Gần đây bấm ▶ rồi chạm từ đầu,
     chạm từ cuối là chọn cả khoảng ở giữa; chạm lại một từ đã chọn để bỏ đúng
     từ đó. Dòng nhắc dưới tiêu đề hướng dẫn thao tác, áp dụng cả khi đang tìm
     kiếm.
  11. **Loại trừ từ khi import hàng loạt**: ở bước xem trước, mỗi dòng hợp lệ có
     nút ⊘ để bỏ từ đó khỏi lần import. Từ bị loại vẫn hiện (mờ, gạch ngang) và
     bấm lại là hoàn tác; số trên nút Import và thống kê cập nhật theo, màn kết
     quả ghi rõ đã loại trừ bao nhiêu từ.
  12. **Cài đặt → Cách AI sinh ví dụ**: chọn nghĩa phổ biến thay vì nghĩa hiếm
     (`concrete` → “cụ thể, rõ ràng”, `harness` → “tận dụng, khai thác”), chọn
     bối cảnh câu ví dụ (đời sống, công việc, IT, du lịch…), thêm yêu cầu riêng
     và xem trước đúng chỉ dẫn gửi AI. Lưu theo tài khoản, dùng ngay cho lần tạo
     nghĩa/ví dụ kế tiếp. Câu ví dụ không còn bị giới hạn trình độ A2–B1.
  13. **Mất mạng không còn làm mất tiến độ ôn tập**: mỗi lượt chấm điểm chỉ
     chuyển sang từ tiếp theo sau khi server đã ghi xong SRS. Nếu lưu thất bại,
     app chặn lại bằng hộp thoại **"Mất kết nối mạng"** với hai lựa chọn
     **Thử lại** / **Thoát** — lượt ôn đó không bị đánh rơi âm thầm.
  14. **Mở màn Ôn tập / Luyện tập khi offline** hiện đúng trạng thái
     **"Cần kết nối mạng"** + nút **Thử lại**, không còn hiện nhầm
     "All caught up!" / "No words to study".
  15. **Sửa từ ở mọi màn** (Ôn tập, Luyện tập, Gần đây, danh mục, bộ từ, tìm
     kiếm) có lớp phủ mờ khoá thao tác **"Đang lưu…"**, xong đổi thành dấu tick
     **"Đã lưu" + tên từ** rồi tan dần (blur nhẹ, spring, rung haptic). Không
     còn bấm nhầm trong lúc chờ.
  16. **Hết giật sau khi sửa từ**: màn danh mục / bộ từ cập nhật tại chỗ thay vì
     tải lại cả danh sách (nguyên nhân màn hình nhảy một cái).
  17. Giữ nguyên các cải tiến trước: import dán từ ngăn cách dấu phẩy + AI lấy
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
