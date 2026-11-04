# Spec: Chế độ "nhìn từ chọn nghĩa" song song với "nhìn nghĩa gõ từ"

## Objective

Thêm chế độ ôn tập dạng trắc nghiệm: hiển thị **từ tiếng Anh** (+ phiên âm, badge
POS/topic), người dùng **chọn nghĩa đúng trong 4 lựa chọn**. Song song với chế độ
"nhìn nghĩa gõ từ" hiện có, và **đổi chế độ được ngay trong màn hình ôn tập**
(toggle trên đỉnh màn) — không cần quay ra chọn trước.

Áp dụng cho cả hai màn:
- `ReviewPage` (ôn SRS hằng ngày/due, chấm Again/Hard/Good/Easy)
- `PracticePage` (luyện tập bộ từ, studyMode: sai lặp lại cuối session)

Đã xác nhận với người dùng (2026-11-04):
1. Thêm vào cả 2 màn ReviewPage + PracticePage.
2. Nghĩa gây nhiễu là nghĩa thật của từ khác trong cùng bộ đang ôn; bộ quá ít
   thì bù ngẫu nhiên từ toàn bộ từ vựng user (qua action `getWordIndex` có sẵn).
3. 4 lựa chọn mỗi câu.
4. Đổi chế độ giữa session: giữ nguyên danh sách từ, câu hiện tại, điểm, queue Again.

## Tech Stack

- Flutter/Dart, StatefulWidget + setState (app không dùng provider).
- Material 3 theme tập trung (`lib/theme/app_theme.dart`), tái dụng `AnimatedPressable`,
  `ExampleCard`/`ReviewExamplePanel`, `ConfettiOverlay`, `SaveBlockedDialog`.
- Không thêm dependency, không đổi schema DB, không đổi API server
  (action `getWordIndex` đã có trên server — chỉ thêm method client).

## Commands

- Tests: `flutter test`
- Static analysis: `flutter analyze lib test`
- Deploy web/API: `vercel --prod --yes` (sau push)
- APK (vì sửa `lib/`): `flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info=build/symbols`,
  copy sang `apk/vocab-arm64-release.apk`, cập nhật `apk/README.md`, verify hash link tải.
- Verify production: `main.dart.js` trên https://vocab-virid.vercel.app phải chứa chuỗi mới.

## Project Structure

- `lib/pages/review_page.dart`, `lib/pages/practice_page.dart`: thêm state chế độ
  (`spelling` | `choice`), toggle UI, nhánh render câu hỏi, xử lý trả lời cho chế độ chọn.
- `lib/widgets/meaning_choice_card.dart` (mới): widget câu hỏi trắc nghiệm dùng chung
  cho cả 2 màn — từ + phiên âm + badges + danh sách option + trạng thái đúng/sai.
- `lib/services/meaning_choice_options.dart` (mới, pure Dart): hàm dựng bộ options,
  shuffle, dedupe nghĩa, fallback giảm số lựa chọn (tối thiểu 2).
- `lib/services/database_service_web.dart`: tái dụng method `wordIndex(userId)`
  đã có (cache trong bộ nhớ, tự invalidate khi sửa từ) để lấy pool nghĩa
  fallback toàn bộ từ vựng. Không thêm method, không đổi API server.
- `test/`: unit test cho `meaning_choice_options.dart`; widget test cho cả 2 màn
  (đổi chế độ giữa session, chọn đúng/sai, chấm SRS, retry).

## Code Style

Logic dựng options là pure function, dễ test, không phụ thuộc Flutter:

```dart
class MeaningOption {
  final String meaning;
  final bool isCorrect;
  const MeaningOption({required this.meaning, required this.isCorrect});
}

/// 1 đáp án đúng + tối đa 3 nhiễu lấy từ [poolMeanings] (đã loại trừ nghĩa đúng).
/// Trả về list đã shuffle; nếu pool không đủ thì giảm số lựa chọn (tối thiểu 2).
List<MeaningOption> buildMeaningOptions({
  required String correctMeaning,
  required Iterable<String> poolMeanings,
  required Random random,
});
```

- Đặt tên, format, theme inline theo pattern hiện có (`Theme.of(context)`,
  `withAlpha()` tint, radius 12–16, font 'Be Vietnam Pro'/'Plus Jakarta Sans').
- Nút option dùng `AnimatedPressable`; trạng thái chọn sai tô đỏ, đúng tô xanh
  (dùng `colorScheme.error` / `primary`), nút đã chọn disable sau khi trả lời.

## Testing Strategy

- **Unit** `meaning_choice_options_test.dart`: đúng 1 đáp án đúng; 3 nhiễu khác
  nhau và khác nghĩa đúng; thứ tự shuffle (correctIndex thay đổi qua nhiều lần gọi);
  pool < 3 → trả về ít options hơn nhưng ≥ 2; dedupe nghĩa trùng; loại nghĩa rỗng.
- **Widget PracticePage**: toggle sang chế độ chọn → hiện từ + 4 option; chọn sai
  → đỏ/xanh + panel đáp án + ví dụ; studyMode: sai thêm vào retry; lưu SRS khi
  `studyMode=false`.
- **Widget ReviewPage**: đổi chế độ giữa session giữ nguyên từ/câu/điểm; chọn đúng
  → quality Good, chọn sai → Again + đưa từ vào cuối queue.
- `flutter analyze lib test` không thêm issue mới so với baseline (6 info).

## Boundaries

- **Always**: tái dụng `SrsService`, `practiceResultToQuality`, dialog lưu lỗi,
  `WordChangeBus` flush, confetti khi hoàn thành; chạy test trước commit.
- **Ask first**: đổi API server, schema DB, thêm dependency, đổi ngữ nghĩa chấm SRS hiện có.
- **Never**: xoá/chế độ gõ từ; giả nghĩa nhiễu (phải là nghĩa thật của từ khác);
  commit secrets hay file log/build.

## Success Criteria

- Toggle "Gõ từ" / "Chọn nghĩa" trên cả ReviewPage và PracticePage; đổi giữa
  session giữ nguyên bộ từ, câu hiện tại, điểm, queue Again — không reset.
- Mỗi câu chọn nghĩa có 4 lựa chọn (1 đúng + 3 nhiễu cùng bộ; fallback toàn bộ
  từ vựng qua `getWordIndex`; tối thiểu 2 lựa chọn khi pool quá nhỏ).
- Chọn sai: option đỏ, option đúng xanh, panel đáp án (từ, phiên âm, ví dụ) hiện ra,
  chấm SRS/retry giống chế độ gõ từ.
- `flutter test` và `flutter analyze` pass; `main.dart.js` production chứa chuỗi
  mới; APK rebuild với hash cập nhật trong `apk/README.md`.

## Open Questions

- None — 4 điểm mơ hồ đã xác nhận với người dùng trước khi viết spec.
