# Plan: 2 nút ôn tập trên Dashboard — "Từ vựng đến hạn" & "Cấu trúc đến hạn"

## Bối cảnh
- Grammar đang bị loại khỏi ôn tập SRS (`NOT LIKE '%grammar%'`) — đây là chủ đích: grammar sẽ có kiểu ôn riêng.
- Yêu cầu: Dashboard hiển thị rõ **2 nút**: (1) số từ vựng đến hạn, (2) số cấu trúc (grammar) đến hạn. Nhấn nút nào ôn nấy.
- Quyết định đã chốt với user:
  1. Từ loại lai (vd `'noun,grammar'`) **tính vào nút cấu trúc** (đã bị loại khỏi ôn từ vựng → không từ nào bị rơi).
  2. Ôn cấu trúc **dùng lại ReviewPage** (flashcard + SRS), truyền cờ grammar.
  3. Vị trí: **Dashboard banner chính** (tách banner "Time to review!" hiện tại).

## Kiến trúc / quyết định kỹ thuật
- **Tách truy vấn, không tái sử dụng `getWordsDueForReviewByCategory('grammar')`**: vì query đó khớp `word_type` chính xác từng thành phần (`$2 = ANY(string_to_array(...))`) → không gộp được từ lai `'noun,grammar'`. Cần action mới dùng `LIKE '%grammar%'` (bù chính xác của `NOT LIKE '%grammar%'`).
- **Không đếm trùng**: `dueToday` (từ vựng) đã loại mọi word_type chứa 'grammar'; `grammarDue` chỉ đếm word_type chứa 'grammar'. Hai tập rời nhau.
- Thêm cờ `grammarReview` vào `ReviewPage` thay vì overload `category: 'grammar'` — tránh phụ thuộc vào string magic và giữ category query nguyên trạng.

## Danh sách task

### Phase 1: API (api/lingoflow.js)

#### Task 1: Thêm `grammarDue` vào stats + action lấy từ grammar đến hạn
**Mô tả:** API trả đủ số liệu cho 2 nút và cho phép nạp danh sách cấu trúc đến hạn.

**Thay đổi:**
1. `getDashboardStats` — query `reviewRows`: thêm cột
   `COUNT(*) FILTER (WHERE (vw.next_review_date IS NULL OR vw.next_review_date <= $2) AND vw.word_type LIKE '%grammar%') AS grammar_due`
   → trả về `reviewStats.grammarDue`.
2. `getReviewStats` — cập nhật tương tự (đồng bộ, đề phòng nơi khác dùng).
3. Thêm action `getWordsDueForReviewGrammar`:
   ```sql
   SELECT ... FROM vocabulary_words vw JOIN vocabulary_lists vl ...
   WHERE vl.user_id = $1
     AND (vw.next_review_date IS NULL OR vw.next_review_date <= $2)
     AND COALESCE(vw.word_type, '') LIKE '%grammar%'
   ORDER BY COALESCE(vw.next_review_date, CURRENT_TIMESTAMP) ASC
   ```
   (copy shape của `getAllWordsDueForReview` — có list_name/list_id.)

**Acceptance criteria:**
- [ ] `node --check api/lingoflow.js` pass
- [ ] `grammarDue` + `dueToday` không giao nhau (một từ chỉ nằm trong 1 trong 2)
- [ ] Từ `'noun,grammar'` đến hạn nằm trong grammarDue, KHÔNG nằm trong dueToday

**Files:** `api/lingoflow.js` | **Scope:** S

### Phase 2: Dart service + ReviewPage

#### Task 2: Method service + chế độ grammar trong ReviewPage
**Mô tả:** Client Dart gọi được API mới; ReviewPage có chế độ ôn cấu trúc.

