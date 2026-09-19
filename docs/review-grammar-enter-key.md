# Review cấu trúc: phím Enter = Show answer

## Objective and approved interaction
Màn hình Review cấu trúc (Grammar Review, `ReviewPage(grammarReview: true)`) không có ô nhập, nên phím Enter trước đây không có tác dụng. Người dùng duyệt yêu cầu: bấm **Enter** (hoặc Enter bàn phím số) = bấm nút "Show answer", để luyện bằng bàn phím không cần chuột.

## Stack and conventions
Tái dùng cơ chế phím toàn cục sẵn có của app: `HardwareKeyboard.instance.addHandler` như `practice_page.dart` (đăng ký trong `initState`, gỡ trong `dispose`). Chọn handler toàn cục thay vì `KeyboardListener` vì ở grammar mode không node nào được focus lúc mở màn hình. Chế độ Review thường giữ nguyên: Enter trong ô nhập đã hoạt động qua `TextField.onSubmitted`.

## Implementation
- `lib/pages/review_page.dart`: thêm `_handleHardwareKey` — chỉ chặn Enter ở grammar mode; bỏ qua khi đáp án đang mở / phiên kết thúc (nuốt phím để không flip lại); trả focus cho dialog/bottom sheet đang mở qua `ModalRoute.isCurrent` (Enter của hộp thoại sửa nghĩa / xác nhận xóa không bị nuốt).
- `test/review_enter_key_test.dart`: 3 widget test (grammar mở thẻ, Enter lặp lại là no-op, chế độ thường không đổi) theo mock sẵn có của `review_delete_test.dart`.

## Relevant files
- lib/pages/review_page.dart
- test/review_enter_key_test.dart

## Commands (repository root)
- flutter test test/review_enter_key_test.dart
- flutter test
- flutter build web --release

## Verification results
- RED→GREEN: 2 test grammar fail trước khi sửa, pass sau khi sửa.
- Full Flutter suite: 64 passed (61 cũ + 3 mới).
- `dart analyze` trên 2 file thay đổi: No issues found.
- `flutter build web --release`: thành công; warning Wasm dry-run của package `flutter_tts` vẫn là warning có sẵn.

## Acceptance
- Grammar review: Enter ngay khi mở màn hình (không cần focus) hiển thị thẻ đáp án; chưa gửi `updateWordReview`.
- Enter lần nữa khi đáp án đang mở: không làm gì, không chấm điểm.
- Khi dialog/bottom sheet mở (sửa nghĩa, xóa từ): Enter thuộc về hộp thoại.
- Chế độ Review thường: hành vi Enter trong ô nhập không đổi.
- Phím 1-4 chấm điểm và phím 0 hint hoạt động như cũ.
