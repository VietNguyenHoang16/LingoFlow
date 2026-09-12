# Nâng Cấp Chức Năng Ví Dụ - Quản Lý Ví Dụ Từ Vựng

> **For Hermes:** Dùng subagent-driven-development để thực hiện kế hoạch này từng bước nhỏ.

**Mục tiêu:** Tạo giao diện quản lý (xem, sửa, xóa) tất cả ví dụ cho từ vựng trong trang Vocabulary Set.

**Kiến trúc:**
- Mở rộng `fullDetails` format để hỗ trợ nhiều ví dụ nghĩa:
  ```
  noun: [{definition: con chó, example: [Anh có thú cưng}, {example: ...}], example: [...]}
  ```
- Tạo hàm parse/build hỗ trợ nhiều ví dụ
- Thêm `ExampleManagerSheet` - dialog quản lý ví dụ
- Thêm nút "Quản lý ví dụ" ngoài "Thêm ví dụ"

---

## Phân Tích Hiện Trạng

### 1. Dữ liệu hiện tại
- `fullDetails` lưu dưới dạng: `noun: [{definition: ..., example: ...}]`
- Hàm `addExampleToFullDetails` - thêm ví dụ vào definition đầu tiên chưa có ví dụ
- Hàm `extractFirstExample` - lấy ví dụ đầu tiên
- Hàm `parseFullDetails` - parse chuỗi thành list có cấu trúc

### 2. Giao diện hiện tại
- `_showAddExampleSheet` - dialog nhập 1 ví dụ
- Nút "Thêm ví dụ" ở góc card (vocabulary_set_page.dart dòng 1888)

---

## Kế Hoạch Thực Hiện

### Task 1: Mở rộng parser hỗ trợ nhiều ví dụ

**Objective:** Thay đổi định dạng lưu trữ để hỗ trợ nhiều ví dụ

**Files:**
- Modify: `lib/services/word_details_parser.dart`

**Step 1: Sửa `parseFullDetails`**

Thay đổi để parse format ví dụ dưới dạng mảng:
- Trước: `example: "..." ` → sau: `example: [...]`

```dart
// Format mới:
// noun: [{definition: con chó, examples: [vd1, vd2]}, ...]
// noun: [{definition: con chó, example: vd1, examples: [vd1, vd2]}, ...]
```

**Step 2: Thêm hàm `extractAllExamples`**

```dart
List<String> extractAllExamples(String fullDetails) {
  final parsed = parseFullDetails(fullDetails);
  final examples = <String>[];
  for (final posEntry in parsed) {
    final definitions = posEntry['definitions'] as List?;
    for (final def in definitions ?? []) {
      // Lấy cả example đơn + examples mảng
      final ex = def['example'] as String?;
      if (ex?.trim().isNotEmpty ?? false) examples.add(ex!);
      final exs = def['examples'] as List?;
      if (exs != null) {
        for (final e in exs) {
          if (e is String && e.trim().isNotEmpty) examples.add(e);
        }
      }
    }
  }
  return examples;
}
```

---

### Task 2: Thêm hàm quản lý ví dụ

**Objective:** Thêm hàm xóa/sửa ví dụ cụ thể

**Files:**
- Modify: `lib/services/word_details_parser.dart`

**Step 1: `removeExample`**

```dart
String removeExample(String fullDetails, int index) {
  final parsed = parseFullDetails(fullDetails);
  // Tìm ví dụ tại index và xóa
  // Rebuild lại fullDetails
}
```

**Step 2: `updateExample`**

```dart
String updateExample(String fullDetails, int index, String newExample) {
  // Cập nhật ví dụ tại vị trí index
}
```

---

### Task 3: Tạo ExampleManagerSheet

**Objective:** Dialog quản lý tất cả ví dụ

**Files:**
- Create: `lib/widgets/example_manager_sheet.dart`

**Step 1: UI Dialog**
- Hiển thị danh sách ví dụ hiện tại (có dấu số thứ tự)
- Nút xóa mỗi ví dụ
- Nút sửa (double tap hoặc icon)
- Nút thêm ví dụ mới

**Step 2: Logic xử lý**
- Gọi `_db.updateVocabularyWordDetails` để lưu
- Cập nhật UI sau khi lưu

---

### Task 4: Tích hợp vào VocabularySetPage

**Objective:** Thêm nút quản lý ví dụ

**Files:**
- Modify: `lib/pages/vocabulary_set_page.dart`

**Step 1: Thêm nút "Quản lý ví dụ"**

Bên cạnh nút "Thêm ví dụ", thêm nút "Quản lý ví dụ" để mở ExampleManagerSheet.

---

## Cách Kiểm Tra

1. `flutter analyze`
2. `flutter build apk --debug`
3. Test:
   - Mở từ trong Vocabulary Set
   - Nhấn "Quản lý ví dụ"
   - Xem danh sách ví dụ
   - Sửa/xóa ví dụ
   - Thêm ví dụ mới
   - Kiểm tra dữ liệu đồng bộ

---

## Risks

- Phải đảm bảo format mới tương thích với format cũ
- Backend API cần chấp nhận format mới (kiểm tra `addExampleToFullDetails`)

---

## Files Thay Đổi

| File | Thay đổi |
|------|----------|
| `lib/services/word_details_parser.dart` | Thêm hàm `extractAllExamples`, `removeExample`, `updateExample` |
| `lib/widgets/example_manager_sheet.dart` | Tạo mới - Dialog quản lý ví dụ |
| `lib/pages/vocabulary_set_page.dart` | Thêm nút "Quản lý ví dụ" |

---

## Lịch Trình

1. Task 1: 20 phút (cập nhật parser)
2. Task 2: 20 phút (thêm hàm quản lý)
3. Task 3: 30 phút (tạo dialog)
4. Task 4: 15 phút (tích hợp)
5. Test & Verify: 15 phút

**Tổng: ~1.5 giờ**