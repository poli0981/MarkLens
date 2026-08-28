import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/core/links/link_target.dart';
import 'package:path/path.dart' as p;

/// `docs/03_DATA_FLOW.md`'s four link cases, and the half of
/// `docs/10_SECURITY_PRIVACY.md` invariant 2 that can be tested without a
/// platform: nothing but `http` and `https` ever becomes something openable.
void main() {
  const document = '/docs/guide/README.md';

  LinkTarget classify(String href, {String from = document}) =>
      classifyLink(href: href, documentPath: from);

  group('anchors', () {
    test('a bare fragment is an anchor', () {
      expect(classify('#getting-started'), isA<AnchorLink>());
      expect(
        (classify('#getting-started') as AnchorLink).slug,
        'getting-started',
      );
    });

    test('a percent-encoded fragment decodes', () {
      expect((classify('#tiếng-việt') as AnchorLink).slug, 'tiếng-việt');
      expect(
        (classify('#ti%E1%BA%BFng-vi%E1%BB%87t') as AnchorLink).slug,
        'tiếng-việt',
      );
    });

    test('an empty fragment is not a target', () {
      expect(classify('#'), isA<AnchorLink>());
      expect((classify('#') as AnchorLink).slug, '');
    });
  });

  group('documents', () {
    test('a relative link resolves against the document directory', () {
      final target = classify('../ARCHITECTURE.md') as DocumentLink;

      expect(target.path, p.normalize('/docs/ARCHITECTURE.md'));
      expect(target.anchor, isNull);
    });

    test('a sibling resolves without leaving the directory', () {
      expect(
        (classify('other.md') as DocumentLink).path,
        p.normalize('/docs/guide/other.md'),
      );
    });

    test('file.md#anchor carries both halves', () {
      final target = classify('./deep/notes.mdx#section-two') as DocumentLink;

      expect(target.path, p.normalize('/docs/guide/deep/notes.mdx'));
      expect(target.anchor, 'section-two');
    });

    test('a space in a filename survives percent-encoding', () {
      expect(
        (classify('my%20notes.md') as DocumentLink).path,
        p.normalize('/docs/guide/my notes.md'),
      );
    });

    test('a stray percent is a filename, not bad encoding', () {
      // `50%_done.md` is a real filename and not valid percent-encoding.
      // Decoding must fail soft rather than throw.
      expect(
        (classify('50%_done.md') as DocumentLink).path,
        p.normalize('/docs/guide/50%_done.md'),
      );
    });

    test('a query string is dropped rather than resolved into the name', () {
      expect(
        (classify('notes.md?v=2') as DocumentLink).path,
        p.normalize('/docs/guide/notes.md'),
      );
    });

    test('a Windows drive letter is a path, not a scheme', () {
      // `Uri` reads `C:/docs/x.md` as scheme `c`. Refusing that would refuse
      // an ordinary absolute path on the platform this app was written on.
      final target = classify('C:/docs/x.md', from: r'C:\docs\README.md');

      expect(target, isA<DocumentLink>());
    });

    test('a link to something MarkLens does not open is refused', () {
      // Doc 03 refuses rather than guessing: an image, a source file, a
      // directory. Nothing is shelled out for any of them.
      for (final href in <String>[
        'diagram.png',
        '../src/main.rs',
        'subfolder/',
        'Makefile',
      ]) {
        expect(classify(href), isA<UnsupportedLink>(), reason: href);
      }
    });

    test('the extension set is the registry, not a hardcoded list', () {
      final target = classifyLink(
        href: 'notes.rst',
        documentPath: document,
        registry: ExtensionRegistry(const <String>['rst']),
      );

      expect(target, isA<DocumentLink>());
    });
  });

  group('external', () {
    test('http and https are the whole allowlist', () {
      expect(classify('https://example.com/a'), isA<ExternalLink>());
      expect(classify('http://example.com'), isA<ExternalLink>());
      expect(externalLinkSchemes, <String>{'http', 'https'});
    });

    test('the URI arrives intact, query and fragment included', () {
      final target = classify('https://example.com/a?b=1#c') as ExternalLink;

      expect(target.uri.toString(), 'https://example.com/a?b=1#c');
    });

    test('a scheme with no host is not somewhere a browser can go', () {
      expect(classify('http:'), isA<UnsupportedLink>());
      expect(classify('https:///nowhere'), isA<UnsupportedLink>());
    });
  });

  group('refused — invariant 2', () {
    test('every dangerous scheme classifies as unsupported', () {
      const dangerous = <String>[
        'javascript:alert(1)',
        'JavaScript:alert(1)',
        'jAvAsCrIpT:alert(1)',
        'data:text/html,<script>x</script>',
        'vbscript:msgbox(1)',
        'file:///etc/passwd',
        'file://C:/Windows/System32',
        'mailto:someone@example.com',
        'tel:+1234567890',
        'ms-msdt:/id',
        'search-ms:query=x',
        'smb://host/share',
        'ftp://host/file.md',
      ];

      for (final href in dangerous) {
        final target = classify(href);
        expect(target, isA<UnsupportedLink>(), reason: href);
        expect(
          target,
          isNot(isA<ExternalLink>()),
          reason: '$href must never reach url_launcher',
        );
      }
    });

    test('and nothing but ExternalLink can carry a URI at all', () {
      // The structural half of the invariant: the launcher takes a Uri, and
      // this is the only variant that has one. There is no branch to forget.
      final carriers = <LinkTarget>[
        classify('https://example.com'),
        classify('javascript:alert(1)'),
        classify('#anchor'),
        classify('other.md'),
      ].whereType<ExternalLink>().toList();

      expect(carriers, hasLength(1));
      expect(carriers.single.uri.scheme, 'https');
    });

    test('an empty or unparseable href is refused, never followed', () {
      for (final href in <String>['', '   ', '\t\n']) {
        expect(classify(href), isA<UnsupportedLink>(), reason: 'href "$href"');
      }
    });

    test('the refusal keeps the href it refused, for the notice', () {
      final target = classify('javascript:alert(1)') as UnsupportedLink;

      expect(target.scheme, 'javascript');
      expect(target.href, 'javascript:alert(1)');
    });
  });

  group('rule 9 — a href is untrusted input', () {
    test('nothing throws, on anything', () {
      final nasty = <String>[
        '://',
        ':::',
        '%',
        '%zz',
        '%E0%A4%A',
        '#%',
        'a' * 100000,
        '${'../' * 5000}x.md',
        'https://${'a' * 10000}',
        '\u0000',
        '..',
        '.',
        '/',
        r'\',
        '?',
        '#?#',
      ];

      for (final href in nasty) {
        expect(
          () => classify(href),
          returnsNormally,
          reason: 'href of ${href.length} chars',
        );
      }
    });

    test('a traversal normalizes, and is still only ever a path', () {
      // Normalizing is not a sandbox and does not pretend to be one: the user
      // opened the linking document, and following a relative link out of its
      // folder is what a relative link is for. What matters is that it stays a
      // DocumentLink — read through FileService — and never a shell-out.
      final target = classify('../../../../etc/passwd.md') as DocumentLink;

      expect(p.isAbsolute(target.path), isTrue);
      expect(target.path, isNot(contains('..')));
    });
  });
}
