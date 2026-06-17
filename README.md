# Custom Node.js Build for Ubuntu 18.04

### Release Description

**Custom Node.js Build for Ubuntu 18.04**

This release provides a custom build of Node.js for Ubuntu 18.04 (Bionic Beaver) to ensure compatibility with GitHub Actions runners. The build uses GCC 10.3.0 to address compatibility issues with GLIBC versions.

**System Information:**
```
Distributor ID:    Ubuntu
Description:       Ubuntu 18.04.6 LTS
Release:           18.04
Codename:          bionic
```

**GCC Version:**
```
gcc (Ubuntu 10.3.0-1ubuntu1~18.04~1) 10.3.0
Copyright (C) 2020 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
```

## Automated build (Node 20 **and** Node 24)

GitHub Actions deprecated the Node 16/20 action runtime, so actions now ship a
Node 24 runtime. Ubuntu 18.04 has no usable prebuilt Node 24 because:

1. **glibc** — nodejs.org binaries are linked against `GLIBC_2.28`+, but bionic
   ships glibc `2.27` → `version 'GLIBC_2.28' not found`.
2. **libstdc++** — Node 24's V8 needs a C++20 compiler (gcc 12+), and a binary
   built with it normally depends on a newer `GLIBCXX_3.4.3x` than bionic has.

This repo solves both:

* It builds **on** Ubuntu 18.04, so the binary links against the system glibc
  `2.27` (fixes #1).
* It statically links `libstdc++`/`libgcc` (`LDFLAGS="-static-libstdc++
  -static-libgcc"`), so the binary carries its own C++ runtime and only needs
  glibc `2.27` (fixes #2). The Dockerfile asserts this at build time and fails
  if any `GLIBCXX` dynamic dependency remains.

### Files

| File | Purpose |
| --- | --- |
| `Dockerfile` | Parameterized bionic builder (`NODE_VERSION`, `GCC_VERSION`). Outputs to `/dist`. |
| `build-local.sh` | Build locally via Docker (works on macOS/Apple Silicon) → `./dist/<target>/`. |
| `.github/workflows/build-node.yml` | Matrix build of Node 20 (gcc 10) + Node 24 (gcc 13); uploads artifacts and can publish a Release. |

### Build locally

```bash
./build-local.sh node24      # Node 24 with gcc-13  -> ./dist/node24/
./build-local.sh node20      # Node 20 with gcc-10  -> ./dist/node20/
./build-local.sh both        # build both
./build-local.sh v22.14.0 12 # any version / gcc
```

Each output dir contains the full `node-<version>-linux-x64.tar.gz` and a
standalone `node` binary.

### Build in CI

Run the **"Build custom Node.js for Ubuntu 18.04"** workflow via
*workflow_dispatch* (pick the Node 20/24 tags, optionally publish a Release), or
push a `v*` tag to build + release both automatically.

### Use it on a runner

Drop the standalone binary in place of the runner's externals node, e.g.:

```bash
# inside an ubuntu:18.04 job container, before steps run
cp node-node24-linux-x64 /__e/node24/bin/node   # or /__e/node20/bin/node
chmod +x /__e/node24/bin/node
/__e/node24/bin/node --version
```

<details>
<summary>Original manual GCC-10 build script (Node 20, for reference)</summary>

```bash
apt-get update
apt-get install -y software-properties-common
add-apt-repository -y ppa:ubuntu-toolchain-r/test
apt-get update
apt install -y gcc-10 g++-10
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 30
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 30
apt-get install -y build-essential python3-distutils git
export LDFLAGS="-static-libstdc++ -static-libgcc"
./configure
make -j$(nproc)
make install
```
</details>

**Purpose:**
This custom build is a workaround for the following issue encountered on GitHub Actions runners:
```
/__e/node20/bin/node: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.28' not found (required by /__e/node20/bin/node)
```
By using GCC 10.3.0, this build ensures compatibility with the GLIBC version available in Ubuntu 18.04, allowing Node.js 20 to run without encountering the GLIBC version error.

### Summary

This release provides a custom Node.js build for Ubuntu 18.04 to ensure compatibility with GitHub Actions runners. The build uses GCC 10.3.0 to address compatibility issues with GLIBC versions, allowing Node.js 20 to run on Ubuntu 18.04 without encountering the GLIBC version error. The provided build script automates the installation of GCC 10, the removal of previous alternatives, and the building of Node.js from source.


### Actions for testing node20

```
name: 👾 test-k8s-actions-node20

on:
  workflow_dispatch:
    inputs:
      infinite_loop:
        description: 'Run forever for testing purposes'
        required: false
        default: false
        type: boolean

jobs:
  test-1:
    name: K8S Action - Test - 1
    runs-on: k8s-runner-test
    container:
      image: ubuntu:18.04
    environment:
      name: infra-checks
    steps:
    - name: Install gcc10 for node20
      run: |
        # Add the repository for GCC 10
        apt-get update && apt-get install -y software-properties-common
        add-apt-repository ppa:ubuntu-toolchain-r/test
        apt-get update

        # Install the necessary GCC libraries
        apt-get install -y libstdc++-10-dev

    - name: Checkout
      uses: actions/checkout@v4
      with:
        lfs: false
        submodules: false
        sparse-checkout: |
          README.md
    - name: Test Base - 1 ✅
      run: |
        whoami
        printenv | sort
        uname -a
        nproc && free -h
        df -h
        ls -la
        pwd
    - name: Infinite Loop
      if: ${{ inputs.infinite_loop == true }}
      run: |
        while sleep 10; do echo "thinking 🤔"; done
  test-2:
    name: K8S Action - Test - 2
    runs-on: k8s-runner-test
    container:
      image: ubuntu:22.04
    environment:
      name: infra-checks
    steps:
    - name: Checkout
      uses: actions/checkout@v4
      with:
        lfs: false
        submodules: false
        sparse-checkout: |
          README.md
    - name: Test Base - 1 ✅
      run: |
        whoami
        printenv | sort
        uname -a
        nproc && free -h
        df -h
        ls -la
        pwd
    - name: Infinite Loop
      if: ${{ inputs.infinite_loop == true }}
      run: |
        while sleep 10; do echo "thinking 🤔"; done
```
