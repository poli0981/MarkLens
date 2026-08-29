---
title: Ghi chú tiếng Việt
tags: [tiếng-việt, kiểm-thử]
---

# Trình xem Markdown chỉ đọc

MarkLens mở tệp `.md` và `.mdx` rồi hiển thị chúng — không sửa, không ghi đè,
không đụng vào tài liệu của bạn. Đây là trang dùng để kiểm tra việc dựng chữ
tiếng Việt: dấu thanh chồng lên dấu phụ, và những chữ như **tuyệt**, *quyển*,
`nghiêng`, ưu tiên, đường dẫn, khuyến nghị.

## Dấu và chữ ghép

Một số tổ hợp dễ vỡ khi phông chữ thiếu glyph dựng sẵn:

- ằ ẳ ẵ ặ — chữ ă với bốn dấu
- ề ể ễ ệ — chữ ê
- ồ ổ ỗ ộ — chữ ô
- ờ ở ỡ ợ — chữ ơ
- ừ ử ữ ự — chữ ư
- ỳ ỷ ỹ ỵ — chữ y

Đồng Việt Nam viết là ₫ hoặc VNĐ. Dấu ngoặc kép kiểu Việt là “như thế này”.

## Bảng

| Phím tắt | Việc nó làm | Ghi chú |
|---|---|---|
| `Ctrl+O` | Mở tệp | Hộp thoại của hệ điều hành |
| `Ctrl+P` | Chuyển nhanh | Tìm mờ trên tệp đang mở và gần đây |
| `Ctrl+Shift+F` | Tìm trong nhiều tệp | Chạy trong isolate riêng |
| `F11` | Toàn màn hình | Ẩn thanh trình đơn |

## Khối mã

```dart
/// Đọc tệp và trả về nội dung đã giải mã.
///
/// Không bao giờ ghi: tài liệu của người dùng là bất biến đối với MarkLens.
Future<String> đọcTàiLiệu(String đườngDẫn) async {
  final tệp = File(đườngDẫn);
  return tệp.readAsString(); // UTF-8, có xử lý BOM
}
```

> Một trích dẫn để kiểm tra khoảng cách dòng khi chữ có nhiều dấu phụ chồng
> lên nhau — đây là chỗ chiều cao dòng dễ nhảy nhất.

1. Mở thư mục
2. Chọn tệp ở thanh bên
3. Đọc

- [x] Dựng chữ tiếng Việt
- [ ] Kiểm tra trên máy Ubuntu sạch
