# Plan: Tách loại từ sang app Flutter mới

## Mục tiêu
- Giữ lại trong app hiện tại các loại từ đơn thuần: `noun`, `verb`, `adjective`, `adverb`, `preposition`, `conjunction`, `pronoun`
- Chuyển sang app mới các loại: `collocation`, `grammar`, `phrasal_verb`, `idiom`, `interjection`
- Dữ liệu sẽ được export ra file JSON trước khi xóa khỏi CSDL app hiện tại

## Các bước thực hiện

### Bước 1: Export dữ liệu ra file JSON
- Tạo script `scripts/export_word_types.js`
- Lấy tất cả `vocabulary_words` có `word_type` thuộc: `collocation`, `grammar`, `phrasal_verb`, `idiom`, `interjection`
- Xuất ra file `exports/advanced_words_export_<timestamp>.json`
- Format: mảng object với đầy đủ thông tin từ, nghĩa, word_type, list_id, user_id, created_at

### Bước 2: Xóa dữ liệu khỏi app hiện tại
- Chạy script `scripts/delete_word_types.js`
- Xóa tất cả `vocabulary_words` có `word_type` thuộc 5 loại cần chuyển
- Xóa các `vocabulary_lists` rỗng (không còn word nào) của các category tương ứng
- Giữ nguyên users và các danh sách của các loại từ đơn

### Bước 3: Tạo app Flutter mới
- Tạo project Flutter mới tên `vocab_advanced` (hoặc tên bạn chọn)
- Tạo cấu trúc tương tự app hiện tại: pages, services, widgets, theme
- Tích hợp backend API mới (xem bước 4)

### Bước 4: Tạo backend API mới
- Tạo thư mục `api-advanced/` với file `lingoflow_advanced.js`
- Tái sử dụng cấu trúc từ `api/lingoflow.js` nhưng chỉ cho phép 5 loại từ: `collocation`, `grammar`, `phrasal_verb`, `idiom`, `interjection`
- Tạo schema database mới: `vocabulary_words_advanced`, `vocabulary_lists_advanced`, `users_advanced` (hoặc dùng chung database nhưng tách rõ ràng)
- Triển khai trên Vercel hoặc hosting riêng

### Bước 5: Import dữ liệu vào app mới
- Tạo script `scripts/import_to_advanced_app.js`
- Đọc file JSON export từ bước 1
- Insert vào database của app mới
- Validate số lượng record khớp

## Dữ liệu cần chuyển (ước tính)
- collocation: 6 từ
- grammar: 12 từ
- phrasal_verb: 3 từ
- idiom: 1-2 từ
- interjection: 1 từ
- **Tổng: ~23 từ**

## Rủi ro & Lưu ý
- Backup database trước khi chạy script xóa
- Kiểm tra kỹ điều kiện WHERE để không xóa nhầm từ loại khác
- App mới cần có thể chạy song song với app hiện tại (không ảnh hưởng lẫn nhau)
- Nếu muốn dùng chung backend, cần thêm filter theo `app_source` hoặc tách schema rõ ràng

## Đầu ra mong đợi
1. File JSON export đầy đủ dữ liệu
2. App hiện tại còn 817 từ (810 từ đơn + 7 cụm từ còn lại của verb/adjective/adverb)
3. App mới có đầy đủ 23 từ từ 5 loại đã chuyển
4. Cả 2 app hoạt động độc lập
