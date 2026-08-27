# Regenerating goldens

Goldens are **compared on `ubuntu-latest` only** (`docs/12_TESTING.md`), so they
have to be *generated* there too. This is not a formality: when the first
goldens landed they were generated on the Windows dev machine, and four of the
five differed from the Ubuntu render byte-for-byte. They would have failed the
CI job on its first activation.

The difference is not the font — `flutter_test` substitutes its own — it is
rasterization. Nothing about the layout was wrong on either platform.

So: regenerate in a container that matches the runner, with the Flutter pin from
`docs/01_TECH_STACK.md`.

```bash
docker build -t marklens-goldens tool/goldens
```

```bash
docker run --rm -v "$PWD:/src:ro" -v "$PWD/test/goldens/goldens:/out" marklens-goldens bash -lc 'mkdir -p ~/work && cd /src && tar cf - --exclude=./.git --exclude=./build --exclude=./.dart_tool . | (cd ~/work && tar xf -) && cd ~/work && flutter pub get >/dev/null && flutter test --tags golden --exclude-tags watcher-live --update-goldens && cp test/goldens/goldens/*.png /out/'
```

The repo is copied into the container rather than mounted read-write on purpose:
`flutter pub get` would otherwise leave a Linux `.dart_tool` in the working tree
and the next Windows run would have to redo it.

Drop `--update-goldens` to check the committed references instead of rewriting
them — which is what CI does.
