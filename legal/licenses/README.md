# Licence texts

`legal/THIRD_PARTY_NOTICES.md` names a licence per component; this directory
holds the full text of each family, which its release gate requires.

Two different jobs are done here, and they are worth keeping apart.

## The font licences ship inside the app

`OFL-1.1-NotoSans.txt`, `OFL-1.1-NotoSansJP.txt` and
`OFL-1.1-JetBrainsMono.txt` are not documentation. `pubspec.yaml` lists this
directory under `assets:`, so they travel in every artefact, and
`lib/app/license_registry.dart` reads them back out into `LicenseRegistry` so
Help → Third-party Licenses lists them. That is an obligation of the OFL: the
licence has to accompany the font.

Each is the upstream project's own file, verbatim:

| File | From |
|---|---|
| `OFL-1.1-NotoSans.txt` | `notofonts/latin-greek-cyrillic`, `OFL.txt` |
| `OFL-1.1-NotoSansJP.txt` | `notofonts/noto-cjk`, `Sans/LICENSE` |
| `OFL-1.1-JetBrainsMono.txt` | the `JetBrainsMono-2.304.zip` release, `OFL.txt` |

**`OFL-1.1-NotoSansJP.txt` carries no copyright line**, because upstream's copy
does not. The font's own `name` table gives it as *© 2014–2021 Adobe
(http://www.adobe.com/)*, and it is recorded in `THIRD_PARTY_NOTICES.md` and in
`fonts/README.md` rather than being pasted into a licence file that upstream
wrote. Editing someone else's licence text to make it tidier is worse than
annotating around it.

## The package licence families are for the record

`BSD-3-Clause.txt`, `MIT.txt` and `Apache-2.0.txt` cover the pub packages in
doc 01's dependency table. They are **not** what the app displays: Flutter seeds
`LicenseRegistry` from every package's own `LICENSE` in the dependency graph, so
Help → Third-party Licenses already shows each package's exact text — that is
what makes `NOTICES.Z` 1.4 MB in a release bundle.

Each file is a verbatim copy taken from a package this project actually ships,
so it is the text we are bound by rather than a canonical form retyped:

| File | Copied from |
|---|---|
| `BSD-3-Clause.txt` | `flutter_markdown_plus 1.0.12` |
| `MIT.txt` | `highlight 0.7.0` |
| `Apache-2.0.txt` | `desktop_drop 0.8.0` |

They therefore carry that package's copyright line. Per-component copyright and
version live in `THIRD_PARTY_NOTICES.md`; these files are the licence bodies.
