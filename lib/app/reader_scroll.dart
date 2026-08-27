import 'dart:async';
import 'dart:collection';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The reader's scroll position, addressed by block index.
///
/// A `ListView.builder` cannot jump to an index it has not built, because it
/// does not know the extents of children it has never laid out. That is the one
/// missing primitive behind the outline's click-to-jump and its scroll-spy, the
/// find bar's jumps, `#anchor` links, session scroll restore, doc 03's
/// keep-your-place-on-reload, and the status bar's `position %`. All of it,
/// waiting on this.
///
/// No dependency: `docs/13_CODE_QUALITY.md` prefers our own code to a utility
/// package, and doc 01 counted `scroll_to_index` against the renderer candidate
/// that was rejected — pulling in the equivalent here would be arguing both
/// sides.
///
/// It lives in `app/` rather than `features/reader/` because the outline and
/// the find bar are *other* features, and a feature may not import another
/// (`docs/02_ARCHITECTURE.md`). They reach it through `app/providers.dart`,
/// which is the one door.
class BlockScroller {
  /// Creates a scroller. One per reader.
  BlockScroller() {
    controller.addListener(_onScroll);
  }

  /// How long a programmatic jump takes once it is close enough to animate.
  static const Duration revealDuration = Duration(milliseconds: 220);

  /// The curve of that last movement.
  static const Curve revealCurve = Curves.easeOutCubic;

  /// How long the accent pulse stays on the block that was jumped to.
  static const Duration pulseDuration = Duration(milliseconds: 900);

  /// Idle time before a scroll counts as settled (`docs/03_DATA_FLOW.md`).
  static const Duration settleDelay = Duration(milliseconds: 400);

  /// How far short of the target a long jump deliberately lands, so the
  /// arrival is a glide rather than a teleport.
  static const double glideDistance = 120;

  /// How many times [reveal] may jump-and-look before it settles for its best
  /// estimate. Each jump builds more children, which improves the next guess.
  static const int maxProbes = 8;

  /// The height assumed for a block nothing has measured yet.
  static const double assumedExtent = 48;

  /// How many measurements are kept. Scrolling a 1 MB document must not
  /// accumulate twenty-six thousand of them.
  static const int measurementCap = 400;

  /// Handed to the renderer, which gives it to its `ListView`.
  final ScrollController controller = ScrollController();

  /// The block at the top of the viewport, or `-1` before anything is built.
  final ValueNotifier<int> topBlock = ValueNotifier<int>(-1);

  /// How far through the document the reader is, as a whole percent.
  ///
  /// Whole percents, not pixels: it is what the status bar displays, so finer
  /// resolution would rebuild it sixty times a second to show the same string.
  final ValueNotifier<int> positionPercent = ValueNotifier<int>(0);

  /// The block currently flashing after a jump, or `-1`.
  final ValueNotifier<int> pulsingBlock = ValueNotifier<int>(-1);

  /// Called [settleDelay] after the reader stops moving, with the document's
  /// identity and where it is — one of doc 03's session-save triggers.
  void Function(String identity, double ratio)? onScrollSettled;

  final SplayTreeMap<int, double> _offsets = SplayTreeMap<int, double>();
  String? _identity;
  int _blockCount = 0;
  double _meanExtent = assumedExtent;
  Timer? _settle;
  Timer? _pulse;
  bool _restoring = false;
  bool _disposed = false;

  /// Where the reader is, as a 0..1 ratio.
  double get ratio {
    if (!controller.hasClients) {
      return 0;
    }
    final extent = controller.position.maxScrollExtent;
    // A document shorter than the window does not scroll; it is all showing,
    // which reads as the top rather than as a division by zero.
    return extent <= 0 ? 0 : (controller.offset / extent).clamp(0.0, 1.0);
  }

  /// The reader is now showing a different document.
  ///
  /// Everything measured belonged to the old one, so it goes.
  void adopt({
    required String identity,
    required int blockCount,
    double restoreRatio = 0,
  }) {
    _identity = identity;
    _blockCount = blockCount;
    invalidateMeasurements();
    // The reader adopts a document from `initState` and `didUpdateWidget` —
    // both inside a build. Writing a `ValueNotifier` there marks its listeners
    // dirty while the framework is already building them, which is an error,
    // not a warning. Everything that notifies waits for the frame to end.
    _afterFrame(() {
      topBlock.value = -1;
      pulsingBlock.value = -1;
      unawaited(restoreRatioPosition(restoreRatio));
    });
  }

