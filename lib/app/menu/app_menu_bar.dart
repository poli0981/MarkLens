import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/chrome.dart';
import 'package:marklens/app/shortcuts.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// MarkLens's menu bar: File · View · Help (`docs/06_UI_UX.md`).
///
/// Built on Flutter's Material `MenuBar` rather than a hand-rolled row. Doc 06
/// reached the right conclusion — `PlatformMenuBar` is a macOS affair and is
/// not what we want — but from there assumed we would build the bar ourselves.
/// Spike S4 found `MenuBar` already is "our own widget row": it is a plain
/// widget, themed from `MenuBarTheme`, identical on Windows and Linux, and it
/// handles arrow traversal and `Esc` for us.
///
/// What it will not do is let the bar be focused while every menu is closed —
/// `_MenuBarAnchorState` wraps its children in `ExcludeFocus` until something
/// opens. So doc 06's "Alt focuses the menu bar" is not achievable as written,
/// and Alt opens the File menu instead; the shell owns that key handling.
///
/// Every label goes through ARB (CLAUDE.md rule 4) and every shortcut label is
/// derived from [appShortcuts], so the bar cannot advertise a key combination
/// that is not actually bound.
///
/// The three top-level titles carry accelerator markers (`&File`, `&Tệp`,
/// `ファイル(&F)`) so `Alt+F` / `Alt+V` / `Alt+H` open them and the letters
/// underline while `Alt` is held. The marker lives in the *translated* string
/// because the letter has to differ per language.
class AppMenuBar extends ConsumerWidget {
  /// Creates the menu bar.
  const AppMenuBar({required this.fileMenuController, super.key});

  /// Opens the File menu when `Alt` is tapped on its own.
  ///
  /// Flutter's `MenuBar` wraps itself in `ExcludeFocus` while every menu is
  /// closed, so the bar cannot be *focused* without being *opened* — spike S4.
  /// Alt therefore opens rather than highlights.
  final MenuController fileMenuController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final chrome = ref.watch(chromeProvider);
    final controller = ref.read(chromeProvider.notifier);

