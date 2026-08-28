import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/images/image_source.dart';
import 'package:path/path.dart' as p;

/// `docs/04_MARKDOWN_PIPELINE.md`'s image policy, and the half of
/// `docs/10_SECURITY_PRIVACY.md` invariants 3 and 4 that can be decided without
/// touching a disk: which `src` may become a file read, which may become a
/// network request, and which may become neither.
void main() {
  const document = '/docs/guide/README.md';

  ImageSource classify(String src, {String from = document}) =>
      classifyImage(src: src, documentPath: from);

  group('local', () {
    test('a relative src resolves against the document directory', () {
      final source = classify('../assets/badge.png') as LocalImageSource;

      expect(source.path, p.normalize('/docs/assets/badge.png'));
      expect(source.isSvg, isFalse);
    });

    test('every allowed extension is allowed, and svg is marked', () {
      for (final extension in imageExtensions) {
        final source = classify('pic.$extension');

        expect(source, isA<LocalImageSource>(), reason: extension);
        expect(source.isSvg, extension == 'svg', reason: extension);
      }
    });

    test('the check is case-insensitive', () {
      expect(classify('PHOTO.JPEG'), isA<LocalImageSource>());
      expect(classify('Badge.SVG').isSvg, isTrue);
    });

    test('a query string is not part of the extension', () {
      final source = classify('../assets/badge.svg?v=2') as LocalImageSource;

      expect(source.path, p.normalize('/docs/assets/badge.svg'));
      expect(source.isSvg, isTrue);
    });

    test('a space survives percent-encoding', () {
      expect(
        (classify('name%20with%20spaces.png') as LocalImageSource).path,
        p.normalize('/docs/guide/name with spaces.png'),
      );
    });

    test('an absolute path is allowed, as doc 04 says', () {
      expect(
        (classify('/var/pics/x.png') as LocalImageSource).path,
        p.normalize('/var/pics/x.png'),
      );
    });
  });

  group('outside the allowlist — invariant 3', () {
    test('a document cannot point a decoder at a non-image', () {
      for (final src in <String>[
        '../assets/document.pdf',
        '../assets/installer.exe',
        '../assets/mystery',
        '../assets/.hidden',
        '/etc/hostname',
        '../../../../../../etc/passwd',
        'notes.md',
      ]) {
        expect(classify(src), isA<UnsupportedImageSource>(), reason: src);
      }
    });

    test('the reason is carried, so the placeholder can say which', () {
      final source =
          classify('../assets/document.pdf') as UnsupportedImageSource;

      expect(source.reason, 'pdf');
      expect(source.src, '../assets/document.pdf');
    });

    test('a data: URI is refused — it is a payload, not a location', () {
      final source = classify(
        'data:image/gif;base64,R0lGODlhAQABAAAAACw=',
      ) as UnsupportedImageSource;

      expect(source.reason, 'data');
    });

    test('and so is every other scheme', () {
      for (final src in <String>[
        'file:///etc/passwd.png',
        'ftp://host/x.png',
        'javascript:alert(1)',
        'blob:https://example.com/abc.png',
      ]) {
        expect(classify(src), isA<UnsupportedImageSource>(), reason: src);
      }
    });
  });

  group('remote — invariant 4', () {
    test('http and https become a remote source, nothing else does', () {
      expect(
        classify('https://example.com/tracker.png'),
        isA<RemoteImageSource>(),
      );
      expect(
        classify('http://example.com/insecure.png'),
        isA<RemoteImageSource>(),
      );
    });

    test('a remote svg is still marked as svg', () {
      expect(classify('https://example.com/badge.svg').isSvg, isTrue);
    });

    test('a remote non-image is refused before it is a URL', () {
      expect(
        classify('https://example.com/tracker.php'),
        isA<UnsupportedImageSource>(),
      );
    });

    test('RemoteImageSource is the only variant carrying a Uri', () {
      // The structural half: the widget that can make a request takes one of
      // these, and nothing else can produce one. There is no branch to forget.
      final remote = <ImageSource>[
        classify('https://example.com/a.png'),
        classify('local.png'),
        classify('data:image/gif;base64,AA'),
        classify('//example.com/a.png'),
      ].whereType<RemoteImageSource>().toList();

      expect(remote, hasLength(1));
      expect(remote.single.uri.host, 'example.com');
    });

    test('a protocol-relative URL is not a local path', () {
      // It has no scheme, so it falls through every scheme check ever written
      // and lands in the local branch — where statting it is Windows opening
      // an SMB connection to a host the document named. The corpus has one.
      expect(
        classify('//example.com/tracker.png'),
        isA<UnsupportedImageSource>(),
      );
      expect(
        classify('//example.com/badge.svg'),
        isA<UnsupportedImageSource>(),
      );
    });

    test('and neither is a UNC path', () {
      // `Uri` does not parse backslashes at all, so this arrives looking like
      // an ordinary relative reference.
      expect(
        classify(r'\\server\share\badge.png'),
        isA<UnsupportedImageSource>(),
      );
      expect(
        classify(r'  \\server\share\x.png'),
        isA<UnsupportedImageSource>(),
      );
    });
  });

  group('rule 9 — a src is untrusted input', () {
    test('nothing throws, on anything', () {
      final nasty = <String>[
        '',
        '   ',
        '.',
        '..',
        '/',
        r'\',
        '?',
        '#',
        '%',
        '%zz',
        'a' * 100000,
        '${'../' * 5000}x.png',
        'https://${'a' * 10000}/x.png',
        '\u0000',
        'x.PNG?a=%',
      ];

      for (final src in nasty) {
        expect(
          () => classify(src),
          returnsNormally,
          reason: 'src of ${src.length} chars',
        );
      }
    });

    test('an empty src is a placeholder, not a crash', () {
      expect(classify(''), isA<UnsupportedImageSource>());
    });
  });
}
