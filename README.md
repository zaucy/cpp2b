# cpp2b - a build system for [cpp2](https://github.com/hsutter/cppfront)

:warning: This is highly experimental and a work-in-progress project that's just for fun. I do not recommend using it in any serious projects at this time.

If you don't know what cpp2 is then I highly recommend you checkout the [cppfront repository](https://github.com/hsutter/cppfront) and the [cpp2 documentation](https://hsutter.github.io/cppfront/) before continuing here.

## Goals of cpp2b

* simple build system that "just works"
* C++20 module support _only_ (no legacy headers)
* support for latest compilers only
* configurable with cpp2 itself (no config files)

## Getting Started

There is no installer for `cpp2b` at this time. Instead you must compile and install it yourself. There are some convenient scripts to do that in the root of this repository, but they are not guaranteed to work since `cpp2b` and `cppfront` are changing frequently. None the less you'll find 'instructions' for Windows and Linux below.


### Installing on Windows

* [install the latest msvc](https://visualstudio.microsoft.com/downloads/)
* clone this repo
* run `.\install.cmd`

### Installing on Linux

* [install the latest clang](https://clang.llvm.org/get_started.html)
* clone this repo
* run `./install.sh`

As of writing this you'll need to manually compile libcxx with module support by [following these instructions](https://github.com/llvm/llvm-project/blob/main/libcxx/docs/Modules.rst). After which you must assign the `CPP2B_LIBCXX_BUILD_ROOT` environment variable to the folder where you built libcxx.

For example this is what I use to build libcxx on my machine running Ubuntu.

```bash
cd ~/projects
git clone https://github.com/llvm/llvm-project.git
cd llvm-project
mkdir build
CC=clang CXX=clang++ cmake -G Ninja -S runtimes -B build -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind"
ninja -C build

# install cpp2b
CPP2B_LIBCXX_BUILD_ROOT=~/projects/llvm-project/build ./install.sh
```
