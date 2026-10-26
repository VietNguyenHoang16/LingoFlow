# Spec: AI phân loại & lấy nghĩa khi import và khi sửa từ

## Objective

- Import chỉ cần dán danh sách từ ngăn cách bằng dấu phẩy. AI lấy nghĩa tiếng
  Việt, phân loại loại từ, rồi pipeline cũ tạo ví dụ như trước.
- Từ nào AI không trả về được nghĩa bị bỏ qua và được báo lại trước khi import.
- Sửa Từ trong màn Review: AI tự lấy nghĩa mới + phân loại lại loại từ; phát âm /
  chi tiết vẫn lấy từ dictionaryapi.dev.

## Tech Stack

- Flutter/Dart (dialog import, màn Review).
- Vercel Node.js API + PostgreSQL.
- `api/_lib/xai.js`: chuỗi provider AI sẵn có (`createAiChain`) + Gemini fallback.

## Commands

- `flutter test`
- `flutter analyze`
- `node --check api/lingoflow.js && node --check api/_lib/xai.js`
- `node --test test/*.test.js`

## Project Structure

- `api/_lib/xai.js`: thêm prompt/normalizer `generateWordInfo`.
- `api/lingoflow.js`: action `enrichWords`.
- `lib/services/database_service_web.dart`: `enrichWords()` + `AiWordInfo`.
- `lib/services/bulk_word_importer.dart`: `parseWords`, `enrichMeanings`.
- `lib/widgets/bulk_import_dialog.dart`: bước "Phân tích bằng AI" + preview.
- `lib/pages/review_page.dart`, `lib/widgets/quick_word_edit.dart`: sửa từ.

## Code Style

Một request AI cho mỗi từ, chạy song song có giới hạn, dùng chung deadline để
request không vượt `maxDuration` 60s:

```js
const chain = createAiChain(await getUserAiConfigs(data.userId));
const info = await chain.generateWordInfo({ word }, { timeoutMs, deadline });
```

## Testing Strategy

- Node: prompt + normalizer + `generateWordInfo` với `fetch` giả.
- Dart: parse danh sách phẩy, enrich thành công / lỗi, dialog import đầy đủ
  (phân tích → preview → import), sửa từ trong Review (AI nghĩa/loại từ, để
  trống nghĩa, AI lỗi thì không lưu).

## Boundaries

- Always: giữ pipeline tạo ví dụ hiện có (`bulkAddWords`), báo rõ từ bị bỏ qua.
- Ask first: đổi schema, thêm dependency, đổi màn import khác (bộ từ).
- Never: lưu từ khi AI không cho được nghĩa, gọi AI không có xác thực.

## Success Criteria

- Dán `serendipity, resilient` → preview hiện nghĩa tiếng Việt + loại từ.
- Từ AI bỏ sót hiện lỗi và không được import; số lượng bỏ qua hiện ở màn kết quả.
- Review: đổi Từ, để trống Nghĩa → lưu nghĩa + loại từ do AI lấy, ví dụ được
  tạo lại; AI lỗi → không lưu, hiện thông báo.
- `flutter test` (145 test) và `node --test test/*.test.js` (42 test) xanh.
