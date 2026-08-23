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
  String get menuFile => 'Tệp';

  @override
  String get menuView => 'Hiển thị';

  @override
  String get menuHelp => 'Trợ giúp';

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
}
