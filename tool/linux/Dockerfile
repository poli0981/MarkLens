# Builds the Linux release artefacts on the platform floor.
#
# ubuntu:22.04 is deliberate and doc 11 explains why: an AppImage and a .deb
# inherit the glibc of the machine that built them, so building on the *oldest*
# supported base is what makes them run on newer ones. Ubuntu 22.04 is the
# charter's floor.
#
# It is a container rather than an `ubuntu-22.04` runner, which is what doc 14
# used to specify. Those runner images begin deprecation on 2026-09-17 and are
# unsupported from 2027-04-17, so a pipeline pinned to that label has a
# seven-month life. Pinning the *image* instead makes the floor a property of
# something we control, and it is the arrangement tool/goldens/ already uses for
# "the build has to be reproducible on a machine that is not this one".
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl file git unzip xz-utils zip \
      clang cmake ninja-build pkg-config libgtk-3-dev libglu1-mesa \
      dpkg-dev fakeroot desktop-file-utils \
      xvfb libgl1 libgl1-mesa-dri libglx-mesa0 \
    && rm -rf /var/lib/apt/lists/*

# xvfb is not decoration. A packaged GTK application cannot be started at all
# without a display - even `marklens --version` exits 1 with "cannot open
# display", because GTK creates the window before the Dart entrypoint ever sees
# argv - so without it the only thing a build can check about its own artefacts
# is that they are the right size. docs/12_TESTING.md's integration smoke will
# need it too.
#
# libgl1-mesa-dri and libglx-mesa0 come with it: xvfb provides a display but no
# GPU, so Flutter's Impeller backend falls back to software GL, and without a
# Mesa DRI driver that initialisation is where the process stops rather than
# fails. libgl1 alone is the loader, not a driver.

# Flutter refuses to run as root, so the whole toolchain lives under a user.
RUN useradd -ms /bin/bash builder
USER builder
WORKDIR /home/builder

ARG FLUTTER_VERSION=3.47.1
RUN curl -fsSL -o flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    && tar xf flutter.tar.xz && rm flutter.tar.xz
ENV PATH="/home/builder/flutter/bin:${PATH}"
RUN git config --global --add safe.directory /home/builder/flutter \
    && flutter --version && flutter precache --linux
