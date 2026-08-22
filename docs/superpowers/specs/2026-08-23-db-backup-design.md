# DB Backup Hàng ngày — Design Spec

**Ngày:** 2026-08-23
**Trạng thái:** Đã duyệt

## Mục tiêu

Tự động sao lưu toàn bộ dữ liệu Postgres (từ vựng, tiến độ SRS, users) hằng ngày vào một repo GitHub PRIVATE riêng để khôi phục khi sự cố.

## Ràng buộc phát hiện khi khảo sát

- Repo chính `VietNguyenHoang16/LingoFlow` là **PUBLIC** → không được chứa file dump (có SĐT — PII)
- `DATABASE_URL` nằm trong env của Vercel project `vocab` (encrypted)
- `gh` CLI chưa cài trên máy — mọi thao tác qua git push + GitHub web UI

## Kiến trúc

```
GitHub Actions (cron 30 18 * * * UTC = 01:30 sáng VN)
   └─ pg_dump "$DATABASE_URL" -Fc (custom format, đã nén)
        └─ clone repo private bằng BACKUP_REPO_TOKEN (PAT)
             └─ backups/YYYY-MM-DD.dump → commit → push
```

## Thành phần

| Phần | Vị trí | Ghi chú |
|---|---|---|
| Workflow | `.github/workflows/db-backup.yml` (repo public) | Cron + `workflow_dispatch` chạy tay |
| Repo lưu backup | `VietNguyenHoang16/lingoflow-backups` (**private**, user tạo tay) | Chứa `backups/<date>.dump`, lịch sử git = retention |
| Secret 1 | `DATABASE_URL` | Copy từ Vercel → GitHub secrets (mã hóa, che trong log) |
| Secret 2 | `BACKUP_REPO_TOKEN` | PAT tối thiểu quyền Contents RW trên repo private |
| Tài liệu restore | `docs/restore-backup.md` | Lệnh `pg_restore` từng bước |

## Bảo mật

- File dump chỉ tồn tại trong repo private; repo public chỉ thấy workflow yml
- GitHub mã hóa secrets kể cả ở repo public; log runner tự che giá trị secret

## Verify

User chạy workflow tay qua tab Actions (`workflow_dispatch`) → kiểm tra repo private xuất hiện `backups/<hôm-nay>.dump`.

## Lệch đã biết (chấp nhận)

Cron GitHub có thể trễ vài phút–vài giờ trong giờ cao điểm — chấp nhận với backup hàng ngày.
