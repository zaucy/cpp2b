#!/usr/bin/env bash

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

ROOT_DIR=$SCRIPT_DIR

cd $ROOT_DIR

CPPFRONT=$ROOT_DIR/.cache/tools/cppfront
CPP2B_DIST=$ROOT_DIR/dist/debug/cpp2b
MODULES_DIR=$ROOT_DIR/.cache/modules

mkdir -p $ROOT_DIR/.cache/repos
mkdir -p $MODULES_DIR
mkdir -p $ROOT_DIR/.cache/tools
mkdir -p $ROOT_DIR/dist/debug
mkdir -p $ROOT_DIR/.cache/cpp2/source/src
mkdir -p $ROOT_DIR/.cache/cpp2/source/_build

CPP2B_COMPILER=${CC:=clang}

function log_info() {
    echo "INFO: $1"
}

function log_error() {
    echo "ERROR: $1"
}

function fatal() {
    echo "FATAL: $1"
    exit 1
}

if ! [ -x "$(command -v $CPP2B_COMPILER)" ]; then
    fatal "cannot find $CPP2B_COMPILER in your PATH"
fi

if ! [[ $CPP2B_COMPILER == *"clang"* ]]; then
    fatal "only clang is supported: detected $CPP2B_COMPILER"
fi

COMPILER_VERSION=$($CPP2B_COMPILER --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
COMPILER_MAJOR_VERSION=$(echo $COMPILER_VERSION | cut -d. -f1)
if [ "$COMPILER_MAJOR_VERSION" -lt 18 ]; then
    fatal "clang version 18 or newer only supported: detected $COMPILER_VERSION"
fi

if [[ -z "${CPP2B_LIBCXX_BUILD_ROOT}" ]]; then
    log_error "libcxx with module support must be built from source"
    log_error "follow these instructions https://github.com/llvm/llvm-project/blob/main/libcxx/docs/Modules.rst"
    fatal "missing CPP2B_LIBCXX_BUILD_ROOT environment variable"
fi

log_info "using libcxx build root $CPP2B_LIBCXX_BUILD_ROOT"

if ! [ -d $CPP2B_LIBCXX_BUILD_ROOT ]; then
    log_fatal "directory $CPP2B_LIBCXX_BUILD_ROOT does not exist"
fi

function ensure_gh_repo() {
    local repo=$1
    local repo_path=$ROOT_DIR/.cache/repos/$repo
    if ! [ -d $repo_path ]; then
        mkdir -p $repo_path
        git clone --quiet --depth=1 --filter=blob:none --sparse https://github.com/$repo $repo_path
    fi
}

function ensure_gh_repo_subdir() {
    local repo=$1
    local repo_path=$ROOT_DIR/.cache/repos/$repo
    local repo_subdir=$2
    local repo_subdir_path=$repo_path/$repo_subdir
    if ! [ -d $repo_subdir_path ]; then
        cd $repo_path
        log_info "checking out repo $repo/$reposubdir"
        git sparse-checkout add $repo_subdir
        cd $ROOT_DIR
    fi
}

ensure_gh_repo "hsutter/cppfront"
ensure_gh_repo_subdir "hsutter/cppfront" "source"
ensure_gh_repo_subdir "hsutter/cppfront" "include"

CPPFRONT_INCLUDE_DIR=$ROOT_DIR/.cache/repos/hsutter/cppfront/include

LIBCXX_MODULES_DIR=$CPP2B_LIBCXX_BUILD_ROOT/modules
LIBCXX_INCLUDE_DIR=$CPP2B_LIBCXX_BUILD_ROOT/include
LIBCXX_LIB_DIR=$CPP2B_LIBCXX_BUILD_ROOT/lib

if ! [ -x $CPPFRONT ]; then
    log_info "compiling cppfront..."
    cd $ROOT_DIR/.cache/repos/hsutter/cppfront/source
    $CPP2B_COMPILER -lstdc++ -lc -lm -fuse-ld=lld -std=c++23 cppfront.cpp -o $CPPFRONT
    cd $ROOT_DIR
fi

if ! [ -f $MODULES_DIR/std.pcm ]; then
    cd $LIBCXX_MODULES_DIR/c++/v1
    log_info "compiling std module..."

    $CPP2B_COMPILER                        \
        -stdlib=libc++                       \
        -std=c++23                           \
        -fexperimental-library               \
        -isystem $LIBCXX_INCLUDE_DIR/c++/v1  \
        -Wno-reserved-module-identifier      \
        std.cppm                             \
        --precompile -o $MODULES_DIR/std.pcm

    cd $ROOT_DIR
fi

if ! [ -f $MODULES_DIR/std.compat.pcm ]; then
  cd $LIBCXX_MODULES_DIR/c++/v1
  log_info "compiling std.compat module..."

  $CPP2B_COMPILER                        \
    -stdlib=libc++                       \
    -std=c++23                           \
    -fexperimental-library               \
    -isystem $LIBCXX_INCLUDE_DIR/c++/v1  \
    -Wno-reserved-module-identifier      \
    -fprebuilt-module-path=$MODULES_DIR  \
    std.compat.cppm                      \
    --precompile -o $MODULES_DIR/std.compat.pcm

    cd $ROOT_DIR
fi

if ! [ -f $MODULES_DIR/dylib.pcm ]; then
    cd $LIBCXX_MODULES_DIR/c++/v1
    log_info "compiling dylib module..."

    $CPP2B_COMPILER                        \
        -stdlib=libc++                       \
        -std=c++23                           \
        -fexperimental-library               \
        -isystem $LIBCXX_INCLUDE_DIR/c++/v1  \
        -fprebuilt-module-path=$MODULES_DIR  \
        "$ROOT_DIR/src/dylib.cppm"           \
        --precompile -o $MODULES_DIR/dylib.pcm

    cd $ROOT_DIR
fi

log_info "compiling cpp2b module..."
if [ -f "$ROOT_DIR/.cache/cpp2/source/_build/cpp2b.cppm" ]; then
    rm "$ROOT_DIR/.cache/cpp2/source/_build/cpp2b.cppm"
fi

cat "$ROOT_DIR/share/cpp2b.cppm.tpl" | sed "s\`@CPP2B_PROJECT_ROOT@\`$ROOT_DIR\`g" > "$ROOT_DIR/.cache/cpp2/source/_build/cpp2b.cppm"
cat "$ROOT_DIR/share/cpp2b.cppm.tpl" | sed "s\`@CPP2B_COMPILER@\`clang\`g" > "$ROOT_DIR/.cache/cpp2/source/_build/cpp2b.cppm"

$CPP2B_COMPILER                                       \
    -stdlib=libc++                                    \
    -std=c++23                                        \
    -fexperimental-library                            \
    -isystem $LIBCXX_INCLUDE_DIR/c++/v1               \
    -fprebuilt-module-path=$MODULES_DIR               \
    "$ROOT_DIR/.cache/cpp2/source/_build/cpp2b.cppm"  \
    --precompile -o $MODULES_DIR/cpp2b.pcm

log_info "running cppfront..."
$CPPFRONT src/main.cpp2 -pure -import-std -l -format-colon-errors -o "$ROOT_DIR/.cache/cpp2/source/src/main.cpp"

log_info "compiling..."
$CPP2B_COMPILER                                   \
    -stdlib=libc++                                \
    "$MODULES_DIR/cpp2b.pcm"                      \
    "$MODULES_DIR/dylib.pcm"                      \
    "$MODULES_DIR/std.compat.pcm"                 \
    "$ROOT_DIR/.cache/cpp2/source/src/main.cpp"   \
    -std=c++23                                    \
    -fexperimental-library                        \
    -Wno-unused-result                            \
    -Wno-deprecated-declarations                  \
    -fprebuilt-module-path=$MODULES_DIR           \
    -L$LIBCXX_LIB_DIR                             \
    -isystem $LIBCXX_INCLUDE_DIR/c++/v1           \
    -lc++abi                                      \
    -lc++                                         \
    -lm                                           \
    -static                                       \
    -fuse-ld=lld                                  \
    -I"$CPPFRONT_INCLUDE_DIR"                     \
    -o $CPP2B_DIST

log_info "successfully built $CPP2B_DIST"
