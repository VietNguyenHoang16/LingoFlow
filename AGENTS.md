# AGENTS.md

## Bắt buộc: đồng bộ & báo cáo phát hành (đọc trước khi báo "xong")

Người dùng nhìn app qua **web (PWA) / API / APK**, không nhìn code. Mọi thay đổi phải thực sự
lên các bề mặt đó và chỉ được báo hoàn thành khi có bằng chứng.

- **Vercel KHÔNG auto-deploy từ GitHub** → sau khi push phải chạy `vercel --prod --yes`
  (deploy này áp dụng cho cả `api/` và `web/`).
- **PWA giữ cache** → nhắc người dùng iPad: tắt hẳn app 2 lần, hoặc xoá icon rồi
  "Thêm vào MH chính" lại.
- **Sửa `lib/`** → build lại APK arm64, cập nhật `apk/vocab-arm64-release.apk` +
  `apk/README.md` (dung lượng, SHA256, changelog), commit + push.
- **Bắt buộc kiểm tra**: `main.dart.js` (và `pwa.js` nếu sửa `web/`) tải từ domain production
  phải chứa chuỗi mới của thay đổi; link tải APK phải trả đúng SHA256 vừa build.
- Thiếu bằng chứng (log deploy / kiểm tra production / hash APK) → **không** được nói
  "đã cập nhật"; phải nói rõ phần nào chưa lên (web / API / APK).

👉 Chi tiết đầy đủ — lệnh, checklist từng bước, mẫu báo cáo: [docs/deploy-checklist.md](docs/deploy-checklist.md)

## OpenCode Skill-Driven Execution

This project uses **skill-driven execution** powered by the `skill` tool and skills located globally at `C:\Users\ASUS\.config\opencode\skills/`.

### Core Rules

- If a task matches a skill, you MUST invoke it via the `skill` tool
- Skills are located at `skills/<skill-name>/SKILL.md` (global path)
- Never implement directly if a skill applies
- Always follow the skill instructions exactly (do not partially apply them)

### Intent → Skill Mapping

Automatically map user intent to skills:

- Feature / new functionality → `spec-driven-development`, then `incremental-implementation`, `test-driven-development`
- Planning / breakdown → `planning-and-task-breakdown`
- Bug / failure / unexpected behavior → `debugging-and-error-recovery`
- Code review → `code-review-and-quality`
- Refactoring / simplification → `code-simplification`
- API or interface design → `api-and-interface-design`
- UI work → `frontend-ui-engineering`
- Security concerns → `security-and-hardening`
- Performance concerns → `performance-optimization`
- Deprecating / migrating → `deprecation-and-migration`
- Writing docs / ADRs → `documentation-and-adrs`
- Adding logs / metrics / alerts → `observability-and-instrumentation`
- Deploying / launching → `shipping-and-launch`
- CI/CD pipelines → `ci-cd-and-automation`
- Committing / branching → `git-workflow-and-versioning`

**Taste/Design mappings:**

- Design landing page / portfolio / premium UI → `design-taste-frontend` (taste-skill)
- Redesign existing website/app → `redesign-existing-projects` (redesign-skill)
- Premium / expensive / agency-quality visual → `high-end-visual-design` (soft-skill)
- Clean editorial / Notion/Linear style → `minimalist-ui` (minimalist-skill)
- Raw / industrial / Swiss typography → `industrial-brutalist-ui` (brutalist-skill)
- Image → analyze → code workflow → `image-to-code` (image-to-code-skill)
- AI output keeps truncating → `full-output-enforcement` (output-skill)
- Generate design images (comps, mobile, brand) → `imagegen-frontend-web`, `imagegen-frontend-mobile`, `brandkit`
- Google Stitch-compatible DESIGN.md → `stitch-design-taste` (stitch-skill)

### Lifecycle Mapping (Implicit Commands)

- DEFINE → `spec-driven-development`
- PLAN → `planning-and-task-breakdown`
- BUILD → `incremental-implementation` + `test-driven-development`
- VERIFY → `debugging-and-error-recovery`
- REVIEW → `code-review-and-quality`
- SHIP → `shipping-and-launch`

### Execution Model

For every request:

1. Determine if any skill applies (even 1% chance)
2. Invoke the appropriate skill using the `skill` tool
3. Follow the skill workflow strictly
4. Only proceed to implementation after required steps (spec, plan, etc.) are complete

### Anti-Rationalization

The following thoughts are incorrect and must be ignored:

- "This is too small for a skill"
- "I can just quickly implement this"
- "I'll gather context first"

Correct behavior:

- Always check for and use skills first
