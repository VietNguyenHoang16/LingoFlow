# Spec: Hai loại từ vựng — Học ngay (active) & Nên biết (passive)

- Ngày: 2026-10-31
- Trạng thái: **đã duyệt** — Phase 1 đã triển khai, Phase 2–5 đang chờ
- Người dùng: chủ app, mục tiêu giao tiếp đời thường + IT

## 1. Mục tiêu

App chỉ còn **2 loại từ vựng**, mỗi loại có cơ chế học khác nhau:

| | **Học ngay** (active) | **Nên biết** (passive) |
|---|---|---|
| Mục đích | Dùng chủ động: nói, viết, email, họp, code | Nhận ra & hiểu khi đọc/nghe |
| Tiêu chí | Gặp thường xuyên (đời thường + IT), dùng được ngay tuần này | Gặp thỉnh thoảng, ngữ cảnh hẹp (tin tức, tài liệu, trang trọng) |
| Kiểu ôn | Gõ từ (spell) — như hiện tại | **Chọn nghĩa đúng trong 4 đáp án**, không cần gõ |
| Lịch ôn | SRS đầy đủ (SM-2), mastery 0–3, due hằng ngày | SRS nhẹ: giãn cách dài hơn, không lên mastery |
| Đếm "cần ôn hôm nay" | Có (nút chính) | Không — có mục riêng "Gặp lại nhẹ (N)" |
| Cụm từ đi kèm | Có (AI sinh 2–3 collocation) | Không |
| Ảnh hưởng chuỗi ngày học | Có | Không |
| Ví dụ | `acknowledge` (xác nhận alert) | `chancellor` (hiểu khi đọc tin) |

**Không ưu tiên** (vd `bloc`) không phải loại thứ 3: chỉ là nhãn AI trả về ở bước
phân tích/import, mặc định **không tick** để không lưu (vẫn tick tay được nếu muốn).

## 2. User stories

1. Thêm/import từ → AI gán `Học ngay` / `Nên biết` / `Không ưu tiên` kèm nghĩa +
   từ loại; riêng Học ngay có thêm 2–3 cụm từ đi kèm. Tôi sửa được bằng 1 chạm.
2. Trang chính có 2 nhóm riêng: **Học ngay** và **Nên biết**, đếm due riêng.
3. Ôn Học ngay: gõ từ như hiện tại; sai thì hẹn gặp lại sớm.
4. Ôn Nên biết: hiện từ (kèm phát âm), tôi chọn 1 trong 4 nghĩa; đúng thì giãn
   lịch dài, sai thì hiện nghĩa + ví dụ và hẹn gặp lại sớm. Không bắt gõ.
5. Đổi loại bất kỳ lúc nào: Nên biết → Học ngay (bắt đầu SRS từ đầu);
   Học ngay → Nên biết (giữ nghĩa, reset lịch ôn nhẹ).
6. Dữ liệu cũ được AI phân loại lại, tôi xem trước/sửa trong 1 màn duyệt rồi áp dụng.

## 3. Mô hình dữ liệu

Thêm cột vào `vocabulary_words`:

```sql
learning_mode VARCHAR(10) NOT NULL DEFAULT 'active'  -- 'active' | 'passive'
collocations  TEXT DEFAULT ''                        -- "comply with · be compliant with · compliance"
```

- Giữ nguyên các cột SRS hiện có (`ease_factor`, `interval_days`, `next_review_date`,
  `mastery_level`, `lapse_count`, ...) cho cả 2 loại.
- `word_type`, `topic_tag`: **giữ trong DB nhưng bỏ khỏi UI** (chỉ dùng ẩn cho AI
  và màn Ôn cấu trúc/grammar hiện có).
- `collocations` chỉ dùng cho Học ngay.

### Quy tắc lịch ôn (mặc định, có thể chỉnh)

| Loại | Lần đầu | Đúng | Sai | Trần |
|---|---|---|---|---|
| Học ngay | due ngay/ngày mai (như hiện tại) | SM-2 như hiện tại | quay lại sớm, mastery có thể giảm | không |
| Nên biết | due ngay | 1 → 3 → 7 → 21 → 45 ngày | về 1 ngày, không giảm mastery | 60 ngày |

