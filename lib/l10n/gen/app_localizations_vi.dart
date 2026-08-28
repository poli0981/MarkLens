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
  String readerMdxComponentTitle(String name) {
    return '$name (thành phần MDX, không kết xuất)';
  }

  @override
  String readerMdxComponentAttributes(String names) {
    return 'Thuộc tính: $names';
  }

  @override
  String readerLinkUnsupported(String kind) {
    return 'MarkLens không mở liên kết $kind.';
  }

  @override
  String readerLinkMissingTarget(String name) {
    return '$name không còn ở đó nữa.';
  }

  @override
  String readerLinkMissingAnchor(String anchor) {
    return 'Không có tiêu đề nào khớp #$anchor.';
  }

  @override
  String readerLinkLaunchFailed(String host) {
    return 'Không chuyển được $host sang trình duyệt.';
  }

  @override
  String get readerImageMissing => 'Không tìm thấy ảnh';

  @override
  String get readerImageUnsupported => 'Không phải định dạng ảnh được hỗ trợ';

  @override
  String get readerImageRemoteBlocked =>
      'Đã chặn ảnh từ xa. Bật ảnh từ xa trong Cài đặt để tải.';

  @override
  String readerImageTooLarge(String name) {
    return '$name khá lớn nên không được hiển thị tự động.';
  }

  @override
  String get readerImageLoadAnyway => 'Vẫn tải';

  @override
  String get readerImageFailed => 'Không thể hiển thị ảnh này.';

  @override
  String get searchAcrossHint => 'Tìm trong các tệp đang mở';

  @override
  String get searchAcrossRunning => 'Đang tìm…';

  @override
  String get searchAcrossNoMatches => 'Không có kết quả trong các tệp đang mở';

  @override
  String searchAcrossSummary(int matches, int files) {
    String _temp0 = intl.Intl.pluralLogic(
      matches,
      locale: localeName,
      other: '$matches kết quả',
    );
    String _temp1 = intl.Intl.pluralLogic(
      files,
      locale: localeName,
      other: '$files tệp',
    );
    return '$_temp0 trong $_temp1';
  }

  @override
  String searchAcrossTruncated(int count) {
    return '$count+';
  }

  @override
  String get searchAcrossClose => 'Đóng tìm kiếm';

  @override
  String get quickSwitcherHint => 'Đi tới tệp';

  @override
  String get quickSwitcherEmpty => 'Không có kết quả';

  @override
  String get quickSwitcherRecentBadge => 'gần đây';

  @override
  String get menuOpenRecentClear => 'Xóa danh sách gần đây';

  @override
  String get emptyStateRecent => 'Gần đây';

  @override
  String get aboutTitle => 'Giới thiệu MarkLens';

  @override
  String aboutVersion(String version) {
    return 'Phiên bản $version';
  }

  @override
  String get aboutTagline => 'Trình xem Markdown nhanh, nhẹ, chỉ đọc.';

  @override
  String get aboutLicense => 'GPL-3.0-only. Phần mềm tự do, không bảo hành.';

  @override
  String get aboutHomepage => 'Trang dự án';

  @override
  String get commonClose => 'Đóng';

  @override
  String updateAvailable(String version) {
    return 'Đã có MarkLens $version';
  }

  @override
  String get updateOpenRelease => 'Xem thay đổi';

  @override
  String get updateUpToDate => 'MarkLens đã là bản mới nhất.';

  @override
  String get updateChecksOff => 'Kiểm tra cập nhật đang tắt trong Cài đặt.';

  @override
  String get logExportSuggestedName => 'marklens-log';

  @override
  String logExportWritten(String path) {
    return 'Đã ghi nhật ký chẩn đoán vào $path.';
  }

  @override
  String get logExportFailed => 'Không ghi được nhật ký chẩn đoán vào đó.';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get settingsSectionGeneral => 'Chung';

  @override
  String get settingsSectionReading => 'Đọc';

  @override
  String get settingsSectionFiles => 'Tệp';

  @override
  String get settingsSectionNetwork => 'Mạng';

  @override
  String get settingsLanguage => 'Ngôn ngữ';

  @override
  String get settingsFollowSystem => 'Theo hệ thống';

  @override
  String get settingsRestoreSession => 'Mở lại phiên trước khi khởi động';

  @override
  String get settingsRecentLimit => 'Số tài liệu gần đây được giữ';

  @override
  String get settingsFontScale => 'Cỡ chữ';

  @override
  String get settingsContentWidth => 'Bề rộng cột đọc';

  @override
  String get settingsContentWidthFull => 'Toàn bộ bề rộng';

  @override
  String get settingsFrontMatter => 'Front matter';

  @override
  String get settingsFrontMatterCollapsed => 'Thu gọn';

  @override
  String get settingsFrontMatterExpanded => 'Mở rộng';

  @override
  String get settingsFrontMatterHidden => 'Ẩn';

  @override
  String get settingsExtensions => 'Phần mở rộng tệp MarkLens mở';

  @override
  String get settingsExtensionsHint => 'Thêm phần mở rộng';

  @override
  String get settingsAdd => 'Thêm';

  @override
  String get settingsFileCap => 'Số tệp tối đa một thư mục được mở';

  @override
  String get settingsWatch => 'Tải lại tài liệu khi tệp thay đổi trên đĩa';

  @override
  String get settingsRemoteImages => 'Tải ảnh từ Internet';

  @override
  String get settingsRemoteImagesDetail =>
      'Mặc định tắt: tài liệu nêu tên một máy chủ có thể dùng nó để biết bạn đã mở tài liệu.';

  @override
  String get settingsUpdateCheck => 'Kiểm tra phiên bản mới';

  @override
  String get settingsUpdateCheckDetail =>
      'Nhiều nhất mỗi ngày một lần, tới GitHub. Không gửi thông tin gì về bạn.';

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
