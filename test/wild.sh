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

set -o nounset
set -o pipefail
set -o errexit

source test/wild-runner.sh

readonly RESULT_DIR=_tmp/wild

#
# Helpers
#

# TODO: Remove
_parse-configure-scripts() {
  local src=$1
  local name=$(basename $src)

  time _parse-many \
    $src \
    $RESULT_DIR/$name-configure-parsed \
    $(find $src -name 'configure' -a -printf '%P\n')
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

readonly ABORIGINAL_DIR=~/src/aboriginal-1.4.5

#
# All
#

all-manifests() {
  oil-sketch-manifest
  oil-manifest

  local src

  #
  # Bash stuff
  #
  src=~/git/other/bash-completion
  _manifest $(basename $src) $src \
    $(find $src/completions -type f -a -printf 'completions/%P\n')

  # Bats bash test framework.  It appears to be fairly popular.
  src=~/git/other/bats
  _manifest $(basename $src) $src \
    $(find $src \
      \( -wholename '*/libexec/*' -a -type f -a \
         -executable -a -printf '%P\n' \) )

  # Bash debugger?
  src=~/src/bashdb-4.4-0.92
  _manifest bashdb $src \
    $(find $src -name '*.sh' -a -printf '%P\n')

  src=~/git/other/Bash-Snippets
  _manifest $(basename $src) $src \
    $(find $src \
      \( -name .git -a -prune \) -o \
      \( -type f -a -executable -a -printf '%P\n' \) )

  #
  # Shell Frameworks/Collections
  #

  # Brendan Gregg's performance scripts.
  # Find executable scripts, since they don't end in sh.
  # net/tcpretrans is written in Perl.
  src=~/git/other/perf-tools
  _manifest $(basename $src) $src \
    $(find $src \
      \( -name .git -a -prune \) -o \
      \( -name tcpretrans -a -prune \) -o \
      \( -type f -a -executable -a -printf '%P\n' \) )

  # ASDF meta package/version manager.
  # Note that the language-specific plugins are specified (as remote repos)
  # here: https://github.com/asdf-vm/asdf-plugins/tree/master/plugins
  # They # could be used for more tests.

  src=~/git/other/asdf
  _manifest $(basename $src) $src \
    $(find $src \( -name '*.sh' -o -name '*.bash' \) -a -printf '%P\n' )

  src=~/git/other/scripts-to-rule-them-all
  _manifest $(basename $src) $src \
    $(find $src \
      \( -name .git -a -prune \) -o \
      \( -type f -a -executable -a -printf '%P\n' \) )

  #
  # Linux Distros
  #

  _simple-manifest ~/git/other/minimal
  _simple-manifest ~/git/other/linuxkit

  src=$ABORIGINAL_DIR
  _manifest aboriginal $src \
    $(find $src -name '*.sh' -printf '%P\n')

  src=/etc/init.d
  _manifest initd $src \
    $(find $src -type f -a -executable -a -printf '%P\n')

  src=/usr/bin
  _manifest usr-bin $src \
    $(find $src -name '*.sh' -a -printf '%P\n')

  # Version 1.0.89 extracts to a version-less dir.
  src=~/git/basis-build/_tmp/debootstrap
  _manifest debootstrap $src \
    $(find $src '(' -name debootstrap -o -name functions ')' -a -printf '%P\n') \
    $(find $src/scripts -type f -a -printf 'scripts/%P\n')

  #
  # Cloud Stuff
  #
  _simple-manifest ~/git/other/mesos
  _simple-manifest ~/git/other/chef-bcpc
  _simple-manifest ~/git/other/sandstorm
  _simple-manifest ~/git/other/kubernetes

  src=~/git/other/dokku
  _manifest dokku $src \
    $(find $src '(' -name '*.sh' -o -name dokku ')' -a -printf '%P\n')

  #
  # Google
  #
  _simple-manifest ~/git/other/bazel
  _simple-manifest ~/git/other/protobuf

  #
  # Other shells
  #

  _simple-manifest ~/git/other/ast  # korn shell stuff
  _simple-manifest ~/src/mksh

  #
  # Other Languages
  #

  _simple-manifest ~/git/other/julia
  _simple-manifest ~/git/other/sdk  # Dart SDK?

  _simple-manifest ~/git/other/micropython
  _simple-manifest ~/git/other/staticpython  # statically linked build

  #
  # Esoteric
  #

  _simple-manifest ~/git/scratch/shasm
  _simple-manifest ~/git/other/lishp

  src=~/git/other/mal/bash
  _manifest make-a-lisp-bash $src \
    $(find $src '(' -name '*.sh' ')' -a -printf '%P\n')

  src=~/git/other/gherkin
  _manifest $(basename $src) $src \
    $(find $src '(' -name '*.sh' -o -name 'gherkin' ')' -a -printf '%P\n')

  src=~/git/other/balls
  _manifest $(basename $src) $src \
    $(find $src '(' -name '*.sh' -o -name balls -o -name esh ')' -a \
                -printf '%P\n')

  src=~/git/other/bashcached
  _manifest $(basename $src) $src \
    $(find $src '(' -name '*.sh' -o -name 'bashcached' ')' -a -printf '%P\n')

  src=~/git/other/quinedb
  _manifest $(basename $src) $src \
    $(find $src '(' -name '*.sh' -o -name 'quinedb' ')' -a -printf '%P\n')

  src=~/git/other/bashttpd
  _manifest $(basename $src) $src \
    $(find $src -name 'bashttpd' -a -printf '%P\n')

  #
  # Parsers
  #
  local src=~/git/other/j
  _manifest $(basename $src) $src \
    $(find $src -type f -a  -name j -a -printf '%P\n')

  _simple-manifest ~/git/other/JSON.sh

  #
  # Big
  #

  #
  # Misc Scripts
  #

  # NOTE: These scripts don't end with *.sh
  src=~/git/other/pixelb-scripts
  _manifest pixelb-scripts $src \
    $(find $src \( -name .git -a -prune \) -o \
                \( -type f -a -executable -a -printf '%P\n' \) )

  _simple-manifest ~/git/other/wwwoosh
  _simple-manifest ~/git/other/git
  _simple-manifest ~/git/other/mesos

  _simple-manifest ~/git/other/exp  # What is this?

}

write-all-manifests() {
  mkdir -p _tmp/wild
  all-manifests > _tmp/wild/MANIFEST.txt
  wc -l _tmp/wild/MANIFEST.txt
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

# Doesn't parse because of extended glob.
parse-wd() {
  local src=~/git/other/wd

  time _parse-many \
    $src \
    $RESULT_DIR/wd \
    $(find $src -type f -a  -name wd -a -printf '%P\n')
}


#
# Big projects
#

parse-linux() {
  _simple-manifest ~/src/linux-4.8.7
}

parse-mozilla() {
  _simple-manifest \
    /mnt/ssd-1T/build/ssd-backup/sdb/build/hg/other/mozilla-central/
}

parse-chrome() {
  _simple-manifest \
    /mnt/ssd-1T/build/ssd-backup/sdb/build/chrome
}

parse-chrome2() {
  _parse-configure-scripts \
    /mnt/ssd-1T/build/ssd-backup/sdb/build/chrome
}

parse-android() {
  _simple-manifest \
    /mnt/ssd-1T/build/ssd-backup/sdb/build/android
}

parse-android2() {
  _parse-configure-scripts \
    /mnt/ssd-1T/build/ssd-backup/sdb/build/android
}

parse-openwrt() {
  _simple-manifest \
    /mnt/ssd-1T/build/ssd-backup/sdb/build/openwrt
}

parse-openwireless() {
  _simple-manifest \
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

