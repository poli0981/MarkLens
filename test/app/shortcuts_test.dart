import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/shortcuts.dart';

/// The doc 06 shortcut inventory, and spike S4's "no conflicts with Flutter
/// defaults" gate.
void main() {
  group('the inventory itself', () {
    test('no two actions claim the same key combination', () {
      final seen = <String, Intent>{};
      for (final entry in appShortcuts.entries) {
        final key = entry.key.debugDescribeKeys();
        expect(
          seen,
          isNot(contains(key)),
          reason:
              '$key is bound to both ${seen[key].runtimeType} and '
              '${entry.value.runtimeType}',
        );
        seen[key] = entry.value;
      }
    });

    test('every activator is one a menu item can display', () {
      // MenuItemButton renders the shortcut label from the activator, so an
      // activator it cannot serialise would leave the menu silently label-less.
      for (final activator in appShortcuts.keys) {
        expect(
          activator,
          isA<MenuSerializableShortcut>(),
          reason: '$activator cannot be shown next to a menu item',
        );
      }
    });

    test('Ctrl+A is not bound', () {
      // It keeps its conventional meaning — selecting the rendered text. The
      // whole-document copy is Ctrl+Shift+C (docs/spike-results/S2-selection).
      const ctrlA = SingleActivator(LogicalKeyboardKey.keyA, control: true);
      expect(
        appShortcuts.keys.map((a) => a.debugDescribeKeys()),
        isNot(contains(ctrlA.debugDescribeKeys())),
      );
    });
  });

  group('no conflict with Flutter defaults', () {
    // Behavioural rather than a hard-coded list of Flutter's own bindings:
    // those are private and would drift. If Flutter ever adds a default that
    // swallows one of ours, these go red.
    for (final entry in appShortcuts.entries) {
      testWidgets('${entry.key.debugDescribeKeys()} reaches its action', (
        tester,
      ) async {
        var fired = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Shortcuts(
              shortcuts: appShortcuts,
              child: Actions(
                actions: <Type, Action<Intent>>{
                  entry.value.runtimeType: CallbackAction<Intent>(
                    onInvoke: (_) {
                      fired = true;
                      return null;
                    },
                  ),
                },
                child: const Focus(autofocus: true, child: SizedBox.expand()),
              ),
            ),
          ),
        );
        await tester.pump();

        await _send(tester, entry.key as SingleActivator);
        expect(fired, isTrue, reason: 'the intent never reached its action');
      });
    }

    testWidgets('and they still reach it while a text field has focus', (
      tester,
    ) async {
      // The case that actually matters: Flutter's DefaultTextEditingShortcuts
      // sits between a focused EditableText and our bindings. On macOS it
      // binds Ctrl+A/B/E/F/N/T, which would swallow Ctrl+B and Ctrl+F — but
      // Windows and Linux bind no Control+letter at all, which is what this
      // asserts for the platforms v1 targets.
      final fired = <Type>{};
      await tester.pumpWidget(
        MaterialApp(
          home: Shortcuts(
            shortcuts: appShortcuts,
            child: Actions(
              actions: <Type, Action<Intent>>{
                for (final intent in appShortcuts.values)
                  intent.runtimeType: CallbackAction<Intent>(
                    onInvoke: (i) {
                      fired.add(i.runtimeType);
                      return null;
                    },
                  ),
              },
              child: const Material(child: TextField(autofocus: true)),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.testTextInput.isRegistered,
        isTrue,
        reason: 'the text field never took focus, so this proves nothing',
      );

      for (final entry in appShortcuts.entries) {
        await _send(tester, entry.key as SingleActivator);
      }

      final missed = appShortcuts.values
          .map((i) => i.runtimeType)
          .toSet()
          .difference(fired);
      expect(
        missed,
        isEmpty,
        reason: 'swallowed while a text field had focus: $missed',
      );
    });
  });

  group('a bare Alt cannot be a shortcut at all', () {
    test('SingleActivator refuses a modifier as its trigger', () {
      // Why FocusMenuBarIntent lives on a key-event handler instead of in
      // appShortcuts (spike S4). If this ever stops throwing, the Alt handling
      // in the shell can be simplified into a normal binding.
      expect(
        () => SingleActivator(LogicalKeyboardKey.altLeft),
        throwsAssertionError,
      );
    });

    test('and Alt is therefore absent from the inventory', () {
      for (final intent in appShortcuts.values) {
        expect(intent, isNot(isA<FocusMenuBarIntent>()));
      }
    });
  });
}

/// Presses [activator], modifiers and all, then releases everything.
Future<void> _send(WidgetTester tester, SingleActivator activator) async {
  if (activator.control) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  }
  if (activator.shift) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyEvent(activator.trigger);
  if (activator.shift) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
  if (activator.control) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  }
  await tester.pump();
}
