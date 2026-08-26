/// Where the window was, so it comes back where it was left.
class WindowGeometry {
  /// Creates a geometry.
  const WindowGeometry({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.maximized = false,
  });

  /// Reads a geometry from [json], or returns `null` if it is not usable.
  ///
  /// A partial or nonsensical geometry is discarded rather than repaired: the
  /// app opening at its default size is a much better outcome than opening
  /// one pixel tall, or off the side of a monitor that is no longer attached.
  static WindowGeometry? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final x = _readNum(json['x']);
    final y = _readNum(json['y']);
    final width = _readNum(json['w']);
    final height = _readNum(json['h']);
    if (x == null || y == null || width == null || height == null) {
      return null;
    }
    if (width < _minSize || height < _minSize) {
      return null;
    }
    return WindowGeometry(
      x: x,
      y: y,
      width: width,
      height: height,
      maximized: json['maximized'] == true,
    );
  }

  static const double _minSize = 200;

  /// Left edge, in logical pixels.
  final double x;

  /// Top edge, in logical pixels.
  final double y;

  /// Width in logical pixels.
  final double width;

  /// Height in logical pixels.
  final double height;

  /// Whether the window was maximized.
  final bool maximized;

  /// This geometry as JSON.
  Map<String, Object?> toJson() => <String, Object?>{
    'x': x,
    'y': y,
    'w': width,
    'h': height,
    'maximized': maximized,
  };

  static double? _readNum(Object? value) => switch (value) {
    final double d when d.isFinite => d,
    final int i => i.toDouble(),
    _ => null,
  };
}

/// One document in the open set, as the session remembers it.
class SessionDocument {
  /// Creates an entry.
  const SessionDocument({
    required this.path,
    this.scroll = 0,
    this.pinned = false,
  });

  /// Reads an entry from [json], or returns `null` if it has no usable path.
  static SessionDocument? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final path = json['path'];
    if (path is! String || path.trim().isEmpty) {
      return null;
    }
    final scroll = switch (json['scroll']) {
      final double d when d.isFinite => d,
      final int i => i.toDouble(),
      _ => 0.0,
    };
    return SessionDocument(
      path: path,
      scroll: scroll < 0 ? 0 : (scroll > 1 ? 1 : scroll),
      pinned: json['pinned'] == true,
    );
  }

  /// Absolute path of the document.
  final String path;

  /// Scroll position as a 0..1 ratio.
  ///
  /// A ratio rather than an offset so it survives a zoom change or a small
  /// edit; doc 03's nearest-heading anchor refines it after an external change.
  final double scroll;

  /// Whether the tab is pinned.
  final bool pinned;

  /// This entry as JSON.
  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'scroll': scroll,
    'pinned': pinned,
  };
}

/// Everything in `session.json` (`docs/05_SESSION_AND_SETTINGS.md`).
///
/// Reading is total, like `AppSettings`: an entry that cannot be understood is
/// dropped and the rest of the session still restores. Losing one tab is a far
/// better outcome than losing the session (rule 9).
class SessionState {
  /// Creates a session.
  const SessionState({
    this.window,
    this.sidebarWidth = 280,
    this.outlineVisible = true,
    this.openRoots = const <String>[],
    this.documents = const <SessionDocument>[],
    this.activePath,
    this.recent = const <String>[],
  });

  /// Reads a session from [json].
  factory SessionState.fromJson(Map<String, Object?> json) {
    const fallback = SessionState.empty;
    final documents = <SessionDocument>[
      for (final entry in _readList(json['files']))
        ?SessionDocument.fromJson(entry),
    ];
    final paths = <String>{for (final document in documents) document.path};
    final active = json['activePath'];

    return SessionState(
      window: WindowGeometry.fromJson(json['window']),
      sidebarWidth: _readWidth(json['sidebarWidth'], fallback.sidebarWidth),
      outlineVisible: json['outlineVisible'] is bool
          ? json['outlineVisible']! as bool
          : fallback.outlineVisible,
      openRoots: _readPaths(json['openRoots']),
      documents: documents,
      // An active path naming a document that is not in the open set would
      // leave the reader pointing at nothing.
      activePath: active is String && paths.contains(active) ? active : null,
      recent: _readPaths(json['recent']),
    );
  }

  /// The empty session, used for a first run and after a corrupt file.
  static const SessionState empty = SessionState();

  /// The schema version this code writes.
  static const int schemaVersion = 1;

  /// Smallest sidebar width that is still usable.
  static const double minSidebarWidth = 120;

  /// Largest sidebar width that leaves room to read.
  static const double maxSidebarWidth = 800;

  /// Where the window was, or `null` to use the default placement.
  final WindowGeometry? window;

  /// Sidebar width in logical pixels.
  final double sidebarWidth;

  /// Whether the outline panel was open.
  final bool outlineVisible;

  /// Folder roots, which drive the sidebar tree and the watchers.
  final List<String> openRoots;

  /// The flat open set — ad-hoc files and files opened from roots alike.
  final List<SessionDocument> documents;

  /// Which document was active, or `null`.
  final String? activePath;

  /// Recently opened paths, most recent first.
  final List<String> recent;

  /// This session as JSON, including the schema version.
  Map<String, Object?> toJson() => <String, Object?>{
    'version': schemaVersion,
    'window': ?window?.toJson(),
    'sidebarWidth': sidebarWidth,
    'outlineVisible': outlineVisible,
    'openRoots': openRoots,
    'files': <Map<String, Object?>>[
      for (final document in documents) document.toJson(),
    ],
    'activePath': ?activePath,
    'recent': recent,
  };

  static List<Object?> _readList(Object? value) =>
      value is List ? value : const <Object?>[];

  /// Absolute-looking, non-blank, deduped, order preserved.
  static List<String> _readPaths(Object? value) {
    final seen = <String>{};
    return <String>[
      for (final entry in _readList(value))
        if (entry is String && entry.trim().isNotEmpty && seen.add(entry))
          entry,
    ];
  }

  static double _readWidth(Object? value, double fallback) {
    final width = switch (value) {
      final double d when d.isFinite => d,
      final int i => i.toDouble(),
      _ => fallback,
    };
    return width < minSidebarWidth
        ? minSidebarWidth
        : (width > maxSidebarWidth ? maxSidebarWidth : width);
  }
}
