#!/bin/bash
#
# Nim CI: build and test Nim
#
# Copyright 2016 Federico Ceratto <federico.ceratto@gmail.com>
# Released under GPLv3 License, see LICENSE file

set -ue

source nim_ci_params


run_release_and_install_test() {

    mkdir -p "$artifacts_output_dir"

    echo -e "\nCloning Nim repo\n"
    git clone -q --depth 1 https://github.com/nim-lang/Nim.git
    echo -e "\nCloning csources\n"
    cd Nim
    git clone --depth 1 https://github.com/nim-lang/csources.git

    echo -e "\nBuilding csources\n"
    ( cd csources && sh build.sh )
    sed -i -e 's,cc = gcc,cc = clang,' config/nim.cfg
    export PATH=$(pwd)/bin${PATH:+:$PATH}
    echo -e "\nBuilding koch\n"
    nim c koch
    echo -e "\nRunning koch boot\n"
    ./koch boot
    ./koch boot -d:release
    ./koch nimble
    nim e tests/test_nimscript.nims
    nimble install zip -y
    nimble install opengl
    nimble install sdl1
    nimble install jester@#head
    nimble install niminst
    nim c --taintMode:on -d:nimCoroutines tests/testament/tester
    tests/testament/tester --pedantic all -d:nimCoroutines
    echo -e "\nRunning koch web\n"
    ./koch web
    ./koch csource
    ./koch nimsuggest

    # Copy koch web outputs into artifact dir
    cp -a doc "$artifacts_output_dir"
    cp -a web "$artifacts_output_dir"

    # Success: save Nim in cache
    cd ..
    mkdir -p $cache_dir
    rm $cache_dir/Nim -rf
    mv Nim $cache_dir/
    cd "$cache_dir/Nim"

    echo -e "\nRebuilding csources\n"
    mv csources csources.old
    ./koch csources -d:release

    echo -e "\nBuilding release tarball\n"
    ./koch xz

    echo -e "\nPublishing tarball\n"
    tarball_fname=$(ls $cache_dir/Nim/build/nim*tar.xz)
    echo $tarball_fname > "$artifacts_output_dir"/release_tarball_name
    cp $tarball_fname "$artifacts_output_dir"

    echo -e "\nSigning tarball\n"
    set +x
    if [ -n "$GPG_BUILD_SIGN_PASSPHRASE" ]; then
        # user id: "Nim CircleCI builder"
        gpg --yes --batch --import $private_key_fname
        gpg --detach-sig --no-use-agent --yes --batch \
            --passphrase=$GPG_BUILD_SIGN_PASSPHRASE \
            --sign --armor $tarball_fname
        cp $tarball_fname.asc "$artifacts_output_dir"

    fi
    set -x

    echo -e "\nLooking for unexpected files in the tarball\n"
    rm -f $unexpected_files
    touch $unexpected_files
    #TODO: unpack tarball
    find . -executable -type f -not -name '*.sh' >> $unexpected_files
    find . -name '*.o' -not -path './icons/*_icon.o' >> $unexpected_files
    find . -name '.DS_Store' >> $unexpected_files
    find doc -name '*.html' >> $unexpected_files

    if [[ -s $unexpected_files ]]; then
        echo "ERROR: Unexpected files found:"
        cat $unexpected_files
    fi


#    echo -e "\nRunning testinstall \n"
#    ./koch testinstall
#
#    let destDir = getTempDir()
#    copyFile("build/nim-$1.tar.xz" % VersionAsString,
#             destDir / "nim-$1.tar.xz" % VersionAsString)
#    setCurrentDir(destDir)
#    execCleanPath("tar -xJf nim-$1.tar.xz" % VersionAsString)
#    setCurrentDir("nim-$1" % VersionAsString)
#    execCleanPath("sh build.sh")
#    # first test: try if './bin/nim --version' outputs something sane:
#    let output = execProcess("./bin/nim --version").splitLines
#    if output.len > 0 and output[0].contains(VersionAsString):
#      echo "Version check: success"
#      execCleanPath("./bin/nim c koch.nim")
#      execCleanPath("./koch boot -d:release", destDir / "bin")
#      # check the docs build:
#      execCleanPath("./koch web", destDir / "bin")
#      # check the tests work:
#      execCleanPath("./koch tests", destDir / "bin")
#    else:
#      echo "Version check: failure"

}

run_release_and_install_test
