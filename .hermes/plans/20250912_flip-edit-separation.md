# Sửa Lỗi Flip Từ - Tách Rời Chức Năng Flip và Chỉnh Sửa

> **For Hermes:** Dùng subagent-driven-development để thực hiện kế hoạch này từng bước nhỏ.

**Mục tiêu:** Khi người dùng nhấn vào từ để lật qua lại (flip), chỉ flip. Thêm nút chỉnh sửa riêng biệt.

---

## Phân Tích Nguyên Nhân

### 1. recent_page.dart
- `onTap` → **chỉ flip** (dòng 670-677) - ✓ Đúng
- `onLongPress` → mở `_showWordOptions` (dòng 678-682) - OK
- **Chưa có icon chỉnh sửa/xóa riêng** trên card

### 2. category_page.dart
- `onTap` → **chỉ flip** (dòng 496-502) - ✓ Đúng
- `onLongPress` → `_editWord(word)` (dòng 504) - OK
- `_buildWordCardBack` có hành vi chỉnh sửa nhanh khi nhấn vào "Nghĩa" - Gây nhầm lẫn
- **Chưa có icon chỉnh sửa/xóa riêng** trên card

### 3. vocabulary_set_page.dart
- `onTap` → flip hoặc chọn từ (dòng 1763-1765) - ✓ Đúng
- `onLongPress` → `_showWordOptions` (dòng 1766-1772) - OK

### Vấn đề chính:
1. **Không có icon chỉnh sửa riêng** trên card → người dùng không biết cách chỉnh sửa nhanh
2. **Trong category_page.dart**, phần sau card (`_buildWordCardBack`) có `GestureDetector(onTap: _quickEditMeaning)` trên phần "Nghĩa" → người nhấn nhầm vào đây sẽ chỉnh sửa

---

## Kế Hoạch Thực Hiện

### Task 1: Thêm icon chỉnh sửa và xóa vào category_page.dart

**Objective:** Thêm 2 icon riêng biệt vào góc card

**Files:**
- Modify: `lib/pages/category_page.dart`

**Step 1: Sửa `_buildWordCard`**

Thêm vào sau `Container` chính (sử dụng `Stack`):
```dart
return GestureDetector(
  onTap: () => flip,
  onLongPress: () => _editWord(word),
  child: Stack(
    children: [
      Container(...),
      // Icon chỉnh sửa + xóa ở góc trên phải
      Positioned(
        top: 8,
        right: 8,
        child: Row(
          children: [
            IconButton(icon: Icon(Icons.edit), onPressed: () => _editWord(word)),
            IconButton(icon: Icon(Icons.delete), onPressed: () => _deleteWord(wordId)),
          ],
        ),
      ),
    ],
  ),
);
```

---

### Task 2: Thêm icon chỉnh sửa và xóa vào recent_page.dart

**Objective:** Tương tự category_page.dart

**Files:**
- Modify: `lib/pages/recent_page.dart`

---

### Task 3: Thêm icon chỉnh sửa và xóa vào vocabulary_set_page.dart

**Objective:** Tương tự

**Files:**
- Modify: `lib/pages/vocabulary_set_page.dart`

---

### Task 4: Xóa hoặc giữ nguyên `_quickEditMeaning` trong category_page.dart

**Objective:** Quyết định cách xử lý flip card back
- **Giữ lại** nhưng thêm nhận dạng rõ ràng hơn (icon edit riêng)
- Hoặc **di chuyển** chức năng chỉnh sửa nhanh sang icon riêng

---

## Kiểm Tra

1. Chạy `flutter analyze` - không lỗi
2. Build APK: `flutter build apk --debug`
3. Test:
   - Nhấn vào card từ → chỉ flip
   - Nhấn icon chỉnh sửa → mở dialog chỉnh sửa
   - Nhấn icon xóa → xóa từ

---

## Files Sẽ Thay Đổi

| File | Thay đổi |
|------|----------|
| `lib/pages/category_page.dart` | Thêm icon edit/delete, sửa `_buildWordCard` |
| `lib/pages/recent_page.dart` | Thêm icon edit/delete |
| `lib/pages/vocabulary_set_page.dart` | Thêm icon edit/delete |