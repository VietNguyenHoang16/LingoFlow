# Tính Năng Tìm Kiếm & Chỉnh Sửa Từ Nhanh

> **For Hermes:** Dùng subagent-driven-development để thực hiện kế hoạch này từng bước nhỏ.

**Mục tiêu:** Cho phép người dùng tìm kiếm từ vựng và chỉnh sửa ngay trong bố cục tìm kiếm (SearchBottomSheet), thay vì mở dialog riêng.

**Kiến trúc:**
- Giữ nguyên giao diện tìm kiếm hiện có trong `SearchBottomSheet`
- Thêm nút "Chỉnh sửa" cho mỗi kết quả tìm kiếm
- Khi nhấn chỉnh sửa → mở `EditWordSheet` với dữ liệu hiện có → lưu thay đổi → cập nhật UI ngay
- Backend API đã có sẵn: `updateVocabularyWord` trong DatabaseService

**Tech Stack:** Flutter, Riverpod (nếu có), HTTP API

---

## Phân Tích Hiện Trạng

### Các file liên quan:

1. **`lib/pages/dashboard_page.dart`** (623 lines)
   - Lớp `SearchBottomSheet` (dòng 461-623): Giao diện tìm kiếm hiện có
   - Sử dụng `DatabaseService.searchWord()` để lấy kết quả
   - Hiển thị từ, nghĩa, loại từ, thể loại

2. **`lib/services/database_service_web.dart`** (dòng 375-378)
   - Hàm `searchWord(userId, query)` - trả về danh sách từ

3. **`lib/services/database_service_web.dart`** (dòng 301-319)
   - Hàm `updateVocabularyWord()` - cập nhật từ (đã có)

4. **`lib/widgets/edit_word_sheet.dart`** (308 lines)
   - Hàm `showEditWordSheet()` - dialog chỉnh sửa từ
   - Được sử dụng trong `vocabulary_set_page.dart`

5. **`lib/services/database_service_web.dart`** (dòng 380-383)
   - Cần thêm hàm `updateVocabularyWord` được export

### Các thay đổi cần thiết:

1. Thêm hàm `updateVocabularyWord` vào DatabaseService
2. Sửa `SearchBottomSheet` để thêm nút chỉnh sửa
3. Xử lý save/cancel khi chỉnh sửa

---

## Kế Hoạch Thực Hiện

### Task 1: Thêm hàm updateVocabularyWord vào DatabaseService

**Objective:** Đảm bảo DatabaseService có hàm cập nhật từ vựng

**Files:**
- Modify: `lib/services/database_service_web.dart:301-319`

**Step 1: Kiểm tra hàm đã có sẵn**

File đã có hàm `updateVocabularyWord` ở dòng 301-319. Cần xác nhận API endpoint hoạt động và thêm vào export nếu cần.

**Step 2: Xác thực API endpoint**

Chạy thử hoặc kiểm tra API backend tại `https://vocab-virid.vercel.app/api/lingoflow`

---

### Task 2: Sửa SearchBottomSheet - Thêm nút chỉnh sửa

**Objective:** Thêm khả năng chỉnh sửa từ trong SearchBottomSheet

**Files:**
- Modify: `lib/pages/dashboard_page.dart` (từ 573-616)

**Step 1: Thêm Icon chỉnh sửa vào mỗi kết quả tìm kiếm**

Thêm một nút icon bên phải trong mỗi item của ListView.

**Step 2: Implement hàm _editWord**

Thêm hàm xử lý khi người dùng nhấn chỉnh sửa:
- Lấy word hiện tại
- Gọi `showEditWordSheet`
- Lưu ý tượng cập nhật

**Step 3: Cập nhật UI sau khi chỉnh sửa**

Sau khi lưu thành công:
- Cập nhật `_searchResults` tại vị trí tương ứng
- Hiển thị thông báo thành công

---

### Task 3: Thêm hàm xóa từ trong SearchBottomSheet

**Objective:** Thêm khả năng xóa từ trong SearchBottomSheet

**Files:**
- Modify: `lib/pages/dashboard_page.dart`

**Step 1: Thêm Icon xóa vào mỗi kết quả tìm kiếm**

**Step 2: Implement hàm _deleteWord**

- Xác nhận xóa
- Gọi `DatabaseService.deleteVocabularyWord`
- Cập nhật danh sách

---

## Cách Kiểm Tra

1. **Build thử:** `flutter build apk --debug` hoặc mở trong IDE
2. **Kiểm tra chức năng:**
   - Mở app → nhấn nút tìm kiếm
   - Nhập từ → xem kết quả
   - Nhấn icon chỉnh sửa → Dialog mở ra
   - Thay đổi nghĩa → Lưu → Kết quả cập nhật ngay
3. **Kiểm tra lỗi:** Xử lý trường hợp không có kết nối mạng

---

## Rủi Ro & Câu Hỏi Mở

1. **Rủi ro:** Khi cập nhật từ, dữ liệu cache có cần refresh không?
2. **Câu hỏi:** Cần thêm X / Nhóm xóa hàng loạt không? (Hiện chỉ cần chỉnh sửa nhanh)

---

## Tệp Tin Sẽ Thay Đổi

| File | Thay đổi |
|------|----------|
| `lib/pages/dashboard_page.dart` | Thêm icon chỉnh sửa, xóa; bổ sung logic xử lý |
| `lib/services/database_service_web.dart` | Kiểm tra/cập nhật hàm updateVocabularyWord |

---

## Lịch Trình Dự Kiến

1. Task 1: 15 phút (kiểm tra API)
2. Task 2: 30 phút (implement chỉnh sửa)
3. Task 3: 15 phút (implement xóa)
4. Test & Verify: 15 phút

**Tổng: ~1 giờ**