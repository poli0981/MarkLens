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
}
