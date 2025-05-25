#!/usr/bin/env bash

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

ROOT_DIR=$SCRIPT_DIR

cd $ROOT_DIR

./build.sh
cp dist/debug/cpp2b ~/.local/bin/cpp2b
rm -rf ~/.local/share/cpp2b
cp -r share/cpp2b ~/.local/share
