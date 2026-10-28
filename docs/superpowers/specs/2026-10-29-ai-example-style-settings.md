# Spec: Cài đặt "Cách AI sinh ví dụ"

Ngày: 2026-10-29

## Mục tiêu

Người dùng muốn tự chỉnh cách AI chọn nghĩa và viết câu ví dụ, thay vì prompt cố định
trong `api/_lib/xai.js`. Mặc định mới phản ánh cách học hiệu quả:

- Bỏ qua nghĩa hiếm / nghĩa đen ít dùng, lấy nghĩa phổ biến mà người học cần:
  `concrete` → "cụ thể, rõ ràng" (không phải "bê tông"),
  `harness` → "tận dụng, khai thác" (không phải "yên cương ngựa").
- Ví dụ đặt trong bối cảnh đời sống hằng ngày hoặc công việc/IT — nơi người học gặp từ đó.

Thành công khi: trong Cài đặt có khung chỉnh; thay đổi áp dụng ngay cho lần tạo
nghĩa/ví dụ kế tiếp; không cần sửa code hay deploy lại.

## Quyết định đã chốt với người dùng

| Câu hỏi | Lựa chọn |
| --- | --- |
| Mức chỉnh | Preset (bối cảnh + bỏ nghĩa hiếm) **+** ô "Yêu cầu riêng" tự do ≤ 300 ký tự |
| Phạm vi áp dụng | Cả **nghĩa** (khi thêm/import từ) **và ví dụ**; không đổi cách chọn loại từ |
| Lưu trữ | Theo **tài khoản** (server, `users.ai_example_style`), giống `ai_configs` |

## Mô hình dữ liệu

`users.ai_example_style TEXT` (JSON):

```json
{ "contexts": ["daily", "work", "it"], "skipRareSenses": true, "custom": "" }
```

Mặc định khi chưa lưu / JSON hỏng: `contexts = ["daily", "work", "it"]`,
`skipRareSenses = true`, `custom = ""`.

Danh mục bối cảnh (id dùng chung client ↔ server, nhãn tiếng Việt ở client):

| id | Nhãn UI | Cụm tiếng Anh đưa vào prompt |
| --- | --- | --- |
| `daily` | Đời sống hằng ngày | everyday life |
| `work` | Công việc / văn phòng | work and the office |
| `it` | IT & công nghệ | IT and technology |
| `study` | Học tập / thi cử | study and exams |
| `travel` | Du lịch | travel |
| `business` | Kinh doanh | business |
| `health` | Sức khoẻ | health and daily wellbeing |
| `media` | Phim ảnh / giải trí | films, series and entertainment |

## Hợp đồng API

- `getAiExampleStyle` → trả object style đã chuẩn hoá.
- `saveAiExampleStyle` (`{ style }`) → chuẩn hoá, lưu, trả object đã lưu.
- Mọi case sinh nghĩa/ví dụ (`addVocabularyWord`, `generateWordExample`,
  `updateVocabularyWordDetails`, `updateVocabularyWord`, `bulkAddWords`,
  `enrichWords`) tự đọc style của user và truyền vào prompt — client không phải gửi kèm.

## Prompt

Style được ghép thành khối "Learner preferences" đặt sau phần Rules, trước `Word:`:

- `skipRareSenses: true` → yêu cầu chọn nghĩa người học cần, kèm 2 ví dụ concrete/harness.
- `contexts` → liệt kê bối cảnh nên đặt câu (rỗng = để AI tự chọn).
- `custom` → một dòng `Extra notes from the learner: ...` (đã gộp khoảng trắng, cắt 300 ký tự).

Ràng buộc cứng giữ nguyên: đúng 1 câu 5–20 từ, **phải chứa từ mục tiêu**, JSON only.
Không còn khoá trình độ A2–B1: câu viết ở mức tự nhiên mà chính từ đó cần (từ thông dụng
thì đơn giản, từ nâng cao thì được nâng cao).
Prompt nghĩa (`buildWordInfoPrompt`) nhận cùng style để chọn nghĩa phổ biến trước.

## Cấu trúc file

```
api/_lib/xai.js                        → normalizeExampleStyle, buildStylePrompt, prompt mới
api/lingoflow.js                       → cột users.ai_example_style + 2 case get/save + truyền style
lib/services/ai_settings_service.dart  → AiExampleStyle, AiExampleContext
lib/services/database_service_web.dart → getAiExampleStyle / saveAiExampleStyle
lib/widgets/ai_example_style_sheet.dart→ khung chỉnh (bottom sheet)
lib/pages/profile_page.dart            → mục "Cách AI sinh ví dụ" trong Cài đặt
test/xai_example_style.test.js         → test prompt/normalize (node --test)
test/ai_example_style_test.dart        → test model + sheet (flutter test)
```

## Kiểm thử

- Node: mặc định khi thiếu/hỏng dữ liệu; prompt chứa khối ưu tiên; tắt `skipRareSenses`
  thì mất khối nghĩa hiếm; `custom` bị cắt 300 ký tự và gộp khoảng trắng; id bối cảnh lạ bị loại;
  luật "phải chứa từ mục tiêu" vẫn còn trong prompt.
- Flutter: round-trip JSON của `AiExampleStyle`; từ chối id lạ; sheet hiện mặc định,
  bật/tắt và lưu trả về style đã chỉnh.
- Lệnh: `node --test test/xai_example_style.test.js`, `flutter analyze`, `flutter test`.

## Boundaries

- Always: luật JSON + từ mục tiêu phải giữ trong prompt; style do server chuẩn hoá lại,
  không tin JSON từ client.
- Ask first: đổi thứ tự provider AI, thêm loại từ mới, đổi schema bảng khác.
- Never: cho người dùng sửa thẳng prompt gốc; log API key; để `custom` dài quá 300 ký tự.

## Success criteria

1. Vào Cài đặt → "Cách AI sinh ví dụ": chọn bối cảnh, tắt/bật bỏ nghĩa hiếm, nhập yêu cầu riêng,
   lưu thành công và mở lại thấy đúng giá trị đã lưu.
2. Không cấu hình gì → ví dụ mới vẫn ưu tiên nghĩa phổ biến + bối cảnh đời sống/IT.
3. Xoá hết bối cảnh + tắt bỏ nghĩa hiếm + không có yêu cầu riêng → prompt quay về dạng cũ.
4. Mọi test hiện có vẫn xanh.
