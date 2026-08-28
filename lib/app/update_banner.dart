import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/update/semver.dart';
import 'package:marklens/core/update/update_service.dart';

/// What the update banner is saying, if anything.
@immutable
class UpdateBannerState {
  /// Creates a banner state.
  const UpdateBannerState({
    this.available,
    this.checking = false,
    this.checkedManually = false,
  });

  /// The newer release, or `null`.
  final AvailableUpdate? available;

  /// Whether a check is in flight.
  final bool checking;

  /// Whether the last check was Help → Check for Updates rather than the
  /// automatic one.
  ///
  /// It is the only thing that separates "nothing to say" from "you asked, and
  /// the answer is you are up to date": an automatic check that finds nothing
  /// must be completely silent (doc 11), and a manual one that says nothing is
  /// a button that appears broken.
  final bool checkedManually;

  /// Whether the banner is showing.
  bool get visible => available != null;

  /// Returns a copy with the given fields replaced.
  UpdateBannerState copyWith({
    AvailableUpdate? available,
    bool? checking,
    bool? checkedManually,
    bool clearAvailable = false,
  }) => UpdateBannerState(
    available: clearAvailable ? null : (available ?? this.available),
    checking: checking ?? this.checking,
    checkedManually: checkedManually ?? this.checkedManually,
  );
}

/// Runs the release check and holds what it found (`docs/03_DATA_FLOW.md`,
/// `updateBanner`).
///
/// Two entry points with deliberately different manners. [checkOnLaunch]
/// respects both the setting and the 24-hour interval and says nothing unless
/// there is news; [checkNow] is the Help menu, ignores the interval, and
/// always reports — including "you are up to date", which is the answer a
/// person who clicked a button is owed.
class UpdateBannerController extends Notifier<UpdateBannerState> {
  @override
  UpdateBannerState build() => const UpdateBannerState();

  /// The version this binary reports, parsed once.
  static final SemVer current =
      SemVer.tryParse(appVersion) ?? const SemVer(0, 0, 0);

  /// The automatic check of doc 03: setting on, and not in the last 24 hours.
  Future<void> checkOnLaunch() async {
    if (!ref.read(settingsProvider).network.updateCheck) {
      // "Off" means no request is made, not a flag consulted afterwards — the
      // same shape `files.watchEnabled` takes (doc 07).
      return;
    }
    final service = ref.read(updateServiceProvider);
    if (!service.isDue(ref.read(lastUpdateCheckProvider))) {
      return;
    }
    await _run(service, manual: false);
  }

  /// Help → Check for Updates: now, regardless of when the last one ran.
  ///
  /// It does **not** override the setting. Turning update checks off is a
  /// statement about network traffic, and a menu item that ignored it would
  /// make the setting a suggestion.
  Future<void> checkNow() async {
    if (!ref.read(settingsProvider).network.updateCheck) {
      state = state.copyWith(checkedManually: true);
      return;
    }
    await _run(ref.read(updateServiceProvider), manual: true);
  }

  /// Dismisses the banner for this launch.
  void dismiss() =>
      state = state.copyWith(clearAvailable: true, checkedManually: false);

  Future<void> _run(UpdateService service, {required bool manual}) async {
    state = state.copyWith(checking: true, checkedManually: manual);
    final found = await service.check(
      current: current,
      log: ref.read(logBufferProvider),
    );
    // Recorded whatever the answer was, including a failure: the interval
    // exists to bound *requests*, and retrying every launch because the last
    // one was offline is the behaviour it is there to prevent.
    ref.read(lastUpdateCheckProvider.notifier).stamp();
    state = UpdateBannerState(
      available: found,
      checkedManually: manual,
    );
  }
}

/// The update-banner provider.
final NotifierProvider<UpdateBannerController, UpdateBannerState>
updateBannerProvider =
    NotifierProvider<UpdateBannerController, UpdateBannerState>(
      UpdateBannerController.new,
    );

/// When the update check last ran, restored from and written back to
/// `session.json`.
class LastUpdateCheck extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Puts back what the session remembered.
  ///
  /// A method rather than a setter, matching `RecentFiles.restore`: both say
  /// which direction the value is travelling, where `lastUpdateCheck = x`
  /// would read as asserting a fact rather than loading one.
  // ignore: use_setters_to_change_properties
  void restore(DateTime? when) => state = when;

  /// Records that a check just ran.
  void stamp() {
    state = DateTime.now().toUtc();
    ref.read(sessionLinkProvider).save();
  }
}

/// The last-check provider.
final NotifierProvider<LastUpdateCheck, DateTime?> lastUpdateCheckProvider =
    NotifierProvider<LastUpdateCheck, DateTime?>(LastUpdateCheck.new);