    void todo(String item) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.menuNotImplemented(item))),
        );
    }

    return MenuBar(
      children: <Widget>[
        SubmenuButton(
          controller: fileMenuController,
          menuChildren: <Widget>[
            MenuItemButton(
              shortcut: _activatorFor<OpenFilesIntent>(),
              onPressed: () => todo(l10n.menuOpenFiles),
              child: Text(l10n.menuOpenFiles),
            ),
            MenuItemButton(
              shortcut: _activatorFor<OpenFolderIntent>(),
              onPressed: () => todo(l10n.menuOpenFolder),
              child: Text(l10n.menuOpenFolder),
            ),
            SubmenuButton(
              menuChildren: <Widget>[
                // Disabled on purpose: an empty submenu would be a dead end
                // with no explanation (docs/06, empty states).
                MenuItemButton(child: Text(l10n.menuOpenRecentEmpty)),
              ],
              child: Text(l10n.menuOpenRecent),
            ),
            MenuItemButton(
              shortcut: _activatorFor<ReloadDocumentIntent>(),
              onPressed: () => todo(l10n.menuReload),
              child: Text(l10n.menuReload),
            ),
            MenuItemButton(
              shortcut: _activatorFor<CopyDocumentIntent>(),
              onPressed: () => todo(l10n.menuCopyDocument),
              child: Text(l10n.menuCopyDocument),
            ),
            MenuItemButton(
              shortcut: _activatorFor<CloseTabIntent>(),
              onPressed: () => todo(l10n.menuCloseTab),
              child: Text(l10n.menuCloseTab),
            ),
            MenuItemButton(
              onPressed: () => todo(l10n.menuCloseAll),
              child: Text(l10n.menuCloseAll),
            ),
            MenuItemButton(
              shortcut: _activatorFor<OpenSettingsIntent>(),
              onPressed: () => todo(l10n.menuSettings),
              child: Text(l10n.menuSettings),
            ),
            MenuItemButton(
              onPressed: () => todo(l10n.menuExit),
              child: Text(l10n.menuExit),
            ),
          ],
          child: MenuAcceleratorLabel(l10n.menuFile),
        ),
        SubmenuButton(
          menuChildren: <Widget>[
            // The View menu is live in the prototype: everything here is local
            // UI state, so S4's "does it feel right" gate can actually be felt.
            CheckboxMenuButton(
              value: chrome.sidebarVisible,
              onChanged: (_) => controller.toggleSidebar(),
              shortcut: _activatorFor<ToggleSidebarIntent>(),
              child: Text(l10n.menuToggleSidebar),
            ),
            CheckboxMenuButton(
              value: chrome.outlineVisible,
              onChanged: (_) => controller.toggleOutline(),
              shortcut: _activatorFor<ToggleOutlineIntent>(),
              child: Text(l10n.menuToggleOutline),
            ),
            MenuItemButton(
              shortcut: _zoomActivator(1),
              onPressed: () => controller.zoomBy(1),
              child: Text(l10n.menuZoomIn),
            ),
            MenuItemButton(
              shortcut: _zoomActivator(-1),
              onPressed: () => controller.zoomBy(-1),
              child: Text(l10n.menuZoomOut),
            ),
            MenuItemButton(
              shortcut: _zoomActivator(0),
              onPressed: () => controller.zoomBy(0),
              child: Text(l10n.menuZoomReset),
            ),
            SubmenuButton(
              menuChildren: <Widget>[
                for (final entry in <(ThemeMode, String)>[
                  (ThemeMode.system, l10n.menuThemeSystem),
                  (ThemeMode.light, l10n.menuThemeLight),
                  (ThemeMode.dark, l10n.menuThemeDark),
                ])
                  RadioMenuButton<ThemeMode>(
                    value: entry.$1,
                    groupValue: chrome.themeMode,
                    onChanged: (mode) =>
                        controller.setThemeMode(mode ?? ThemeMode.system),
                    child: Text(entry.$2),
                  ),
              ],
              child: Text(l10n.menuTheme),
            ),
            CheckboxMenuButton(
              value: chrome.fullScreen,
              onChanged: (_) => controller.toggleFullScreen(),
              shortcut: _activatorFor<ToggleFullScreenIntent>(),
              child: Text(l10n.menuFullScreen),
            ),
          ],
          child: MenuAcceleratorLabel(l10n.menuView),
        ),
        SubmenuButton(
          menuChildren: <Widget>[
            MenuItemButton(
              onPressed: () => todo(l10n.menuCheckUpdates),
              child: Text(l10n.menuCheckUpdates),
            ),
            MenuItemButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
              ),
              child: Text(l10n.menuThirdPartyLicenses),
            ),
            MenuItemButton(
              onPressed: () => todo(l10n.menuExportLog),
              child: Text(l10n.menuExportLog),
            ),
            MenuItemButton(
              onPressed: () => showAboutDialog(
                context: context,
                applicationName: l10n.appTitle,
              ),
              child: Text(l10n.menuAbout),
            ),
          ],
          child: MenuAcceleratorLabel(l10n.menuHelp),
        ),
      ],
    );
  }
}

/// The activator bound to [T] in [appShortcuts], or `null` if it has none.
///
/// Looking the label up rather than writing it beside the item is what stops
/// the menu from claiming a shortcut nobody wired.
MenuSerializableShortcut? _activatorFor<T extends Intent>() {
  for (final entry in appShortcuts.entries) {
    if (entry.value is T && entry.key is MenuSerializableShortcut) {
      return entry.key as MenuSerializableShortcut;
    }
  }
  return null;
}

/// Zoom shares one intent type across three activators, so it is matched on
/// the step rather than the type.
MenuSerializableShortcut? _zoomActivator(int step) {
  for (final entry in appShortcuts.entries) {
    final intent = entry.value;
    if (intent is ZoomIntent &&
        intent.step == step &&
        entry.key is MenuSerializableShortcut) {
      return entry.key as MenuSerializableShortcut;
    }
  }
  return null;
}
