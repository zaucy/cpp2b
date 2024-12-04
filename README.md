# cpp2b - a build system for [cpp2](https://github.com/hsutter/cppfront)

:warning: This is highly experimental and a work-in-progress project that's just for fun. I do not recommend using it in any serious projects at this time.

If you don't know what cpp2 is then I highly recommend you checkout the [cppfront repository](https://github.com/hsutter/cppfront) and the [cpp2 documentation](https://hsutter.github.io/cppfront/) before continuing here.

## Goals of cpp2b

* cpp2 _only_ (no cpp1<sup>[[1]](#building-modules)</sup>)
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

### First project and how it works

A `cpp2b` project simply contains a `build.cpp2` at it's root. This file gets compiled and the `build` function is _ran_ while building your project. Inside your `build.cpp2` file you can configure your project. This configuration is very limited at this time and will be expanded more in the future. Other `*.cpp2` files are discovered and are parsed to see what kind of output file should be built. If your `.cpp2` file has a `main` function then it is assumed to be an [_executable_](#building-executables) and if it contains a `module` statement it is considered a [module](#building-modules). All output from `cpp2b` is in the directory `.cache/cpp2` and should be added to the ignore file of your source control of choice.

If you want to just get started quickly then run:

```bash
cpp2b init
```

And a simple project will be ready for you to build!

:warning: `cpp2b` clones the latest [`cppfront`](https://hsutter.github.io/cppfront/), but only if it hasn't been already fetched in your project. This means your project might break if there's a breaking change with `cppfront`. If you want update to the latest `cppfront` you must delete your `.cache/cpp2` directory or run `cpp2b clean`.

#### Building executables

Any `.cpp2` file with a `main` function under a `cpp2b` project root will be turned into an executable. By default the executables name will be the name of the `*.cpp2` source file.

```cpp2
// example.cpp2
main: () = std::println("look im writing cpp2!");

// subdir/another.cpp2
main: () = std::println("another executable already!?");
```

After running `cpp2b build` you should see 2 paths in the `.cache/cpp2/bin` directory printed for you. Notice how there is `.cache/cpp2/bin/example` and `.cache/cpp2/bin/subdir/another` (on Windows you would have `.exe` extension.)

If you want your executables (binaries) to have a different name you can configure that in your `build.cpp2`.

```cpp2
import cpp2b.build;

build: (inout b: cpp2b::build) -> void = {
	b.binary_name("example", "a.exe");         // rename to a.exe
	b.binary_name("subdir/another", "b.exe");  // rename to b.exe
}
```

Now our `example` executable will be named `a.exe` and `subdir/another` will be named `b.exe` (even on Linux!)

#### Building modules

As of writing this cpp2 doesn't support support exporting modules. See [the cppfront github issue](https://github.com/hsutter/cppfront/issues/269). For that reason `cpp2b` temporarily supports `.cppm` files as source files. Once `cppfront` supports modules directly in some capacity this support will be removed.

Any `.cppm` file with a `module` statement is considered a module.

```cpp
// somedep.cppm
export module itsme;
import std;

export void do_something() {
	std::println("message from itsms module do_something()");
}
```

This module will be named `itsme` because of the `export module` statement. The filename has nothing to do with the module name (unlike an executable.) If we now add a binary `.cpp2` file that imports `itsme` it should be discovered.

```cpp2
// example.cpp2
import itsme;

main: () = {
	std::println("look im writing cpp2!");
	do_something();
}
```

After running `cpp2b` and we run `.cache/cpp2/bin/example` (`.exe` on Windows) the output should be:

```
look im writing cpp2!
message from itsms module do_something()
```