**Thay đổi:**
1. `lib/services/database_service_web.dart`: thêm `getWordsDueForReviewGrammar(int userId)` (pattern giống `getAllWordsDueForReview`).
2. `lib/pages/review_page.dart`:
   - Thêm `final bool grammarReview;` (default `false`) vào constructor.
   - Trong `_loadDueWords`: `if (widget.grammarReview) → getWordsDueForReviewGrammar(userId)` đặt **trước** nhánh category.
   - Tiêu đề: `widget.grammarReview ? 'Grammar Review' : (listName ?? 'Daily Review')`.
   - SRS rating dùng nguyên flow hiện có (grammar word có đủ field SRS).

**Acceptance criteria:**
- [ ] `flutter analyze` không lỗi mới
- [ ] ReviewPage với `grammarReview: true` nạp đúng danh sách grammar (kiểm tra runtime)
- [ ] Nhánh hiện tại (daily / category / list) hoạt động không đổi

**Files:** `database_service_web.dart`, `review_page.dart` | **Scope:** S

### Phase 3: UI Dashboard

#### Task 3: Tách banner thành 2 nút
**Mô tả:** Thay `_buildDailyReviewBanner` bằng hàng 2 nút độc lập.

**Thay đổi (`lib/pages/dashboard_page.dart`):**
1. `_buildDailyReviewBanner` → trả `Row` gồm 2 nút mở rộng bằng nhau (`Expanded`):
   - **Nút 1 — Từ vựng:** giữ gradient `reviewBannerDue`/`reviewBannerDone`, badge `dueToday`, nhấn → `_navigateToReview()` (như cũ).
   - **Nút 2 — Cấu trúc:** gradient riêng (thêm màu mới, vd `reviewBannerGrammar` vào `AppLingoColors` cả light + dark trong `app_theme.dart`, đề xuất tím/violet phân biệt), badge `grammarDue`, nhấn → `ReviewPage(userId, grammarReview: true)`.
2. Trạng thái 0: mỗi nút tự hiển thị trạng thái done riêng (✅ / "All done!") theo số của chính nó.
3. Text theo style hiện tại (font Plus Jakarta Sans / Be Vietnam Pro, tiếng Anh như phần còn lại của app): "N words due" / "N structures due".
4. `_loadData()` reload sau khi pop (đã có sẵn ở `_navigateToReview` — nhân bản cho nút grammar).

**Acceptance criteria:**
- [ ] 2 nút hiển thị đúng số, cập nhật sau khi quay lại từ màn ôn
- [ ] Light + dark mode đều đọc được (contrast đủ)
- [ ] Nhấn nút cấu trúc mở ReviewPage ở chế độ grammar

**Files:** `dashboard_page.dart`, `app_theme.dart` | **Scope:** M

## Checkpoint cuối
- [ ] `node --check api/lingoflow.js` pass
- [ ] `flutter analyze` + `flutter test` pass
- [ ] Chạy app: thêm từ grammar có `next_review_date` trong quá khứ → nút cấu trúc hiện số đúng; ôn xong số giảm
- [ ] Từ lai `'noun,grammar'` chỉ tính vào nút cấu trúc

## Rủi ro & giảm thiểu
| Rủi ro | Mức | Giảm thiểu |
|---|---|---|
| `LIKE '%grammar%'` khớp thừa nếu sau này thêm loại từ chứa chữ "grammar" | Thấp | 12 loại từ là cố định (`kWordTypeKeys`); nếu thêm loại mới phải rà lại query |
| Row 2 nút bị chật trên màn hình nhỏ (số dài) | Thấp | Dùng `Expanded` + `maxLines: 1` + `ellipsis` cho text |
| Deploy API cũ hơn app mới (grammarDue undefined) | Trung bình | Dart đọc `grammarDue` với fallback `?? 0` → nút hiện 0, không crash |

## Không làm trong đợt này
- Thông báo đẩy riêng cho cấu trúc đến hạn (notification_service) — có thể làm sau.
- Màn hình ôn cấu trúc dạng riêng (điền chỗ trống v.v.) — dùng lại ReviewPage theo quyết định user.
