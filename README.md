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


```
docker pull --platform linux/amd64 ubuntu:18.04
docker run --platform linux/amd64 -it --rm -v $PWD:$PWD -w $PWD ubuntu:18.04 bash
```

**Build Script:**
```bash
# Update the package list and install prerequisites
apt-get update
apt-get install -y software-properties-common

# Add the repository for GCC 10
add-apt-repository -y ppa:ubuntu-toolchain-r/test
apt-get update

# Install GCC 10 and G++ 10
apt install -y gcc-10 g++-10

# Remove previous alternatives
update-alternatives --remove-all gcc
update-alternatives --remove-all g++

# Define the new compiler alternatives
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 30
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 30
update-alternatives --install /usr/bin/cc cc /usr/bin/gcc 30
update-alternatives --set cc /usr/bin/gcc
update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++ 30
update-alternatives --set c++ /usr/bin/g++

# Confirm and update alternatives (optional)
update-alternatives --config gcc
update-alternatives --config g++

# Install build dependencies
apt-get install -y build-essential python3-distutils git

# Clone the Node.js repository and checkout the desired version
git clone --depth 1 --branch v20.19.1 https://github.com/nodejs/node
cd node

# Configure and build Node.js
./configure
make -j$(nproc) # Use all available CPU cores

# Optionally, install Node.js
make install
```

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
