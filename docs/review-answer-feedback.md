# Review: tô ký tự gõ sai trên thẻ đáp án

## Objective and approved interaction
Chế độ Review thường yêu cầu gõ lại từ tiếng Anh. Trước đây khi gõ sai, người dùng chỉ nhận được icon ❌ đỏ và dòng `You typed: <cả chuỗi>` — không biết sai ở chữ nào, thiếu hay thừa ký tự. Người dùng đã duyệt (trao đổi trực tiếp) phương án: **tô ngay trên từ đáp án trong thẻ + tô dòng "You typed"**, không thêm khối UI mới và không thêm câu giải thích bằng lời.

## Stack and conventions
- Thuần Flutter/Dart, không thêm dependency (repo có quy tắc hỏi trước khi đổi dependency; `characters` chỉ là transitive trong `pubspec.lock`).
- Logic tách khỏi UI đặt trong `lib/services/` (theo mẫu `review_word_utils.dart`) để test thuần Dart và tái dùng cho Practice sau này.
- Widget trình bày đặt trong `lib/widgets/` (theo mẫu `review_example_panel.dart`).
- Test theo mẫu `test/review_*_test.dart` (MockClient từ `http/testing`, mock `flutter_tts`, `AppTheme.light`).
- **Không đụng SRS**: `_isAnswerCorrect` trước giờ chỉ mang tính cố vấn (điểm do người dùng bấm 1-4). Kết luận đúng/sai vẫn giữ nguyên công thức cũ `typed.trim().toLowerCase() == expected.toLowerCase()`.

## Implementation
1. `lib/services/answer_comparison.dart` (mới)
   - `diffAnswer({typed, expected})` → `AnswerDiff { isCorrect, distance, expectedMarks, typedMarks, hasMismatch, mismatchCount, similarity }`.
   - Căn chỉnh ký tự bằng LCS (DP, tie-break ưu tiên "thiếu") + Levenshtein 2 hàng cho `distance`; gộp cặp (thiếu + thừa) liền kề thành `replaced` để không nhiễu khi chỉ sai 1 ký tự.
   - Tách ký tự theo `runes` (không cắt đôi surrogate pair). Chốt an toàn: chuỗi > 64 ký tự bỏ qua căn chỉnh; tích n*m > 25000 bỏ qua Levenshtein — không bao giờ ném exception.
   - Trả lời khác hẳn đáp án (không chung ký tự nào) → trả về toàn dấu `keep`, tức **không tô gì** (tô kín cả từ chỉ gây nhiễu), nhưng vẫn chấm sai như cũ.
   - Chưa gõ gì (rỗng / chỉ khoảng trắng) → không có dấu lệch nào để tô.
   - Ngữ nghĩa "đúng/sai" giữ y như code cũ; mọi khác biệt hoa/thường và khoảng trắng đầu-cuối vẫn được coi là đúng và **không** tô đỏ.
2. `lib/widgets/answer_diff_text.dart` (mới)
   - Nhận `text` + `marks`, render `Text.rich` với span gom theo trạng thái: `missing`/`replaced` → gạch chân chấm + amber đậm; `extra`/`replaced` (phía chuỗi đã gõ) → gạch ngang + amber.
   - Tự kiểm tra `marks` có dựng lại đúng `text` không; sai lệch thì fallback về `Text` thường (không bao giờ crash/hiển thị sai chữ).
3. `lib/pages/review_page.dart`
   - `_answerDiff` chỉ được tính trong `_showAnswerCard()` khi `!widget.grammarReview`; `_isAnswerCorrect = _answerDiff!.isCorrect`.
   - Reset `_answerDiff = null` ở `_rateWord()` và ở nhánh xoá từ (giữ nguyên các reset cũ).
   - `_buildAnswerWord()`: từ đáp án giữ nguyên style cũ (Plus Jakarta Sans, 24/30) — chỉ đổi sang bản tô ký tự khi có dấu lệch.
   - `_buildTypedLine()`: dòng `You typed: ...` giữ nguyên tiền tố + nội dung như cũ; khi có ký tự thừa/sai thì chèn dấu `keep` cho tiền tố và render bản có gạch ngang.
   - Màu tô `_answerMismatchColor = 0xFFFFD54F` (Amber 300) — đủ tương phản trên cả nền gradient indigo lẫn nền đỏ khi sai.

