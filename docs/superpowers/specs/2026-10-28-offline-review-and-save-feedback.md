# Spec: Chặn ôn tập khi offline + phản hồi "Đang lưu / Đã lưu" khi sửa từ

## Objective

Hai lỗi người dùng báo:

1. Mất mạng vẫn ôn tập (chấm điểm) bình thường, nhưng tiến độ SRS không lưu được
   (lỗi bị nuốt trong `catchError`). Thoát ra vào lại phải làm lại từ đầu.
   → Không cho phép chấm điểm khi không lưu được: chặn ngay, báo rõ, cho thử lại
   hoặc thoát. Không im lặng đánh rơi tiến độ.
2. Sau khi sửa từ ở bất kỳ màn nào, sheet/dialog đóng → màn hình trở lại rồi
   "giật" một cái (do reload danh sách / đổi chiều cao thẻ / hiện loading).
   → Trong lúc lưu, phủ một lớp khoá thao tác "Đang lưu…"; xong đổi thành dấu
   tick "Đã lưu" tinh tế rồi tan. Danh sách cập nhật tại chỗ, bỏ reload gây giật.

Người dùng chốt: (1) chặn hẳn khi offline, (2) lớp phủ khoá + xác nhận tại chỗ,
(3) phong cách premium/tinh tế (blur nhẹ, tick vẽ nét, spring, haptic).

## Tech Stack

- Flutter/Dart (SDK ^3.10.1), `http`, `shared_preferences`.
- API server-backed (`DatabaseService` → `/api/lingoflow`), không có cache offline.
- Không thêm dependency.

## Commands

- Test: `flutter test`
- Analyze: `flutter analyze`
- Test riêng: `flutter test test/offline_guard_test.dart test/save_feedback_test.dart`

## Project Structure

- `lib/widgets/save_feedback.dart` — lớp phủ "Đang lưu…" → "Đã lưu" + `runWithSaveFeedback`.
- `lib/widgets/save_blocked_dialog.dart` — hộp thoại chặn khi lưu tiến độ thất bại.
- `lib/services/network_error.dart` — nhận diện lỗi mạng từ thông điệp API.
- `lib/pages/review_page.dart`, `practice_page.dart` — chặn chấm điểm khi lỗi lưu.
- `lib/pages/category_page.dart`, `recent_page.dart`, `vocabulary_set_page.dart`,
  `lib/widgets/search_bottom_sheet.dart` — bọc luồng sửa từ, bỏ reload gây giật.
- `test/` — widget test cho cả hai hành vi.

## Code Style

```dart
final saved = await runWithSaveFeedback<String>(
  context: context,
  word: result.word,
  action: () async {
    await _db.updateVocabularyWord(...);
    return result.word;
  },
);
```

- Comment tiếng Việt không dấu ở các quyết định phi hiển nhiên (theo code hiện có).
- Chuỗi UI tiếng Việt có dấu; giữ font `Plus Jakarta Sans` / `Be Vietnam Pro`.

## Testing Strategy

- Widget test dùng `MockClient` như `test/review_edit_test.dart`.
- Offline: `updateWordReview` trả lỗi mạng → hộp thoại chặn xuất hiện, thẻ hiện
  tại không đổi, "Thử lại" gửi lại request và chỉ đi tiếp khi thành công.
  Tải danh sách lỗi mạng → màn "Cần kết nối mạng" + "Thử lại", không hiện
  "All caught up!".
- Save feedback: trong lúc request bị gate, lớp phủ "Đang lưu…" chặn chạm;
  xong hiện "Đã lưu" và tự tan; lỗi thì lớp phủ biến mất và rollback như cũ.
- Sửa từ ở màn danh mục không gọi `getWordsByCategory` lần hai (không giật).

## Boundaries

- Always: giữ nguyên rollback + snackbar lỗi hiện có; chạy `flutter test` và
  `flutter analyze`; bọc mọi luồng sửa từ bằng cùng một lớp phủ.
- Ask first: thêm dependency, đổi API/schema, đổi thuật toán SRS.
- Never: lưu tiến độ giả khi chưa ghi thành công, bỏ test, hay chặn thao tác
  bằng cách im lặng không báo gì.

## Success Criteria

- Chấm điểm khi request lưu thất bại: thẻ không chuyển, hộp thoại chặn hiện ra,
  "Thử lại" lưu lại đúng lượt đó rồi mới đi tiếp.
- Mở ôn tập khi mất mạng: màn báo "Cần kết nối mạng" + "Thử lại", không phải
  màn "All caught up!".
- Sửa từ xong: có "Đang lưu…" khoá tương tác, rồi "Đã lưu" + tên từ, tự tan;
  không còn spinner/reload làm màn hình nhảy.
- `flutter test` và `flutter analyze` sạch.

## Open Questions

- Không còn. (Đã chốt hành vi offline, kiểu phản hồi và phong cách hiệu ứng.)