  void _afterFrame(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) {
        action();
      }
    });
  }

  /// Forgets every measurement, for a reflow the old numbers cannot describe —
  /// a zoom change, a resized column.
  void invalidateMeasurements() {
    _offsets.clear();
    _meanExtent = assumedExtent;
  }

  /// Records where a block actually landed. Called from the block wrapper.
  void report(int index, double offset, double extent) {
    if (_disposed) {
      return;
    }
    _offsets[index] = offset;
    if (extent > 0) {
      // A running mean, so one enormous table does not define every estimate.
      _meanExtent = _meanExtent == assumedExtent
          ? extent
          : (_meanExtent * 3 + extent) / 4;
    }
    if (_offsets.length > measurementCap) {
      _trimMeasurementsAround(index);
    }
    // The first measurements arrive *after* the frame that opened the
    // document, so without this nothing knows which block is at the top until
    // the reader scrolls — and the outline would open with nothing selected.
    _publish();
  }

  /// Drops a measurement for a block that has left the built window.
  ///
  /// Its offset is still true, but only until something above it reflows, and
  /// keeping every block ever scrolled past is how the map grows without end.
  void forgetIfPresent(int index) => _offsets.remove(index);

  /// Drops the measurements furthest from where the reader is now.
  void _trimMeasurementsAround(int index) {
    while (_offsets.length > measurementCap) {
      final first = _offsets.firstKey()!;
      final last = _offsets.lastKey()!;
      _offsets.remove((index - first) >= (last - index) ? first : last);
    }
  }

  /// Brings [index] to the top of the viewport.
  Future<void> reveal(int index, {bool pulse = true}) async {
    if (!controller.hasClients || _blockCount == 0) {
      return;
    }
    final target = index.clamp(0, _blockCount - 1);

    for (var probe = 0; probe < maxProbes; probe++) {
      if (_offsets.containsKey(target)) {
        break;
      }
      final estimate = _clampOffset(_estimate(target));
      if ((controller.offset - estimate).abs() < 1) {
        break;
      }
      controller.jumpTo(estimate);
      // Each jump builds the children around it, which both answers the
      // question and improves the next guess. One jump is never enough on a
      // lazy list: `maxScrollExtent` is itself an estimate until the end of the
      // document has been built.
      await SchedulerBinding.instance.endOfFrame;
      if (!controller.hasClients) {
        return;
      }
    }

    final destination = _clampOffset(_offsets[target] ?? _estimate(target));
    if ((controller.offset - destination).abs() > glideDistance) {
      // Land deliberately short, then glide the rest. A 220 ms animation
      // across 900,000 px of a 1 MB document is not smooth, it is a smear.
      controller.jumpTo(_clampOffset(destination - glideDistance));
    }
    await controller.animateTo(
      destination,
      duration: revealDuration,
      curve: revealCurve,
    );

    if (pulse) {
      _startPulse(target);
    }
  }

  /// Puts the reader back at a remembered ratio (`session.json`).
  Future<void> restoreRatioPosition(double target) async {
    if (target <= 0) {
      if (controller.hasClients && controller.offset != 0) {
        controller.jumpTo(0);
      }
      _publish();
      return;
    }
    _restoring = true;
    // Two frames: the first lays out enough of the document for
    // `maxScrollExtent` to mean something, the second lands on it.
    for (var attempt = 0; attempt < 2; attempt++) {
      await SchedulerBinding.instance.endOfFrame;
      if (!controller.hasClients) {
        _restoring = false;
        return;
      }
      controller.jumpTo(
        _clampOffset(controller.position.maxScrollExtent * target),
      );
    }
    _restoring = false;
    _publish();
  }

  void _startPulse(int index) {
    _pulse?.cancel();
    pulsingBlock.value = index;
    _pulse = Timer(pulseDuration, () => pulsingBlock.value = -1);
  }

  double _estimate(int index) {
    if (_offsets.isEmpty) {
      return index * _meanExtent;
    }
    final before = _offsets.lastKeyBefore(index + 1);
    final after = _offsets.firstKeyAfter(index);
    final anchor = before ?? after!;
    return _offsets[anchor]! + (index - anchor) * _meanExtent;
  }

  double _clampOffset(double offset) {
    if (!controller.hasClients) {
      return offset;
    }
    final position = controller.position;
    return offset.clamp(position.minScrollExtent, position.maxScrollExtent);
  }

  void _onScroll() {
    if (_restoring) {
      return;
    }
    _publish();

    final identity = _identity;
    if (identity == null || onScrollSettled == null) {
      return;
    }
    _settle?.cancel();
    _settle = Timer(settleDelay, () => onScrollSettled?.call(identity, ratio));
  }

  void _publish() {
    final percent = (ratio * 100).round();
    if (positionPercent.value != percent) {
      positionPercent.value = percent;
    }
    final top = _topBlockAt(controller.hasClients ? controller.offset : 0);
    if (topBlock.value != top) {
      topBlock.value = top;
    }
  }

  /// The last measured block that starts at or above [offset].
  ///
  /// Only measured blocks are considered, and a `ListView` keeps a bounded
  /// window of those, so this is O(built) and not O(document).
  int _topBlockAt(double offset) {
    var best = -1;
    for (final entry in _offsets.entries) {
      if (entry.value <= offset + 1) {
        best = entry.key;
      } else {
        break;
      }
    }
    return best;
  }

  /// Releases the controller and every timer.
  void dispose() {
    _disposed = true;
    _settle?.cancel();
    _pulse?.cancel();
    controller
      ..removeListener(_onScroll)
      ..dispose();
    topBlock.dispose();
    positionPercent.dispose();
    pulsingBlock.dispose();
  }
}

/// The reader's scroller.
final Provider<BlockScroller> readerScrollProvider = Provider<BlockScroller>((
  ref,
) {
  final scroller = BlockScroller();
  ref.onDispose(scroller.dispose);
  return scroller;
});
