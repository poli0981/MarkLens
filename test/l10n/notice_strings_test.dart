/// CLAUDE.md rule 4 and `docs/09_I18N.md` rule 1: every user-facing string is
/// an ARB key, notices included.
///
/// `DocNotice` deliberately carries a kind and never a message, so the text is
/// resolved at the widget layer. Nothing enforced that a kind actually *had* a
/// string — the notice bar itself lands with the reader in M1 step 5, and until
/// then a new `DocNoticeKind` could be added with no translation and nobody
/// would find out until it appeared blank in front of a user.
///
/// The switch below is exhaustive over the enum with no default branch, so
/// adding a kind without an ARB key stops compiling. When the notice bar lands,
/// this mapping moves into the reader and this file shrinks to asserting the
/// three locales are populated.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// The message for [kind], in [l10n]'s locale.
String noticeMessage(AppLocalizations l10n, DocNoticeKind kind) =>
    switch (kind) {
      DocNoticeKind.invalidUtf8 => l10n.readerNoticeInvalidUtf8,
      DocNoticeKind.frontMatterUnparsed => l10n.readerNoticeFrontMatterUnparsed,
      DocNoticeKind.mdxBailOut => l10n.readerNoticeMdxBailOut,
      DocNoticeKind.plainTextFallback => l10n.readerNoticePlainTextFallback,
      DocNoticeKind.largeDocument => l10n.readerNoticeLargeDocument,
    };

void main() {
  group('every notice kind has a string in every locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      test(locale.languageCode, () async {
        final l10n = await AppLocalizations.delegate.load(locale);
        final messages = <String>[];

        for (final kind in DocNoticeKind.values) {
          final message = noticeMessage(l10n, kind);
          expect(
            message.trim(),
            isNotEmpty,
            reason:
                '${kind.name} has no text in ${locale.languageCode} — a notice '
                'the reader cannot phrase is a notice the user cannot act on',
          );
          messages.add(message);
        }

        expect(
          messages.toSet().length,
          messages.length,
          reason:
              'two kinds share the same text in ${locale.languageCode}, so one '
              'of them is telling the user the wrong thing',
        );
      });
    }

    test('all three locales are covered', () {
      expect(
        AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
        <String>{'en', 'vi', 'ja'},
      );
    });
  });
}