Nên biết **không bao giờ** tăng `mastery_level` (giữ 0) và không vào chuỗi ngày học.
Khi đổi sang Học ngay: `next_review_date = null`, `mastery_level = 0`,
`interval_days = 0`, `correct_streak = 0`.

## 4. API

Thêm/sửa action trong `api/lingoflow.js`:

| Action | Thay đổi |
|---|---|
| `enrichWords` | Prompt trả thêm `learningMode` (`active/passive/skip`), `collocations[]` (chỉ active). Chuẩn hoá + fallback `active` nếu AI trả thiếu. |
| `mapWordRow` | Trả thêm `learning_mode`, `collocations`. |
| `getDueWords`, `getAllWordsDueForReview` | Chỉ lấy `learning_mode = 'active'`. |
| `getPassiveDueWords` (mới) | Lấy từ `passive` đã đến hạn, giới hạn 20/lần. |
| `getDashboardStats` | Thêm `passiveDue`; `dueToday` chỉ còn active. |
| `getRecentWords` | Thêm `mode` filter (`all/active/passive`). |
| `getWordsByMode` (mới) | Danh sách theo loại cho tab trên trang chính (phân trang như getVocabularyWords). |
| `updateVocabularyWord` | Nhận thêm `learningMode`, `collocations`. |
| `setWordLearningMode` (mới) | Đổi loại 1 từ + reset lịch đúng quy tắc trên. |
| `bulkSetLearningMode` (mới) | Áp dụng kết quả màn duyệt migration (danh sách id + mode). |
| `getMigrationCandidates` (mới) | Danh sách từ cần phân loại lại (id, word, meaning, word_type, topic_tag, mode hiện tại). |

## 5. UI

### 5.1 Trang chính (RecentPage)
- Segmented control **Học ngay (n) | Nên biết (m)** ngay dưới ô tìm kiếm.
- Mỗi thẻ có chip loại (màu primary = Học ngay, teal = Nên biết).
- Nút đáy: **"Ôn tập hôm nay (N)"** chỉ đếm active; thêm dòng **"Gặp lại nhẹ (M)"**
  (nhỏ, teal) khi có passive due → mở phiên ôn Nên biết.
- Bỏ màn danh mục/chủ đề khỏi luồng (CategoryPage hiện không còn entry point);
  bỏ badge từ loại/chủ đề trên thẻ.
- Menu dài (long-press) thêm: **"Chuyển sang Nên biết"** / **"Chuyển sang Học ngay"**.

### 5.2 Ôn Học ngay (ReviewPage)
- Giữ nguyên luồng gõ từ, mastery, SRS.
- Thẻ đáp án hiện thêm block **"Cụm từ"** (collocations) dạng chip.

### 5.3 Ôn Nên biết (màn mới `PassiveReviewPage`)
- Hiện từ + phát âm (+ loa). 4 đáp án nghĩa (1 đúng + 3 nhiễu lấy từ nghĩa các từ
  khác của user) — **Multiple Choice quay lại CHỈ ở màn này**.
- Chọn đúng: xanh + "Đúng rồi" + giãn lịch; chọn sai: đỏ + hiện đúng + ví dụ,
  hẹn gặp lại 1 ngày.
- Trả về trang chính các số due mới; không ảnh hưởng streak/XP.

### 5.4 Import / Thêm từ
- Preview mỗi dòng có chip 3 trạng thái: `Học ngay` / `Nên biết` / `Bỏ qua`
  (Bỏ qua = không tick sẵn).
- Với Học ngay: hiện thêm cụm từ AI gợi ý (2–3), sửa được trước khi lưu.
- Nút Import đếm đúng số dòng được tick (active + passive, trừ bỏ qua).

### 5.5 Sửa từ / Tìm kiếm
- Edit sheet thêm chọn loại + sửa collocations (chỉ hiện khi Học ngay).
- Kết quả tìm kiếm hiện chip loại; lọc được theo loại.

### 5.6 Migration (dữ liệu cũ)
- Màn `ModeMigrationPage`: gọi AI phân loại lại theo lô (30 từ/lần), hiện tiến độ;
  bảng kết quả: từ | nghĩa | loại AI gợi ý | sửa nhanh | "chọn tất cả Học ngay/Nên biết".
