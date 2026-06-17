# =============================================================================
# Custom Node.js builder for Ubuntu 18.04 (Bionic)
#
# Why this exists:
#   * Prebuilt Node.js >= 18 from nodejs.org is linked against GLIBC_2.28+,
#     while Ubuntu 18.04 ships glibc 2.27 -> the runner fails with:
#       /__e/node20/bin/node: ... version `GLIBC_2.28' not found
#   * Building *on* bionic makes the binary link against the system glibc 2.27,
#     fixing the GLIBC problem.
#   * But a modern compiler (needed for Node 24's C++20 V8) also makes the
#     binary depend on a newer libstdc++ (GLIBCXX_3.4.3x) that stock 18.04 does
#     NOT have. We solve that by statically linking libstdc++ and libgcc, so the
#     produced `node` binary depends ONLY on bionic's glibc 2.27.
#
# Build args:
#   NODE_VERSION  e.g. v24.11.1 / v20.19.0  (must be a real nodejs.org release)
#   GCC_VERSION   e.g. 13 (for Node 24) / 10 (for Node 20)
#
# Output: /dist/node-<version>-linux-x64.tar.gz  + standalone /dist/node binary
# =============================================================================
FROM ubuntu:18.04

ARG NODE_VERSION=v24.11.1
ARG GCC_VERSION=13

ENV DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------------
# Base build dependencies
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        wget \
        xz-utils \
        git \
        make \
        pkg-config \
        software-properties-common \
        gnupg \
        # deps needed to build CPython via pyenv (build host only)
        libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
        libffi-dev liblzma-dev libncurses5-dev libncursesw5-dev tk-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Modern GCC/G++ from the Ubuntu toolchain PPA.
#   Node 24 needs >= gcc 12.2 (C++20); Node 20 builds fine with gcc 10.
#   The PPA's libstdc++ is itself built against bionic glibc, so statically
#   linking it stays glibc-2.27 compatible.
# -----------------------------------------------------------------------------
RUN add-apt-repository -y ppa:ubuntu-toolchain-r/test \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        "gcc-${GCC_VERSION}" "g++-${GCC_VERSION}" \
    && update-alternatives --install /usr/bin/gcc gcc "/usr/bin/gcc-${GCC_VERSION}" 100 \
    && update-alternatives --install /usr/bin/g++ g++ "/usr/bin/g++-${GCC_VERSION}" 100 \
    && update-alternatives --install /usr/bin/cc  cc  /usr/bin/gcc 100 \
    && update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++ 100 \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && gcc --version && g++ --version

# -----------------------------------------------------------------------------
# A modern Python (>=3.8) is required to run Node's configure/gyp.
#   Bionic only ships Python 3.6, so we build 3.10 with pyenv.
#   (No --enable-optimizations: this Python is only used to drive the build.)
# -----------------------------------------------------------------------------
ENV PYENV_ROOT="/opt/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
ARG PYTHON_VERSION=3.10.13
RUN git clone --depth 1 https://github.com/pyenv/pyenv.git "$PYENV_ROOT" \
    && MAKEFLAGS="-j$(nproc)" pyenv install "${PYTHON_VERSION}" \
    && pyenv global "${PYTHON_VERSION}" \
    && python3 --version

# -----------------------------------------------------------------------------
# Fetch, verify and build Node.js from the official source tarball.
#   LDFLAGS statically links libstdc++/libgcc so the result only needs glibc.
# -----------------------------------------------------------------------------
RUN set -eux; \
    cd /tmp; \
    curl -fsSLO "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}.tar.xz"; \
    curl -fsSLO "https://nodejs.org/dist/${NODE_VERSION}/SHASUMS256.txt"; \
    grep " node-${NODE_VERSION}.tar.xz\$" SHASUMS256.txt | sha256sum -c -; \
    tar -xf "node-${NODE_VERSION}.tar.xz"; \
    cd "node-${NODE_VERSION}"; \
    export CC="gcc-${GCC_VERSION}" CXX="g++-${GCC_VERSION}"; \
    export LDFLAGS="-static-libstdc++ -static-libgcc"; \
    ./configure --prefix=/usr/local; \
    make -j"$(nproc)"; \
    DIST="node-${NODE_VERSION}-linux-x64"; \
    make install DESTDIR=/opt/stage; \
    mkdir -p "/opt/${DIST}"; \
    cp -a /opt/stage/usr/local/. "/opt/${DIST}/"; \
    mkdir -p /dist; \
    tar -czf "/dist/${DIST}.tar.gz" -C /opt "${DIST}"; \
    cp "/opt/${DIST}/bin/node" /dist/node; \
    # -- verification: must run on this bionic image and not need newer libstdc++
    "/opt/${DIST}/bin/node" --version; \
    "/opt/${DIST}/bin/node" -e "console.log(process.versions)"; \
    echo "=== ldd ==="; ldd "/opt/${DIST}/bin/node" || true; \
    echo "=== highest GLIBC needed ==="; \
    objdump -T "/opt/${DIST}/bin/node" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1; \
    if objdump -T "/opt/${DIST}/bin/node" | grep -q GLIBCXX; then \
        echo "ERROR: binary still depends on a dynamic libstdc++ (GLIBCXX)"; exit 1; \
    else \
        echo "OK: libstdc++ is statically linked"; \
    fi; \
    cd /tmp && rm -rf "node-${NODE_VERSION}" "node-${NODE_VERSION}.tar.xz" SHASUMS256.txt /opt/stage

# The built artifacts live in /dist. Copy them out with `docker cp` (see
# build-local.sh) or with a CI `docker create`/`cp` step.
CMD ["bash", "-c", "ls -la /dist"]
