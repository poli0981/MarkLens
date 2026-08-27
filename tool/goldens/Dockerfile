# Regenerates MarkLens goldens on the same OS the CI golden job uses
# (ubuntu-latest) with the exact Flutter pin from docs/01_TECH_STACK.md.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl git unzip xz-utils zip ca-certificates libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

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
    && flutter --version && flutter precache --universal
