#!/bin/bash
#
# Nim CI: purge cache
#
# Copyright 2016 Federico Ceratto <federico.ceratto@gmail.com>
# Released under GPLv3 License, see LICENSE file

set -ux

source nim_ci_params

echo -e "\nCache:\n"

ls -ltr $cache_dir

echo -e "\nPurging cache:\n"

rm -rf $cache_dir

mkdir -p $cache_dir
