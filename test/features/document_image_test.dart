/// The reader half of doc 04's image policy: what a reader sees when an image
/// is not shown, and that a request is only ever made when the setting says so.
///
/// `test/core/image_source_test.dart` covers which `src` is which. What this
/// adds is the half that needs a disk: existence, size, and the load-anyway
/// affordance.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/images/image_source.dart';
import 'package:marklens/features/reader/images/document_image.dart';
import 'package:marklens/features/reader/images/image_placeholder.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

void main() {
  late Directory root;

  String at(String name) => '${root.path}${Platform.pathSeparator}$name';

  setUp(() {
    root = Directory.systemTemp.createTempSync('marklens_images_');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  Future<void> pump(
    WidgetTester tester,
    ImageSource source, {
    bool allowRemote = false,
    int maxBytes = maxImageBytes,
    String? alt,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DocumentImage(
            source: source,
            allowRemote: allowRemote,
            maxBytes: maxBytes,
            alt: alt,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('local files', () {
    testWidgets('a missing one shows the resolved path, not the src', (
      tester,
    ) async {
      await pump(
        tester,
        LocalImageSource(path: at('nowhere.png'), isSvg: false),
      );

      expect(find.byType(ImagePlaceholder), findsOneWidget);
      expect(find.text('Image not found'), findsOneWidget);
      expect(
        find.text(at('nowhere.png')),
        findsOneWidget,
        reason:
            'a link that resolved somewhere unexpected is the bug this '
            'placeholder exists to make visible',
      );
    });

    testWidgets('a directory is missing rather than an exception', (
      tester,
    ) async {
      Directory(at('folder.png')).createSync();

      await pump(
        tester,
        LocalImageSource(path: at('folder.png'), isSvg: false),
      );

      expect(find.text('Image not found'), findsOneWidget);
    });

    testWidgets('an oversize one waits for a click', (tester) async {
      File(at('big.png')).writeAsBytesSync(List<int>.filled(64, 0));

      await pump(
        tester,
        LocalImageSource(path: at('big.png'), isSvg: false),
        maxBytes: 32,
      );

      expect(find.textContaining('big.png'), findsOneWidget);
      expect(find.text('Load anyway'), findsOneWidget);
    });

    testWidgets('and loading anyway is still local, and still a choice', (
      tester,
    ) async {
      File(at('big.png')).writeAsBytesSync(List<int>.filled(64, 0));

      await pump(
        tester,
        LocalImageSource(path: at('big.png'), isSvg: false),
        maxBytes: 32,
      );
      await tester.tap(find.text('Load anyway'));
      await tester.pump();

      expect(find.text('Load anyway'), findsNothing);
      // The bytes are not a PNG, so the decoder gives up — which is the point:
      // it degrades to a placeholder rather than taking the app down (rule 9).
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('a real SVG renders rather than placeholding', (tester) async {
      File(at('badge.svg')).writeAsStringSync(
        File('test/fixtures/torture/assets/badge.svg').readAsStringSync(),
      );

      await pump(tester, LocalImageSource(path: at('badge.svg'), isSvg: true));
      await tester.pumpAndSettle();

      expect(find.byType(ImagePlaceholder), findsNothing);
    });

    testWidgets('a malformed SVG does not take the app down', (tester) async {
      // Rule 9, measured rather than assumed: the corpus carries a deliberately
      // broken SVG, and what matters is that the frame still builds.
      File(at('bad.svg')).writeAsStringSync(
        File('test/fixtures/torture/assets/malformed.svg').readAsStringSync(),
      );

      await pump(tester, LocalImageSource(path: at('bad.svg'), isSvg: true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });
  });

  group('remote — the setting is the whole gate', () {
    testWidgets('blocked by default, showing the URL it refused', (
      tester,
    ) async {
      await pump(
        tester,
        RemoteImageSource(
          uri: Uri.parse('https://example.com/tracker.png'),
          isSvg: false,
        ),
      );

      expect(find.byType(ImagePlaceholder), findsOneWidget);
      expect(find.text('https://example.com/tracker.png'), findsOneWidget);
      expect(
        find.textContaining('Turn on remote images'),
        findsOneWidget,
        reason: 'doc 04 asks the placeholder to point at the setting',
      );
      expect(
        find.byType(Image),
        findsNothing,
        reason: 'no request is made while the setting is off (rule 5)',
      );
    });

    testWidgets('and with the setting on, it is an image', (tester) async {
      await pump(
        tester,
        RemoteImageSource(
          uri: Uri.parse('https://example.com/tracker.png'),
          isSvg: false,
        ),
        allowRemote: true,
      );

      expect(
        find.byType(Image),
        findsOneWidget,
        reason: 'the setting is the whole gate, and it is open',
      );
      expect(find.textContaining('Turn on remote images'), findsNothing);
      // The request itself cannot succeed against a test binding, so what is
      // showing is the decoder's error placeholder — which is the rule-9 half
      // of the same widget, reached rather than crashed into.
      expect(tester.takeException(), isNull);
    });
  });

  group('outside the allowlist', () {
    testWidgets('names the extension it will not open', (tester) async {
      await pump(
        tester,
        const UnsupportedImageSource(src: 'x.pdf', reason: 'pdf'),
      );

      expect(find.text('Not a supported image'), findsOneWidget);
      expect(find.text('pdf'), findsOneWidget);
    });
  });

  group('alt text', () {
    testWidgets('is shown, because it is all a reader can still get', (
      tester,
    ) async {
      await pump(
        tester,
        LocalImageSource(path: at('nowhere.png'), isSvg: false),
        alt: 'Architecture diagram',
      );

      expect(find.text('Architecture diagram'), findsOneWidget);
    });

    testWidgets('and labels the placeholder for a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const UnsupportedImageSource(src: 'x.pdf', reason: 'pdf'),
        alt: 'A chart',
      );

      final node = tester.getSemantics(find.byType(ImagePlaceholder));

      expect(
        node.label,
        contains('A chart'),
        reason: 'doc 06 asks for screen-reader labels on non-text content',
      );
      expect(
        node.flagsCollection.isImage,
        isTrue,
        reason: 'it stands in for an image, and should announce as one',
      );
      handle.dispose();
    });
  });
}
