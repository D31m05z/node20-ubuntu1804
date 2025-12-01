# Base image
FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
    wget curl llvm tk-dev libncurses5-dev libncursesw5-dev \
    libffi-dev liblzma-dev git make bison gawk python-openssl xz-utils \
    software-properties-common gnupg \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# -----------------------------
# Install pyenv + Python 3.10
# -----------------------------
ENV PYENV_ROOT="/opt/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"

# Clone pyenv
RUN git clone https://github.com/pyenv/pyenv.git "$PYENV_ROOT"

# Install Python 3.10.13
RUN set -eux; \
    export PYTHON_CONFIGURE_OPTS="--enable-optimizations --with-lto"; \
    export MAKEFLAGS="-j$(nproc)"; \
    eval "$(pyenv init -)"; \
    pyenv install 3.10.13; \
    pyenv global 3.10.13; \
    rm -rf "$PYENV_ROOT/versions/3.10.13/lib/python3.10/test" \
           "$PYENV_ROOT/versions/3.10.13/lib/python3.10/lib2to3"

# Make pyenv available globally
RUN echo 'export PYENV_ROOT="/opt/.pyenv"' >> /etc/profile.d/pyenv.sh && \
    echo 'export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"' >> /etc/profile.d/pyenv.sh && \
    echo 'eval "$(pyenv init -)"' >> /etc/profile.d/pyenv.sh

# -----------------------------
# Install Clang 16
# -----------------------------
RUN curl -sSL https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - && \
    add-apt-repository "deb http://apt.llvm.org/bionic/ llvm-toolchain-bionic-16 main" && \
    apt-get update && apt-get install -y clang-16 lldb-16 lld-16 \
    && update-alternatives --install /usr/bin/clang clang /usr/bin/clang-16 100 \
    && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-16 100

# Verify Clang
RUN clang --version && clang++ --version

# Install GCC13 to get modern libstdc++
RUN add-apt-repository ppa:ubuntu-toolchain-r/test -y && \
    apt-get update && \
    apt-get install -y g++-13 libstdc++-13-dev && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 90 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 90

# -----------------------------
# Build Node 24 using Clang 16
# -----------------------------

# Build Node using Clang + new stdlib
ENV CXX="clang++-16"
ENV CC="clang-16"
ENV GCC_TOOLCHAIN_DIR=/usr
ENV CXXFLAGS="--gcc-toolchain=${GCC_TOOLCHAIN_DIR} -isystem ${GCC_TOOLCHAIN_DIR}/include/c++/13 -isystem ${GCC_TOOLCHAIN_DIR}/include/x86_64-linux-gnu/c++/13 -stdlib=libstdc++"
ENV LDFLAGS="--gcc-toolchain=${GCC_TOOLCHAIN_DIR} -L${GCC_TOOLCHAIN_DIR}/lib/x86_64-linux-gnu -Wl,-rpath=${GCC_TOOLCHAIN_DIR}/lib/x86_64-linux-gnu"
ENV CPLUS_INCLUDE_PATH="/usr/include/c++/13:/usr/include/x86_64-linux-gnu/c++/13"

# Clone Node.js repo and checkout v24.x
# RUN git clone https://github.com/nodejs/node.git /opt/node \
#     && cd /opt/node \
#     && git checkout v24.x \
#     && ./configure \
#     && make -j$(nproc) \
#     && make install

# Set default shell
CMD ["bash"]