- Nút "Áp dụng" → `bulkSetLearningMode` (có xác nhận số lượng), báo kết quả.
- Chạy 1 lần, mở từ Hồ sơ → "Phân loại lại từ vựng".

## 6. Prompt phân loại (AI)

```
Người học: người Việt, mục tiêu giao tiếp đời thường + công việc IT.
Với mỗi từ, chọn 1 trong 3 nhãn:
- "active"  (Học ngay): từ cốt lõi, gặp thường xuyên trong email/họp/code/hội thoại
  hằng ngày; người học cần DÙNG được tuần này (vd: acknowledge, deploy, deadline).
- "passive" (Nên biết): từ hay nhưng ngữ cảnh hẹp/chuyên sâu/trang trọng; chỉ cần
  HIỂU khi đọc/nghe (vd: chancellor, auditor, bloc).
  Từ chuyên ngành IT mà một dev bình thường ít tự nói cũng xếp "passive".
- "skip" (Không ưu tiên): gần như không xuất hiện trong công việc/giao tiếp của
  người học, hoặc quá hiếm/chính trị/tin tức xa (vd: bloc).
Trả thêm "collocations": 2-3 cụm hay dùng nhất (chỉ khi active; passive/skip để []).
```

## 7. Testing

- Unit: chuẩn hoá nhãn (thiếu/sai → `active`), collocations (tối đa 3, bỏ rỗng),
  công thức lịch passive (bảng trên), tạo 3 đáp án nhiễu không trùng nghĩa đúng.
- Widget: preview import 3 trạng thái (bỏ qua không tick sẵn); tab trang chính;
  phiên Nên biết chọn đáp án (đúng/sai); phiên Học ngay vẫn gõ từ; chip collocations.
- API: SQL với schema tạm + ROLLBACK cho `getPassiveDueWords`, `getDashboardStats`,
  `setWordLearningMode` (reset lịch), `bulkSetLearningMode`.
- Regression: 197 test hiện có phải pass; cập nhật test nào phụ thuộc due-count.

## 8. Ranh giới

- Always: `flutter test`, `flutter analyze` sạch; commit nhỏ theo phase; cập nhật
  `apk/README.md` + SHA khi build APK; verify bundle production.
- Ask first: đổi công thức lịch passive; xoá dữ liệu; đổi schema ngoài 2 cột trên.
- Never: tự xoá từ của user; chạy migration tự động không qua màn duyệt; đưa
  Multiple Choice trở lại màn Luyện tập (chỉ dùng ở phiên Nên biết).

## 9. Kế hoạch theo phase

1. **Phase 1 — Nền dữ liệu + AI**: schema 2 cột, mapWordRow, prompt 3 nhãn +
   collocations, import preview 3 trạng thái, edit chọn loại. Test unit/API.
2. **Phase 2 — Trang chính 2 nhóm**: tab Học ngay/Nên biết, chip trên thẻ, đếm due
   riêng, bỏ badge/filter cũ, menu đổi loại.
3. **Phase 3 — Ôn Nên biết**: `PassiveReviewPage` (4 đáp án), công thức lịch passive,
   nút "Gặp lại nhẹ", thống kê.
4. **Phase 4 — Migration**: màn duyệt AI + bulk apply.
5. **Phase 5 — Ship**: test toàn bộ, deploy Vercel, build APK, verify, cập nhật README.

## 10. Câu hỏi mở (mặc định đang dùng, đổi được)

1. Lịch passive `1/3/7/21/45`, trần 60 ngày — ổn không?
2. Nên biết **không** tính vào chuỗi ngày học / thống kê "đã thuộc" — ổn không?
3. Luyện tập (PracticePage) chỉ dùng cho Học ngay; Nên biết chỉ ôn qua "Gặp lại nhẹ" — ổn không?
4. Từ Nên biết khi đổi sang Học ngay sẽ **reset lịch** (học lại từ đầu) — đúng ý không?

## 11. Nhật ký triển khai

