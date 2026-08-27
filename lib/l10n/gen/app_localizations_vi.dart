// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'MarkLens';

  @override
  String get menuFile => '&Tệp';

  @override
  String get menuView => '&Hiển thị';

  @override
  String get menuHelp => 'Trợ &giúp';

  @override
  String get menuOpenFiles => 'Mở tệp…';

  @override
  String get menuOpenFolder => 'Mở thư mục…';

  @override
  String get readerCopyCodeTooltip => 'Sao chép mã';

  @override
  String get sidebarMissingBadge => 'không còn';

  @override
  String get readerRawHtmlTitle => 'HTML thô (không kết xuất)';

  @override
  String readerMdxImportsHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'đã ẩn $count import',
    );
    return 'MDX · $_temp0';
  }

  @override
  String get emptyStateDropHint =>
      'Kéo thả một tệp Markdown vào đây, hoặc mở một tệp để bắt đầu.';

  @override
  String get menuOpenRecent => 'Mở gần đây';

  @override
  String get menuOpenRecentEmpty => 'Chưa có tài liệu nào';

  @override
  String get menuReload => 'Tải lại';

  @override
  String get menuCopyDocument => 'Chép toàn bộ tài liệu';

  @override
  String get menuCloseTab => 'Đóng thẻ';

  @override
  String get menuCloseAll => 'Đóng tất cả';

  @override
  String get menuSettings => 'Cài đặt…';

  @override
  String get menuExit => 'Thoát';

  @override
  String get menuToggleSidebar => 'Bật/tắt thanh bên';

  @override
  String get menuToggleOutline => 'Bật/tắt dàn ý';

  @override
  String get menuZoomIn => 'Phóng to';

  @override
  String get menuZoomOut => 'Thu nhỏ';

  @override
  String get menuZoomReset => 'Về cỡ gốc';

  @override
  String get menuTheme => 'Giao diện';

  @override
  String get menuThemeSystem => 'Theo hệ thống';

  @override
  String get menuThemeLight => 'Sáng';

  @override
  String get menuThemeDark => 'Tối';

  @override
  String get menuFullScreen => 'Toàn màn hình';

  @override
  String get menuCheckUpdates => 'Kiểm tra cập nhật…';

  @override
  String get menuThirdPartyLicenses => 'Giấy phép bên thứ ba';

  @override
  String get menuExportLog => 'Xuất nhật ký chẩn đoán…';

  @override
  String get menuAbout => 'Giới thiệu MarkLens';

  @override
  String menuNotImplemented(String item) {
    return '$item chưa được nối';
  }

  @override
  String get readerNoticeInvalidUtf8 =>
      'Tệp này không phải UTF-8 hợp lệ. Một số ký tự đã được thay thế.';

  @override
  String get readerNoticeFrontMatterUnparsed =>
      'Phần front matter không phải các dòng khóa/giá trị đơn giản nên được hiển thị nguyên văn.';

  @override
  String get readerNoticeMdxBailOut =>
      'Một số đoạn MDX không thể diễn giải và được hiển thị dưới dạng mã nguồn.';

  @override
  String get readerNoticePlainTextFallback =>
      'Không thể phân tích tài liệu này nên nó được hiển thị dưới dạng văn bản thuần.';

  @override
  String get readerNoticeLargeDocument =>
      'Đây là tài liệu lớn. Một số tính năng có thể chậm hơn bình thường.';

  @override
  String get readerCopied => 'Đã sao chép';

  @override
  String get readerExpand => 'Mở rộng';

  @override
  String get readerCollapse => 'Thu gọn';

  @override
  String get readerFrontMatterTitle => 'Front matter';

  @override
  String get readerNoticeDismiss => 'Đóng';

  @override
  String readerNoticeMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Thêm $count thông báo',
    );
    return '$_temp0';
  }

  @override
  String readerOpenFailed(String name) {
    return 'Không mở được $name.';
  }

  @override
  String get sidebarEmpty => 'Chưa mở tài liệu nào.';

  @override
  String get sidebarPin => 'Ghim';

  @override
  String get sidebarUnpin => 'Bỏ ghim';

  @override
  String openFolderCapTitle(int count) {
    return 'Thư mục đó có hơn $count tài liệu';
  }

  @override
  String openFolderCapBody(int count) {
    return 'MarkLens có thể mở $count tài liệu đầu tiên. Mở hết sẽ làm sidebar và phiên làm việc chậm hơn mức đáng.';
  }

  @override
  String openFolderCapAccept(int count) {
    return 'Mở $count đầu tiên';
  }

  @override
  String get commonCancel => 'Hủy';

  @override
  String get sessionNotRestored =>
      'Không đọc được phiên làm việc trước. Nó đã được giữ lại bên cạnh một phiên mới.';

  @override
  String statusBarPosition(int percent) {
    return '$percent%';
  }

  @override
  String statusBarWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count từ',
    );
    return '$_temp0';
  }

  @override
  String statusBarNotices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count thông báo',
    );
    return '$_temp0';
  }

  @override
  String get statusBarNoDocument => 'Không có tài liệu nào đang mở';

  @override
  String get outlinePanelTitle => 'Dàn ý';

  @override
  String get settingsNotRestored =>
      'Không đọc được cài đặt của bạn. Chúng đã được giữ lại bên cạnh các giá trị mặc định mới.';

  @override
  String get outlineEmpty => 'Tài liệu này không có tiêu đề nào.';

  @override
  String get findPlaceholder => 'Tìm trong tài liệu';

  @override
  String findMatchCounter(int current, int total) {
    return '$current/$total';
  }

  @override
  String get findNoResults => 'Không có kết quả';

  @override
  String get findCaseSensitive => 'Phân biệt hoa thường';

  @override
  String get findNext => 'Kết quả tiếp theo';

  @override
  String get findPrevious => 'Kết quả trước';

  @override
  String get findClose => 'Đóng tìm kiếm';
}
