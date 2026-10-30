# Checklist phát hành — LingoFlow (bắt buộc cho mọi agent)

Mục đích: **không bao giờ** báo "đã xong" khi web / API / APK chưa thực sự nhận thay đổi.
Mỗi bước dưới đây phải có **bằng chứng** (log, kiểm tra file production, hoặc hash).

## 0. Bối cảnh repo

| Thành phần | Ở đâu | Ghi chú |
|---|---|---|
| App Flutter (Android + Web) | `lib/` | Web dùng chung code Dart với APK |
| Web shell / PWA | `web/` (`index.html`, `pwa.js`, `manifest.json`) | Được Flutter copy vào `build/web` |
| API serverless | `api/lingoflow.js` (+ `api/tts.js`, `api/examples.js`) | Deploy cùng Vercel |
| Vercel project | `vocab` — production: **https://vocab-virid.vercel.app** | **KHÔNG auto-deploy từ GitHub** |
| APK phát hành | `apk/vocab-arm64-release.apk` + `apk/README.md` | Link tải raw GitHub ở README |
| GitHub | `VietNguyenHoang16/LingoFlow`, nhánh `main` | Push trực tiếp `main` |

Điểm hay gây "code mới nhưng app vẫn cũ":
1. **Vercel không nối GitHub** → `git push` không làm web đổi. Phải chạy `vercel --prod`.
2. **PWA/service worker** giữ cache `main.dart.js` cũ trên máy người dùng.
3. **APK** phải build lại; sửa `lib/` không tự có trong APK đang cài.
4. **API** (`api/`) chỉ đổi sau khi deploy; client mới gọi action mới mà server cũ thì lỗi.

## 1. Chất lượng (trước khi commit)

```powershell
flutter test
flutter analyze lib test
```

- [ ] `flutter test` pass **toàn bộ** (không skip, không giảm số test).
- [ ] `flutter analyze` không thêm lỗi mới. Baseline hiện tại: 6 issue mức `info` ở
      `vocabulary_set_page.dart`, `review_word_utils.dart`, `word_type_badge_test.dart`.
- [ ] Bug fix phải có test **fail trên code cũ** trước khi fix (Prove-It), hoặc nêu rõ
      lý do không thể test được (ví dụ hành vi chỉ có trên iOS Safari).

## 2. Commit & push GitHub

```powershell
git add <các file liên quan>
git commit -m "type(scope): mô tả ngắn" -m "vì sao + ảnh hưởng + test"
git push origin main
```

- [ ] Chỉ commit file liên quan (không commit `_out*.txt`, `_diag*.ps1`, `test-results/`…).
- [ ] Log push có dạng `abc1234..def5678  main -> main` → dán vào báo cáo.

## 3. Deploy Vercel (web + API)

```powershell
vercel --prod --yes
```

- [ ] Log có `Production: https://vocab-...vercel.app` và `Aliased: https://vocab-virid.vercel.app`.
- [ ] Deploy này áp dụng cho **cả** `api/lingoflow.js` và `web/` (pwa.js, manifest…).

## 4. Bằng chứng web đã cập nhật (bắt buộc)

Chọn một **chuỗi duy nhất** do thay đổi của bạn tạo ra (tên action API, key mới, câu chữ UI mới…)
rồi kiểm tra file production:

```powershell
$js = Invoke-WebRequest -Uri 'https://vocab-virid.vercel.app/main.dart.js' -UseBasicParsing
$js.Content -match 'filterExistingWordsDetailed'   # ví dụ: phải trả True
```

Nếu sửa `web/` (pwa.js, index.html, manifest.json): tải **đúng file đó** từ domain production
và kiểm tra nội dung mới:

```powershell
(Invoke-WebRequest -Uri 'https://vocab-virid.vercel.app/pwa.js' -UseBasicParsing).Content -match '__tts'
```

- [ ] Đã kiểm tra và dán kết quả (`True`) vào báo cáo.
- [ ] Nếu `False`: DỪNG, kiểm tra lại deploy/commit — **không** báo xong.

## 5. Nếu sửa `api/lingoflow.js`

- [ ] Action mới chạy thật (không chỉ compile):
  - Test SQL bằng **schema tạm + ROLLBACK** trên Postgres (xem mẫu trong lịch sử: tạo schema
    `tts_verify`, tạo bảng tối thiểu, chạy đúng câu SQL với `$1`, `$2`, rồi `ROLLBACK`), hoặc
  - Gọi endpoint với token hợp lệ và kiểm tra payload trả về.
- [ ] Client **luôn có fallback** khi action mới lỗi (API cũ / mạng chập chờn) để không mất
      chức năng hiện có.
- [ ] Lưu ý: `DATABASE_URL` trên Vercel là biến *sensitive* — `vercel env pull` trả rỗng, và
      `.env.production.local` trong máy có thể trỏ tới DB rỗng/cũ. Đừng kết luận "DB sai"
      chỉ vì file local đó.

## 6. Nếu thay đổi ảnh hưởng app Android (`lib/`)

```powershell
flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info=build/symbols
Copy-Item build\app\outputs\flutter-apk\app-release.apk apk\vocab-arm64-release.apk -Force
(Get-Item apk\vocab-arm64-release.apk).Length
(Get-FileHash apk\vocab-arm64-release.apk -Algorithm SHA256).Hash
```

- [ ] Cập nhật `apk/README.md`: dung lượng, SHA256, ngày build, mục changelog mới nhất
      (đánh số lại danh sách nếu cần), giữ link tải raw.
- [ ] Commit `chore(apk): …` + push.
- [ ] Bản Android **không** cần build lại nếu thay đổi chỉ ở `web/` hoặc `api/` hoặc `docs/`.

## 7. Verify link tải APK (bắt buộc)

```powershell
$p = "$env:TEMP\verify.apk"
Invoke-WebRequest -Uri 'https://github.com/VietNguyenHoang16/LingoFlow/raw/main/apk/vocab-arm64-release.apk' -OutFile $p -UseBasicParsing
(Get-FileHash $p -Algorithm SHA256).Hash   # phải trùng hash file vừa build
```

- [ ] Hash khớp. Nếu lệch: chờ GitHub/CDN vài giây rồi tải lại, hoặc kiểm tra đã push đúng chưa.

## 8. Báo cáo cuối (mẫu)

```
- Commit:  fd9fa11 (fix) + 6fcccb8 (apk) → đã push main
- Vercel:  https://vocab-virid.vercel.app (200) — deployment <url>
- Web:     main.dart.js trên production chứa "<chuỗi duy nhất>" → True
- APK:     <bytes> bytes, SHA256 <hash>, link tải …/apk/vocab-arm64-release.apk (hash khớp)
- Nhắc người dùng: PWA iPad tắt hẳn app 2 lần (hoặc xoá icon → Thêm vào MH chính lại);
  Android cài đè bằng link APK mới.
```

## 9. Nguyên tắc

- Không tuyên bố "đã cập nhật" khi thiếu (a) log deploy, (b) kiểm tra file production,
  (c) hash APK khớp link tải.
- Nếu bước nào fail: nói rõ **fail ở đâu** và **phần nào của app chưa được cập nhật**
  (web / API / APK), kèm cách xử lý tiếp.
- Thay đổi chỉ ở `docs/` hoặc README: chỉ cần commit + push, **không** deploy Vercel,
  **không** build APK.
