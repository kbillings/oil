#!/usr/bin/env bash
#
# Run the osh parser on shell scripts found in the wild.
#
# Usage:
#   ./wild.sh <function name>
#
# TODO:
# - There are a lot of hard-coded source paths here.  These files could
# published in a tarball or torrent.
#
# - Combine FILES.html and FAILED.html: need a table like wild.sh.
# - Add ability to do them in parallel
# - Add ability to parse them only
#   - right now we have 3 actions: test AST, html AST, and osh-to-oil.  This
#     does a lot of redundant work.
# - Archive them all into a big tarball?
#
# Maybe have an overall overview page?  Like the spec tests?
# project/
#
# Instead of '%P' then format should be '%p %P' I think?  And maybe add the
# size?

set -o nounset
set -o pipefail
set -o errexit

source test/wild-runner.sh


readonly RESULT_DIR=_tmp/wild

#
# Helpers
#

# generic helper
_parse-project() {
  local src=$1
  local name=$(basename $src)

  time _parse-many \
    $src \
    $RESULT_DIR/$name \
    $(find $src -name '*.sh' -a -printf '%P\n')
}

_parse-configure-scripts() {
  local src=$1
  local name=$(basename $src)

  time _parse-many \
    $src \
    $RESULT_DIR/$name-configure-parsed \
    $(find $src -name 'configure' -a -printf '%P\n')
}

#
# Corpora
#

