# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: e2e\two-review-buttons.spec.js >> Dashboard hiển thị 2 nút ôn tập với số đếm đúng
- Location: e2e\two-review-buttons.spec.js:27:1

# Error details

```
Test timeout of 120000ms exceeded.
```

```
Error: expect(locator).toBeVisible() failed

Locator: getByText('Time to review!')
Expected: visible
Error: element(s) not found

Call log:
  - Expect "toBeVisible" with timeout 60000ms
  - waiting for getByText('Time to review!')

```

```yaml
- button "Enable accessibility"
```

# Test source

```ts
  1  | // E2E: 2 nút ôn tập trên Dashboard — chạy trên build production đã deploy.
  2  | // Chạy: npx playwright test e2e/two-review-buttons.spec.js
  3  | const { test, expect } = require('@playwright/test');
  4  | 
  5  | const BASE = process.env.E2E_BASE_URL || 'https://vocab-virid.vercel.app';
  6  | const API = `${BASE}/api/lingoflow`;
  7  | 
  8  | // Đăng nhập phone ngẫu nhiên -> seed 1 từ noun + 1 từ grammar qua API -> mở app.
  9  | // App lưu session trong localStorage (app tự đăng nhập lại theo token đã lưu).
  10 | // Vì app không hỗ trợ deep-link login từ test, test này xác minh UI bằng cách
  11 | // đăng nhập thủ công trong trang: nhập số phone và submit.
  12 | 
  13 | async function api(action, data, token) {
  14 |   const res = await fetch(API, {
  15 |     method: 'POST',
  16 |     headers: {
  17 |       'Content-Type': 'application/json',
  18 |       ...(token ? { Authorization: `Bearer ${token}` } : {}),
  19 |     },
  20 |     body: JSON.stringify({ action, data }),
  21 |   });
  22 |   const json = await res.json();
  23 |   if (json.error) throw new Error(`${action}: ${json.error}`);
  24 |   return json.data;
  25 | }
  26 | 
  27 | test('Dashboard hiển thị 2 nút ôn tập với số đếm đúng', async ({ page }) => {
  28 |   test.setTimeout(120_000);
  29 | 
  30 |   const phone = `e2e${Date.now()}`;
  31 |   const ok = await api('registerUser', { phoneNumber: phone });
  32 |   expect(ok).toBe(true);
  33 |   const login = await api('loginUser', { phoneNumber: phone });
  34 |   const token = login.token;
  35 |   const userId = login.userId;
  36 | 
  37 |   // Seed: 1 từ noun, 1 cấu trúc grammar
  38 |   await api('addVocabularyWord', { userId, category: 'noun', word: `tree${Date.now()}`, meaning: 'cay', wordType: 'noun' }, token);
  39 |   await api('addVocabularyWord', { userId, category: 'grammar', word: `Used to + V${Date.now()}`, meaning: 'da tung', wordType: 'grammar' }, token);
  40 | 
  41 |   // Đăng nhập trong app (nhập phone)
  42 |   await page.goto(BASE, { waitUntil: 'domcontentloaded' });
  43 |   await expect(page.locator('flutter-view').first()).toBeAttached({ timeout: 30_000 });
  44 | 
  45 |   // Flutter web render canvas — tương tác qua Accessibility tree (enable a11y)
  46 |   // Không thể click canvas trực tiếp theo text, dùng phím: nhập phone vào field focus đầu tiên.
  47 |   // App login: TextField phone + nút đăng nhập. Thử nhập bằng keyboard.
  48 |   await page.keyboard.type(phone, { delay: 30 });
  49 |   await page.keyboard.press('Enter');
  50 | 
  51 |   // Chờ dashboard tải (banner 2 nút xuất hiện trong semantic tree)
> 52 |   await expect(page.getByText('Time to review!')).toBeVisible({ timeout: 60_000 });
     |                                                   ^ Error: expect(locator).toBeVisible() failed
  53 |   await expect(page.getByText('Grammar time!')).toBeVisible();
  54 |   await expect(page.getByText(/1 words due/)).toBeVisible();
  55 |   await expect(page.getByText(/1 structures due/)).toBeVisible();
  56 | 
  57 |   // Ảnh chụp đối chiếu
  58 |   await page.screenshot({ path: 'e2e/dashboard-two-buttons.png', fullPage: false });
  59 | });
  60 | 
```