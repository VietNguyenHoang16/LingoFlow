// E2E: 2 nút ôn tập trên Dashboard — chạy trên build production đã deploy.
// Chạy: npx playwright test e2e/two-review-buttons.spec.js
const { test, expect } = require('@playwright/test');

const BASE = process.env.E2E_BASE_URL || 'https://vocab-virid.vercel.app';
const API = `${BASE}/api/lingoflow`;

// Đăng nhập phone ngẫu nhiên -> seed 1 từ noun + 1 từ grammar qua API -> mở app.
// App lưu session trong localStorage (app tự đăng nhập lại theo token đã lưu).
// Vì app không hỗ trợ deep-link login từ test, test này xác minh UI bằng cách
// đăng nhập thủ công trong trang: nhập số phone và submit.

async function api(action, data, token) {
  const res = await fetch(API, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({ action, data }),
  });
  const json = await res.json();
  if (json.error) throw new Error(`${action}: ${json.error}`);
  return json.data;
}

test('Dashboard hiển thị 2 nút ôn tập với số đếm đúng', async ({ page }) => {
  test.setTimeout(120_000);

  const phone = `e2e${Date.now()}`;
  const ok = await api('registerUser', { phoneNumber: phone });
  expect(ok).toBe(true);
  const login = await api('loginUser', { phoneNumber: phone });
  const token = login.token;
  const userId = login.userId;

  // Seed: 1 từ noun, 1 cấu trúc grammar
  await api('addVocabularyWord', { userId, category: 'noun', word: `tree${Date.now()}`, meaning: 'cay', wordType: 'noun' }, token);
  await api('addVocabularyWord', { userId, category: 'grammar', word: `Used to + V${Date.now()}`, meaning: 'da tung', wordType: 'grammar' }, token);

  // Đăng nhập trong app (nhập phone)
  await page.goto(BASE, { waitUntil: 'domcontentloaded' });
  await expect(page.locator('flutter-view').first()).toBeAttached({ timeout: 30_000 });

  // Flutter web render canvas — tương tác qua Accessibility tree (enable a11y)
  // Không thể click canvas trực tiếp theo text, dùng phím: nhập phone vào field focus đầu tiên.
  // App login: TextField phone + nút đăng nhập. Thử nhập bằng keyboard.
  await page.keyboard.type(phone, { delay: 30 });
  await page.keyboard.press('Enter');

  // Chờ dashboard tải (banner 2 nút xuất hiện trong semantic tree)
  await expect(page.getByText('Time to review!')).toBeVisible({ timeout: 60_000 });
  await expect(page.getByText('Grammar time!')).toBeVisible();
  await expect(page.getByText(/1 words due/)).toBeVisible();
  await expect(page.getByText(/1 structures due/)).toBeVisible();

  // Ảnh chụp đối chiếu
  await page.screenshot({ path: 'e2e/dashboard-two-buttons.png', fullPage: false });
});
