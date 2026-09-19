# syntax=docker/dockerfile:1
#
# EDL — official container image
#
# Publishes the EDL compiler as:
#   ghcr.io/skygenesisenterprise/edl
# with tags: <version> (e.g. 0.1.0), <major.minor> (0.1), latest
#
# `edl run` is a direct interpreter and needs nothing but the edlc binary.
# `edl build` still lowers to bootstrap source and compiles it with the Nim
# bootstrap substrate (a temporary, documented dependency — see
# specs/bootstrap-references.md), so the image also carries the substrate next to
# the compiler and points EDL_BOOTSTRAP at it. When the substrate is replaced by
# a native EDL backend, EDL_BOOTSTRAP and /opt/edl-bootstrap are removed.

FROM debian:bookworm-slim AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         build-essential git make ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

# Build the bootstrap substrate (./build_all.sh) and then the EDL compiler
# (edl/scripts/build.sh). This is the same, verified path used locally and by
# .github/workflows/release.yml.
RUN ./build_all.sh \
    && edl/scripts/build.sh \
    && test -x build/edl/edlc

FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/edl-bootstrap/bin

COPY --from=build /src/build/edl/edlc /usr/local/bin/edlc
# The bootstrap substrate (compiler + its standard library and config) in a
# self-contained prefix so `edl build` can invoke it from any working directory.
COPY --from=build /src/bin/nim /opt/edl-bootstrap/bin/nim
COPY --from=build /src/lib /opt/edl-bootstrap/lib
COPY --from=build /src/config /opt/edl-bootstrap/config

# Transitional: tells the driver where the bootstrap compiler lives.
ENV EDL_BOOTSTRAP=/opt/edl-bootstrap/bin/nim

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/edlc"]
CMD ["help"]