# TODO: Where do we write the base dir?
oil-sketch-manifest() {
  local base_dir=~/git/oil-sketch
  pushd $base_dir >/dev/null
  for name in *.sh {awk,demo,make,misc,regex,tools}/*.sh; do
    echo oil-sketch $base_dir/$name $name
  done
  popd >/dev/null
}

oil-manifest() {
  local base_dir=$PWD
  for name in \
    configure install *.sh {benchmarks,build,test,scripts,opy}/*.sh; do
    echo oil $base_dir/$name $name
  done
}

_manifest() {
  local name=$1
  local base_dir=$2
  shift 2

  for path in "$@"; do
    echo $name $base_dir/$path $path
  done
}

# generic helper
_simple-manifest() {
  local base_dir=$1
  shift

  local name=$(basename $base_dir)
  _manifest $name $base_dir \
    $(find $base_dir -name '*.sh' -a -printf '%P\n')
}

readonly ABORIGINAL_DIR=~/src/aboriginal-1.4.5

all-manifests() {
  oil-sketch-manifest
  oil-manifest

  local src

  src=$ABORIGINAL_DIR
  _manifest aboriginal $src \
    $(find $src -name '*.sh' -printf '%P\n')

  src=/etc/init.d
  _manifest initd $src \
    $(find $src -type f -a -executable -a -printf '%P\n')

  src=/usr/bin
  _manifest usr-bin $src \
    $(find $src -name '*.sh' -a -printf '%P\n')

  src=~/git/other/dokku
  _manifest dokku $src \
    $(find $src '(' -name '*.sh' -o -name dokku ')' -a -printf '%P\n')

  # NOTE: These scripts don't end with *.sh
  src=~/git/other/pixelb-scripts
  _manifest pixelb-scripts $src \
    $(find $src \( -name .git -a -prune \) -o \
                \( -type f -a -executable -a -printf '%P\n' \) )

  _simple-manifest ~/git/other/wwwoosh
  _simple-manifest ~/git/other/git
  _simple-manifest ~/git/other/mesos
  _simple-manifest ~/git/other/mesos
}

write-all-manifests() {
  mkdir -p _tmp/wild
  all-manifests > _tmp/wild/MANIFEST.txt
  wc -l _tmp/wild/MANIFEST.txt
}

parse-pixelb-scripts() {
  local src=~/git/other/pixelb-scripts
  # NOTE: These scripts don't end with *.sh
  _parse-many \
    $src \
    $RESULT_DIR/pixelb-scripts \
    $(find $src \( -name .git -a -prune \) -o \
                \(  -type f -a -executable -a -printf '%P\n' \) )
}

parse-debootstrap() {
  # Version 1.0.89 extracts to a version-less dir.
  local src=~/git/basis-build/_tmp/debootstrap

  # NOTE: These scripts don't end with *.sh
  _parse-many \
    $src \
    $RESULT_DIR/debootstrap \
    $(find $src '(' -name debootstrap -o -name functions ')' -a -printf '%P\n') \
    $(find $src/scripts -type f -a -printf 'scripts/%P\n')
}

# WOW.  I found another lexical state in Bazel.  How to I handle this?
# Anything that's not a space?  Yeah I think after
# () is allowed as a literal
# [[ "${COMMANDS}" =~ ^$keywords(,$keywords)*$ ]] || usage "$@"

parse-git-other() {
  local src=~/git/other
  local depth=3
  _parse-many \
    $src \
    $RESULT_DIR/git-other-parsed \
    $(find $src -maxdepth $depth -name '*.sh' -a -printf '%P\n')
}

parse-hg-other() {
  local src=~/hg/other
  _parse-many \
    $src \
    $RESULT_DIR/hg-other-parsed \
    $(find $src -name '*.sh' -a -printf '%P\n')
}

parse-balls() {
  local src=~/git/other/balls

  time _parse-many \
    $src \
    $RESULT_DIR/balls-parsed \
    $(find $src '(' -name '*.sh' -o -name balls -o -name esh ')' -a \
                -printf '%P\n')
}

parse-make-a-lisp() {
  local src=~/git/other/mal/bash

  time _parse-many \
    $src \
    $RESULT_DIR/make-a-lisp-parsed \
    $(find $src '(' -name '*.sh' ')' -a -printf '%P\n')
}

parse-gherkin() {
  local src=~/git/other/gherkin

  time _parse-many \
    $src \
    $RESULT_DIR/gherkin-parsed \
    $(find $src '(' -name '*.sh' -o -name 'gherkin' ')' -a -printf '%P\n')
}

parse-lishp() {
  _parse-project ~/git/other/lishp
}

parse-bashcached() {
  local src=~/git/other/bashcached

  time _parse-many \
    $src \
    $RESULT_DIR/bashcached-parsed \
    $(find $src '(' -name '*.sh' -o -name 'bashcached' ')' -a -printf '%P\n')
}

parse-quinedb() {
  local src=~/git/other/quinedb

  time _parse-many \
    $src \
    $RESULT_DIR/quinedb-parsed \
    $(find $src '(' -name '*.sh' -o -name 'quinedb' ')' -a -printf '%P\n')
}

parse-bashttpd() {
  local src=~/git/other/bashttpd

  time _parse-many \
    $src \
    $RESULT_DIR/bashttpd \
    $(find $src -name 'bashttpd' -a -printf '%P\n')
}

parse-chef-bcpc() {
  _parse-project ~/git/other/chef-bcpc
}

parse-julia() {
  _parse-project ~/git/other/julia
}

# uses a bare "for" in a function!
parse-j() {
  local src=~/git/other/j

  time _parse-many \
    $src \
    $RESULT_DIR/j-parsed \
    $(find $src -type f -a  -name j -a -printf '%P\n')
}

# Doesn't parse because of extended glob.
parse-wd() {
  local src=~/git/other/wd

  time _parse-many \
    $src \
    $RESULT_DIR/wd \
    $(find $src -type f -a  -name wd -a -printf '%P\n')
}

parse-json-sh() {
  _parse-project ~/git/other/JSON.sh
}

# declare -a foo=(..) is not parsed right
parse-shasm() {
  _parse-project ~/git/scratch/shasm
}

parse-sandstorm() {
  _parse-project ~/git/other/sandstorm
}

parse-kubernetes() {
  _parse-project ~/git/other/kubernetes
}

parse-sdk() {
  _parse-project ~/git/other/sdk
}

# korn shell stuff
parse-ast() {
  _parse-project ~/git/other/ast
}

parse-bazel() {
  _parse-project ~/git/other/bazel
}

parse-bash-completion() {
  local src=~/git/other/bash-completion

  time _parse-many \
    $src \
    $RESULT_DIR/bash-completion-parsed \
    $(find $src/completions -type f -a -printf 'completions/%P\n')
}

parse-protobuf() {
  _parse-project ~/git/other/protobuf
}

parse-mksh() {
  _parse-project ~/src/mksh
}

parse-exp() {
  _parse-project ~/git/other/exp
}

parse-minimal-linux() {
  _parse-project ~/git/other/minimal
}

parse-micropython() {
  _parse-project ~/git/other/micropython
}

parse-staticpython() {
  _parse-project ~/git/other/staticpython
}

parse-linuxkit() {
  _parse-project ~/git/other/linuxkit
}

# NOTE:
# Find executable scripts, since they don't end in sh.
# net/tcpretrans is written in Perl.
parse-perf-tools() {
  local src=~/git/other/perf-tools
  local files=$(find $src \
                \( -name .git -a -prune \) -o \
                \( -name tcpretrans -a -prune \) -o \
                \( -type f -a -executable -a -printf '%P\n' \) )
  #echo $files
  time _parse-many \
    $src \
    $RESULT_DIR/perf-tools-parsed \
    $files
}

# Bats bash test framework.  It appears to be fairly popular.
parse-bats() {
  local src=~/git/other/bats
  local files=$(find $src \
                \( -wholename '*/libexec/*' -a -type f -a \
                   -executable -a -printf '%P\n' \) )

  time _parse-many \
    $src \
    $RESULT_DIR/bats \
    $files
}

parse-bashdb() {
  local src=~/src/bashdb-4.4-0.92

  time _parse-many \
    $src \
    $RESULT_DIR/bashdb \
    $(find $src -name '*.sh' -a -printf '%P\n')
}

parse-bash-snippets() {
  local src=~/git/other/Bash-Snippets
  local files=$(find $src \
                \( -name .git -a -prune \) -o \
                \( -type f -a -executable -a -printf '%P\n' \) )

  time _parse-many \
    $src \
    $RESULT_DIR/bash-snippets \
    $files
}

# ASDF meta package/version manager.
# Note that the language-specific plugins are specified (as remote repos) here:
# https://github.com/asdf-vm/asdf-plugins/tree/master/plugins
# They could be used for more tests.

parse-asdf() {
  local src=~/git/other/asdf

  time _parse-many \
    $src \
    $RESULT_DIR/asdf \
    $(find $src \( -name '*.sh' -o -name '*.bash' \) -a -printf '%P\n' )
}

parse-scripts-to-rule-them-all() {
  local src=~/git/other/scripts-to-rule-them-all

  time _parse-many \
    $src \
    $RESULT_DIR/scripts-to-rule-them-all \
    $(find $src \
      \( -name .git -a -prune \) -o \
      \( -type f -a -executable -a -printf '%P\n' \) )
}

#
# Big projects
#

parse-linux() {
  _parse-project ~/src/linux-4.8.7
}

parse-mozilla() {
  _parse-project \
    /mnt/ssd-1T/build/ssd-backup/sdb/build/hg/other/mozilla-central/
}

parse-chrome() {
  _parse-project \
    /mnt/ssd-1T/build/ssd-backup/sdb/build/chrome
}

parse-chrome2() {
  _parse-configure-scripts \
    /mnt/ssd-1T/build/ssd-backup/sdb/build/chrome
}

parse-android() {
  _parse-project \
    /mnt/ssd-1T/build/ssd-backup/sdb/build/android
}

parse-android2() {
  _parse-configure-scripts \
    /mnt/ssd-1T/build/ssd-backup/sdb/build/android
}

parse-openwrt() {
  _parse-project \
    /mnt/ssd-1T/build/ssd-backup/sdb/build/openwrt
}

parse-openwireless() {
  _parse-project \
    /mnt/ssd-1T/build/ssd-backup/sdb/build/OpenWireless
}

#
# Find Biggest Shell Scripts in Aboriginal Source Tarballs
#

readonly AB_PACKAGES=~/hg/scratch/aboriginal/aboriginal-1.2.2/packages

aboriginal-packages() {
  for z in $AB_PACKAGES/*.tar.gz; do
    local name=$(basename $z .tar.gz)
    echo $z -z $name
  done
  for z in $AB_PACKAGES/*.tar.bz2; do
    local name=$(basename $z .tar.bz2)
    echo $z -j $name
  done
}

readonly AB_OUT=_tmp/aboriginal

aboriginal-manifest() {
  mkdir -p $AB_OUT

  aboriginal-packages | while read z tar_flag name; do
    echo $z $name
    local listing=$AB_OUT/${name}.txt
    tar --list --verbose $tar_flag < $z | grep '\.sh$' > $listing || true
  done
}

aboriginal-biggest() {
  # print size and filename
  cat $AB_OUT/*.txt | awk '{print $3 " " $6}' | sort -n
}

# biggest scripts besides ltmain:
#
# 8406 binutils-397a64b3/binutils/embedspu.sh
# 8597 binutils-397a64b3/ld/emulparams/msp430all.sh
# 9951 bash-2.05b/examples/scripts/dd-ex.sh
# 12558 binutils-397a64b3/ld/genscripts.sh
# 14148 bash-2.05b/examples/scripts/adventure.sh
# 21811 binutils-397a64b3/gas/testsuite/gas/xstormy16/allinsn.sh
# 28004 bash-2.05b/examples/scripts/bcsh.sh
# 29666 gcc-4.2.1/ltcf-gcj.sh
# 33972 gcc-4.2.1/ltcf-c.sh
# 39048 gcc-4.2.1/ltcf-cxx.sh

if test "$(basename $0)" = 'wild.sh'; then
  "$@"
fi

