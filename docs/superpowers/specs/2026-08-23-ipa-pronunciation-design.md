# Auto-fill Phiên âm IPA — Design Spec

**Ngày:** 2026-08-23
**Trạng thái:** Đã duyệt

## Mục tiêu

Mọi card từ vựng hiển thị phiên âm IPA dạng `/ˈleɪ.bər/`. Hiện UI đã render `/pronunciation/` ở mọi card nhưng dữ liệu trong DB phần lớn rỗng (bulk import luôn chèn `''`, thêm tay không tự lấy).

## Phạm vi

- Tự fetch IPA khi thêm/import từ mới (cả 2 luồng import).
- Nút backfill trong Profile điền IPA cho toàn bộ từ cũ còn thiếu.
- Không đổi layer hiển thị.

## Nguồn dữ liệu

Tái dùng `DictionaryService` (dictionaryapi.dev) — trả IPA text + audio. Sửa parser: chọn phonetic **đầu tiên** non-empty thay vì cuối cùng.

## Luồng

| Luồng | Hành vi |
|---|---|
| Thêm/import từ | Fetch IPA trước khi insert; API fail → insert với `''`, không chặn batch |
| Backfill (Profile) | Nút "Cập nhật phiên âm": quét từ thiếu → fetch tuần tự → progress `x/y` → snackbar tổng kết |
| Hiển thị | Không đổi |

## DB / API

- API action mới `getWordsMissingPronunciation(userId)` — id + word của user có pronunciation rỗng.
- API action mới `updateWordPronunciation(wordId, pronunciation)` — ghi an toàn 1 field.

## Error handling

API fail/timeout → bỏ qua từ đó, đếm vào "không tìm thấy". Không bao giờ block thao tác chính.

## Lệch so với thảo luận ban đầu

Progress backfill hiển thị inline trong card Profile (LinearProgressIndicator) thay vì dialog — ít code, cùng UX.

## Testing

Unit test parse phonetic (`parseWordData` qua `@visibleForTesting`). Network/singleton code verify bằng analyze + smoke test.