## Relevant files
- lib/services/answer_comparison.dart (mới)
- lib/widgets/answer_diff_text.dart (mới)
- lib/pages/review_page.dart
- test/answer_comparison_test.dart (mới)
- test/answer_diff_text_test.dart (mới)
- test/review_answer_diff_test.dart (mới)

## Commands (repository root)
- flutter test test/answer_comparison_test.dart
- flutter test test/answer_diff_text_test.dart
- flutter test test/review_answer_diff_test.dart
- flutter test
- flutter analyze
- flutter build web --release

## Verification results
- `test/answer_comparison_test.dart`: 17 test pass (đúng/sai, thiếu/thừa/thay thế ký tự, từ ghép, chưa gõ gì, đáp án rỗng, chuỗi 300 ký tự, emoji ngoài BMP, similarity, khác hẳn đáp án → không tô).
- `test/answer_diff_text_test.dart`: 6 test pass (màu + gạch chân ký tự thiếu, gạch ngang ký tự thừa, `replaced` theo tham số, fallback `Text` khi không có dấu / dấu lệch chuỗi, không overflow ở 320px).
- `test/review_answer_diff_test.dart`: 8 test pass (gõ thiếu → tô trên từ đáp án; gõ thừa → gạch ngang dòng "You typed"; gõ đúng → không tô; nhập rỗng → không tô và không có dòng "You typed"; trả lời khác hẳn → không tô; grammar → không tô; chấm Again → dấu biến mất; long-press vẫn mở xoá từ ẩn và huỷ không gọi API).
- Toàn bộ suite: **98 passed** (67 test cũ + 31 test mới). Các test cũ đụng màn Review (`review_delete_test.dart`, `review_enter_key_test.dart`, `review_example_panel_test.dart`) vẫn xanh.
- `dart analyze` trên 6 file Dart thay đổi/thêm: **No issues found**. `flutter analyze` toàn repo: 8 info-level tồn tại sẵn (vocabulary_set_page, review_word_utils, example_manager_sheet, word_type_badge_test), không phát sinh issue mới.
- `flutter build web --release`: thành công (`✓ Built build\web`, compile 52.9s); warning Wasm dry-run của `flutter_tts` vẫn là warning có sẵn.
- Minh bạch về TDD: 16 test util và 7 test tích hợp pass ngay; 3 test widget của `answer_diff_text_test.dart` fail ở lần chạy đầu do **helper của test** chưa đi xuống span con mà `Text.rich` bọc thêm (lỗi test, không phải lỗi widget) — đã sửa helper và pass.
- Chưa kiểm thử thủ công trên thiết bị thật (môi trường này không có tablet/iPad); hành vi layout khi bàn phím mở dựa trên nhánh `compactMode` có sẵn và test 320px.

## Acceptance
- Gõ sai mà lệch ký tự: ký tự thiếu/sai trên từ đáp án được tô amber + gạch chân; ký tự thừa trên dòng "You typed" được tô amber + gạch ngang.
- Gõ đúng (kể cả khác hoa/thường, thừa khoảng trắng đầu-cuối): giao diện y hệt trước đây, không tô gì.
- Chưa nhập gì rồi bấm Check: không tô đỏ, không có dòng "You typed" (vẫn có icon ❌ như cũ).
- Chế độ Grammar Review: không tô gì (không có ô nhập).
- Chấm điểm 1-4 hoặc xoá từ: dấu sai được xoá cùng thẻ đáp án; ẩn/hiện, long-press và luồng SRS không đổi.
- Không thêm dependency, không đổi schema/API, không đổi cách tính điểm SRS.

