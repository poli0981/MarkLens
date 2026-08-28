/// `docs/11_PACKAGING_UPDATE.md`'s banner and `docs/06_UI_UX.md`'s Help menu,
/// driven through the real shell.
///
/// The transport and the save dialog are both stubbed: one would open a socket
/// and the other a platform dialog, and neither exists inside `testWidgets`.
/// What is asserted is everything above those two seams.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/app.dart';
import 'package:marklens/app/open_files.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/core/session/session_store.dart';
import 'package:marklens/core/update/update_service.dart';
import 'package:marklens/features/about/about_dialog.dart';

class _StubTransport implements UpdateTransport {
  _StubTransport(this.body);

  String? body;
  int calls = 0;

  @override
  Future<String?> fetchLatestRelease(Uri endpoint) async {
    calls++;
    return body;
  }
}

class _StubPrompt implements FilePickerPrompt {
  @override
  Future<List<String>> pickDocuments(ExtensionRegistry registry) async =>
      const <String>[];

  @override
  Future<String?> pickFolder() async => null;
}

/// A release document for [tag], newer than `appVersion` when [tag] is.
String release(String tag) =>
    '{"tag_name":"$tag","html_url":"https://example.com/r/$tag",'
    '"draft":false,"prerelease":false}';

void main() {
  late Directory root;
  late _StubTransport transport;
  late RecordingLauncherLink launcher;
  late StubSaveFilePrompt saver;

  setUp(() {
    root = Directory.systemTemp.createTempSync('marklens_update_');
    transport = _StubTransport(null);
    launcher = RecordingLauncherLink();
    saver = StubSaveFilePrompt();
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
        listen: false,
      );

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    bool updateCheck = true,
  }) async {
    tester.view
      ..physicalSize = const Size(1400, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    if (!updateCheck) {
      // Written before the app starts, so the setting is off at cold start
      // rather than toggled afterwards — which is what "off means no request
      // is made" has to survive.
      File('${root.path}${Platform.pathSeparator}settings.json')
          .writeAsStringSync(
            jsonEncode(<String, Object?>{
              'version': 1,
              'network': <String, Object?>{'updateCheck': false},
            }),
          );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configDirectoryProvider.overrideWithValue(root),
          filePickerPromptProvider.overrideWithValue(_StubPrompt()),
          windowLinkProvider.overrideWithValue(const NoWindowLink()),
          watchLinkProvider.overrideWithValue(const NoWatchLink()),
          launcherLinkProvider.overrideWithValue(launcher),
          saveFilePromptProvider.overrideWithValue(saver),
          updateServiceProvider.overrideWithValue(
            UpdateService(transport: transport),
          ),
          sessionStoreProvider.overrideWithValue(
            SessionStore(
              directory: root,
              debounce: const Duration(milliseconds: 10),
            ),
          ),
        ],
        child: const MarkLensApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));
    return containerOf(tester);
  }

  Future<void> openHelp(WidgetTester tester, String item) async {
    await tester.tap(find.text('Help'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, item));
    await tester.pumpAndSettle();
  }

  group('the launch check', () {
    testWidgets('runs, and raises the banner when there is news', (
      tester,
    ) async {
      transport.body = release('v9.9.9');

      await pumpApp(tester);

      expect(transport.calls, 1);
      expect(find.text('MarkLens 9.9.9 is available'), findsOneWidget);
    });

    testWidgets('is completely silent when up to date', (tester) async {
      transport.body = release('v0.0.1');

      await pumpApp(tester);

      expect(transport.calls, 1);
      expect(find.textContaining('is available'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('and silent when offline', (tester) async {
      transport.body = null;

      await pumpApp(tester);

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('makes no request at all while the setting is off', (
      tester,
    ) async {
      transport.body = release('v9.9.9');

      await pumpApp(tester, updateCheck: false);

      expect(
        transport.calls,
        0,
        reason: '"off" means no request, not a flag consulted afterwards',
      );
      expect(find.textContaining('is available'), findsNothing);
    });

    testWidgets('and does not run again inside 24 hours', (tester) async {
      // The stamp is written to session.json, so a second launch sees it.
      transport.body = release('v9.9.9');
      await pumpApp(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(transport.calls, 1);

      // A blank frame between two cold starts, or the second reuses the
      // element tree and `initState` never runs.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await pumpApp(tester);

      expect(
        transport.calls,
        1,
        reason: 'the interval bounds requests across launches, not per launch',
      );
    });
  });

  group('the banner', () {
    testWidgets('opens the release page rather than downloading', (
      tester,
    ) async {
      transport.body = release('v9.9.9');
      await pumpApp(tester);

      await tester.tap(find.text('See what changed'));
      await tester.pumpAndSettle();

      expect(launcher.opened.single.toString(), 'https://example.com/r/v9.9.9');
    });

    testWidgets('and can be dismissed', (tester) async {
      transport.body = release('v9.9.9');
      await pumpApp(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(UpdateBanner),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('is available'), findsNothing);
    });
  });

  group('Help → Check for Updates', () {
    testWidgets('answers even when there is nothing to say', (tester) async {
      transport.body = release('v0.0.1');
      await pumpApp(tester);

      await openHelp(tester, 'Check for Updates…');

      // The automatic check is silent; a button that says nothing looks broken.
      expect(find.text('MarkLens is up to date.'), findsOneWidget);
    });

    testWidgets('ignores the interval but not the setting', (tester) async {
      transport.body = release('v0.0.1');
      await pumpApp(tester, updateCheck: false);

      await openHelp(tester, 'Check for Updates…');

      expect(transport.calls, 0);
      expect(
        find.text('Update checks are turned off in Settings.'),
        findsOneWidget,
        reason: 'a menu item that overrode the setting would make it advice',
      );
    });

    testWidgets('and raises the banner rather than a second announcement', (
      tester,
    ) async {
      transport.body = release('v9.9.9');
      await pumpApp(tester);
      // Dismiss the launch banner so the manual check has something to do.
      await tester.tap(
        find.descendant(
          of: find.byType(UpdateBanner),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();

      await openHelp(tester, 'Check for Updates…');

      expect(find.text('MarkLens 9.9.9 is available'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('Help → About', () {
    testWidgets('shows the version, not just the name', (tester) async {
      await pumpApp(tester);

      await openHelp(tester, 'About MarkLens');

      expect(find.byType(AboutMarkLens), findsOneWidget);
      expect(find.text('Version $appVersion'), findsOneWidget);
      expect(find.textContaining('GPL-3.0-only'), findsOneWidget);
    });

    testWidgets('and reaches the project page through the launcher seam', (
      tester,
    ) async {
      await pumpApp(tester);
      await openHelp(tester, 'About MarkLens');

      await tester.tap(find.text('Project page'));
      await tester.pumpAndSettle();

      expect(launcher.opened.single.host, 'github.com');
    });
  });

  group('Help → Export Diagnostic Log', () {
    testWidgets('offers the log, and says where it went', (tester) async {
      final container = await pumpApp(tester);
      container.read(logBufferProvider).add('test', 'something happened');

      saver.destination = '${root.path}${Platform.pathSeparator}out.log';
      await openHelp(tester, 'Export Diagnostic Log…');

      expect(saver.calls, 1);
      expect(
        utf8.decode(saver.written!),
        contains('something happened'),
        reason: 'the bytes are the log, and the platform writes them',
      );
      expect(find.textContaining('Diagnostic log written to'), findsOneWidget);
    });

    testWidgets('a cancelled dialog is an answer, not an error', (
      tester,
    ) async {
      await pumpApp(tester);
      saver.destination = null;

      await openHelp(tester, 'Export Diagnostic Log…');

      expect(saver.calls, 1);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('and the launch check is in the log it exports', (
      tester,
    ) async {
      transport.body = release('v0.0.1');
      await pumpApp(tester);

      saver.destination = '${root.path}${Platform.pathSeparator}out.log';
      await openHelp(tester, 'Export Diagnostic Log…');

      expect(utf8.decode(saver.written!), contains('update'));
    });
  });
}
