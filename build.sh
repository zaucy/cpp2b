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

if [[ -z "$CC" ]]; then
    COMPILER_VERSION=$(clang --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    COMPILER_MAJOR_VERSION=$(echo $COMPILER_VERSION | cut -d. -f1)
    if [ "$COMPILER_MAJOR_VERSION" -lt 19 ]; then
        CC=clang-19
    else
        CC=clang
    fi
fi

CPP2B_COMPILER=${CC}

if ! [ -x "$(command -v $CPP2B_COMPILER)" ]; then
    fatal "cannot find $CPP2B_COMPILER in your PATH"
fi

if ! [[ $CPP2B_COMPILER == *"clang"* ]]; then
    fatal "only clang is supported: detected $CPP2B_COMPILER"
fi

COMPILER_VERSION=$($CPP2B_COMPILER --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
COMPILER_MAJOR_VERSION=$(echo $COMPILER_VERSION | cut -d. -f1)
if [ "$COMPILER_MAJOR_VERSION" -lt 19 ]; then
    fatal "clang version 19 or newer only supported: detected $COMPILER_VERSION"
fi

log_info "using compiler '$CPP2B_COMPILER' version '$COMPILER_VERSION'"

function ensure_gh_repo() {
    local repo=$1
    local branch=$2
    local repo_path=$ROOT_DIR/.cache/repos/$repo
    if ! [ -d $repo_path ]; then
        mkdir -p $repo_path
        git clone --quiet --depth=1 --branch=$branch --filter=blob:none --sparse https://github.com/$repo $repo_path
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

ensure_gh_repo "hsutter/cppfront" "v0.8.1"
ensure_gh_repo_subdir "hsutter/cppfront" "source"
ensure_gh_repo_subdir "hsutter/cppfront" "include"

CPPFRONT_INCLUDE_DIR=$ROOT_DIR/.cache/repos/hsutter/cppfront/include

LLVM_ROOT=/usr/lib/llvm-$COMPILER_MAJOR_VERSION

if ! [ -x $CPPFRONT ]; then
    log_info "compiling cppfront..."
    cd $ROOT_DIR/.cache/repos/hsutter/cppfront/source
    $CPP2B_COMPILER \
        -std=c++23                                    \
        -stdlib=libc++                                \
        -fexperimental-library                        \
        -Wno-unused-result                            \
        -Wno-deprecated-declarations                  \
        -fprebuilt-module-path=$MODULES_DIR           \
        -L$LLVM_ROOT/lib                              \
        -isystem $LLVM_ROOT/include/c++/v1            \
        -lc++abi                                      \
        -lc++                                         \
        -lm                                           \
        -static                                       \
        -fuse-ld=lld                                  \
        -I"$CPPFRONT_INCLUDE_DIR"                     \
        cppfront.cpp -o $CPPFRONT
    cd $ROOT_DIR
fi

if ! [ -f $MODULES_DIR/std.pcm ]; then
    cd $LLVM_ROOT/share/libc++/v1
    log_info "compiling std module..."

    $CPP2B_COMPILER                        \
        -stdlib=libc++                       \
        -std=c++23                           \
        -fexperimental-library               \
        -isystem $LLVM_ROOT/include/c++/v1  \
        -Wno-reserved-module-identifier      \
        std.cppm                             \
        --precompile -o $MODULES_DIR/std.pcm

    cd $ROOT_DIR
fi

if ! [ -f $MODULES_DIR/std.compat.pcm ]; then
  cd $LLVM_ROOT/share/libc++/v1
  log_info "compiling std.compat module..."

  $CPP2B_COMPILER                        \
    -stdlib=libc++                       \
    -std=c++23                           \
    -fexperimental-library               \
    -isystem $LLVM_ROOT/include/c++/v1  \
    -Wno-reserved-module-identifier      \
    -fprebuilt-module-path=$MODULES_DIR  \
    std.compat.cppm                      \
    --precompile -o $MODULES_DIR/std.compat.pcm

    cd $ROOT_DIR
fi

if ! [ -f $MODULES_DIR/dylib.pcm ]; then
    log_info "compiling dylib module..."

    $CPP2B_COMPILER                        \
        -stdlib=libc++                       \
        -std=c++23                           \
        -fexperimental-library               \
        -isystem $LLVM_ROOT/include/c++/v1  \
        -fprebuilt-module-path=$MODULES_DIR  \
        "$ROOT_DIR/src/dylib.cppm"           \
        --precompile -o $MODULES_DIR/dylib.pcm

    cd $ROOT_DIR
fi

if ! [ -f $MODULES_DIR/nlohmann.json.pcm ]; then
    log_info "compiling nlohmann.json module..."

    $CPP2B_COMPILER                        \
        -stdlib=libc++                       \
        -std=c++23                           \
        -fexperimental-library               \
        -isystem $LLVM_ROOT/include/c++/v1  \
        -fprebuilt-module-path=$MODULES_DIR  \
        "$ROOT_DIR/src/nlohmann.json.cppm"           \
        --precompile -o $MODULES_DIR/nlohmann.json.pcm

    cd $ROOT_DIR
fi

log_info "compiling cpp2b module..."
if [ -f "$ROOT_DIR/.cache/cpp2/source/_build/cpp2b.cppm" ]; then
    rm "$ROOT_DIR/.cache/cpp2/source/_build/cpp2b.cppm"
fi

cat "$ROOT_DIR/share/cpp2b/cpp2b.cppm.tpl" | sed "s\`@CPP2B_PROJECT_ROOT@\`$ROOT_DIR\`g" > "$ROOT_DIR/.cache/cpp2/source/_build/cpp2b.cppm"

$CPP2B_COMPILER                                       \
    -stdlib=libc++                                    \
    -std=c++23                                        \
    -fexperimental-library                            \
    -isystem $LLVM_ROOT/include/c++/v1                \
    -fprebuilt-module-path=$MODULES_DIR               \
    "$ROOT_DIR/.cache/cpp2/source/_build/cpp2b.cppm"  \
    --precompile -o $MODULES_DIR/cpp2b.pcm

log_info "running cppfront..."
$CPPFRONT src/main.cpp2 -pure -import-std -l -format-colon-errors -o "$ROOT_DIR/.cache/cpp2/source/src/main.cpp"

log_info "compiling..."
$CPP2B_COMPILER                                   \
    -g                                            \
    -stdlib=libc++                                \
    "$MODULES_DIR/cpp2b.pcm"                      \
    "$MODULES_DIR/dylib.pcm"                      \
    "$MODULES_DIR/std.compat.pcm"                 \
    "$MODULES_DIR/nlohmann.json.pcm"              \
    "$ROOT_DIR/.cache/cpp2/source/src/main.cpp"   \
    -std=c++23                                    \
    -fexperimental-library                        \
    -Wno-unused-result                            \
    -Wno-deprecated-declarations                  \
    -fprebuilt-module-path=$MODULES_DIR           \
    -L$LLVM_ROOT/lib                              \
    -isystem $LLVM_ROOT/include/c++/v1            \
    -lc++abi                                      \
    -lc++                                         \
    -lm                                           \
    -static                                       \
    -fuse-ld=lld                                  \
    -I"$CPPFRONT_INCLUDE_DIR"                     \
    -o $CPP2B_DIST

log_info "successfully built $CPP2B_DIST"