### Phase 1 — xong (2026-10-31)
- DB: 2 cột `learning_mode`, `collocations` (tự thêm trong `ensureSchema`).
- API: `mapWordRow` trả 2 trường; `addVocabularyWord`, `bulkAddWords`,
  `updateVocabularyWord` lưu 2 trường; `enrichWords` trả `learningMode`
  (`active/passive/skip`) + `collocations`.
- AI: prompt phân loại theo mục tiêu giao tiếp + IT; cụm từ chỉ cho `active`
  (tối đa 3, chuẩn hoá `a · b`).
- Import: chip 3 trạng thái bấm để đổi, cụm từ hiện dưới từ, dòng "Bỏ qua"
  không tick sẵn / không gửi lên; thống kê tách Học ngay / Nên biết / Bỏ qua.
- Client: `ImportLine`, `AiWordInfo` mang thêm 2 trường; payload gửi kèm.
- Test: +4 test (map mode/cụm từ, bỏ qua không gửi, payload, preview chip).
  201 test pass; analyze không thêm lỗi.
- Chưa làm (Phase 2–5): tab 2 loại ở trang chính, chip trên thẻ, đổi loại
  trong menu/sửa từ, phiên ôn Nên biết (4 đáp án), đếm due riêng, màn migration.

### Phase 2 — xong (2026-10-31)
- Trang chính có 2 tab **Học ngay / Nên biết** (kèm số due từng loại) ngay dưới
  tiêu đề; danh sách lọc theo tab (`getRecentWords` nhận `mode`).
- Thẻ hiện chip loại (Học ngay = primary, Nên biết = teal); bỏ badge từ loại /
  chủ đề khỏi thẻ theo spec.
- Menu long-press có **"Chuyển sang Học ngay / Nên biết"** → gọi
  `setWordLearningMode`, reload danh sách + due.
- Đếm riêng: `dueToday` chỉ active; thêm `passiveDue`; nút "Gặp lại nhẹ (M)"
  đứng cạnh "Ôn tập hôm nay (N)".
- Luyện tập (▶) chỉ hiện ở tab Học ngay.

### Phase 3 — xong (2026-10-31)
- `PassiveReviewPage`: từ + phát âm + loa, 4 đáp án nghĩa (1 đúng + 3 nhiễu từ
  nghĩa của các từ khác), chọn đúng/sai, hiện nghĩa + ví dụ + lịch gặp lại.
- Lịch giãn 1 → 3 → 7 → 21 → 45 ngày theo `review_count`; sai hẹn 1 ngày;
  `mastery_level` giữ 0 (không lên cấp), không tính due/streak của Học ngay.
- Lưu qua `updateWordReview` (sẵn có) với mastery 0.

### Phase 4 — xong (2026-10-31)
- `ModeMigrationPage`: tải toàn bộ từ (`getMigrationCandidates`), AI phân loại
  theo lô 30 từ (dùng `enrichWords`), chip sửa tay, đổi hàng loạt, đếm thay đổi.
- "Áp dụng" chỉ gửi các từ đổi loại qua `bulkSetLearningMode` (1 câu UPDATE
  dùng unnest), reset lịch đúng quy tắc.
- Vào từ Cài đặt → "Phân loại từ vựng".

### Phase 4b — duyệt lô 20 từ (2026-10-31)
- `learning_mode = ''` = **chưa phân loại**; migration version 6 đưa toàn bộ từ về
  trạng thái này một lần (không đụng lịch ôn). Hai tab vẫn hiện từ '' (coi như Học
  ngay) và thẻ hiện chip "Chưa phân loại".
- Màn phân loại mới: mỗi lô 20 từ, mỗi từ có **nút lớn 2 bên Học ngay / Nên biết**
  (bấm bên nào sáng bên đó, bấm lại để bỏ chọn); có **Copy N từ** (chỉ từ tiếng
  Anh, cách nhau dấu phẩy), AI gợi ý, "Tất cả Học ngay/Nên biết"; "Nộp N từ" chỉ
  bật khi chọn đủ lô.
- Nộp qua `bulkClassifyWords` (chỉ đổi `learning_mode`, không reset lịch ôn); từ
  đã có trạng thái không xuất hiện ở lô sau.

