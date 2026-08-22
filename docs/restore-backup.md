# Khôi phục dữ liệu từ backup

Backup tự động chạy 01:30 sáng (giờ VN) hằng ngày, lưu vào repo private
`VietNguyenHoang16/lingoflow-backups`, thư mục `backups/`, tên file
`YYYY-MM-DD.dump` (pg_dump custom format, đã nén).

## Khi cần khôi phục

### Bước 1: Tải file dump

Vào repo `lingoflow-backups` → thư mục `backups/` → chọn ngày muốn khôi phục
→ Download (hoặc dùng git clone trên máy có quyền truy cập).

### Bước 2: Cài postgres-client (nếu chưa có)

```bash
# Ubuntu/WSL
sudo apt-get update && sudo apt-get install -y postgresql-client

# macOS
brew install libpq && brew link --force libpq

# Windows: dùng WSL hoặc tải PostgreSQL installer từ postgresql.org
```

### Bước 3: Khôi phục

Lấy connection string từ Vercel dashboard → project `vocab` → Settings →
Environment Variables → `DATABASE_URL`, rồi:

```bash
export DATABASE_URL="postgresql://...neon.tech/db?sslmode=require"

pg_restore "$DATABASE_URL" \
  --clean --if-exists --no-owner \
  backups/2026-08-23.dump
```

Giải thích cờ:
- `--clean --if-exists`: xóa bảng cũ trước khi ghi đè (restore toàn bộ về
  đúng trạng thái ngày backup)
- `--no-owner`: tránh lỗi quyền owner khi user restore khác user gốc

### Bước 4: Kiểm tra

```bash
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM vocabulary_words;"
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM users;"
```

Số dòng phải khớp với thời điểm backup. Sau đó mở app, đăng nhập và kiểm tra
danh sách từ + tiến độ ôn tập.

## Lưu ý

- Restore **ghi đè** dữ liệu hiện tại — chỉ làm khi thật sự cần
- Muốn giữ dữ liệu hiện tại trước khi restore, chạy thêm một lần dump:
  `pg_dump "$DATABASE_URL" -Fc -f before-restore.dump`
