#!/bin/bash
#
# Nim CI: Test Nim package installation
#
# Copyright 2016 Federico Ceratto <federico.ceratto@gmail.com>
# Released under GPLv3 License, see LICENSE file

source nim_ci_params

echo -e "\nFetching Nimble packages list\n"
wget https://raw.githubusercontent.com/nim-lang/packages/master/packages.json

echo -e "\nStarting package install test\n"
test -d "$cache_dir"
test -d "$cache_dir/Nim"
test -d "$cache_dir/Nim/bin"
ls "$cache_dir/Nim/bin"
export PATH=$PATH:$cache_dir/Nim/bin
$cache_dir/Nim/bin/nim c -r nimble_install_test.nim
