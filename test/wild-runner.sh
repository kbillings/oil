#!/bin/bash
#
# Usage:
#   ./wild-runner.sh <function name>

set -o nounset
set -o pipefail
set -o errexit

source test/common.sh

#
# Helpers
# 

# Default abbrev-text format
osh-parse() {
  bin/osh -n "$@"
}

# TODO: err file always exists because of --no-exec
_parse-one() {
  local input=$1
  local output=$2

  local stderr_file=${output}__err.txt
  osh-parse $input > $output-AST.txt 2> $stderr_file
  local status=$?

  return $status
}

osh-html() {
  bin/osh --ast-format abbrev-html -n "$@"
}

_osh-html-one() {
  local input=$1
  local output=$2

  local stderr_file=${output}__htmlerr.txt
  osh-html $input > $output-AST.html 2> $stderr_file
  local status=$?

  return $status
}

osh-to-oil() {
  bin/osh -n --fix "$@"
}

_osh-to-oil-one() {
  local input=$1
  local output=$2

  local stderr_file=${output}__osh-to-oil-err.txt
  # NOTE: Need text extension for some web servers.
  osh-to-oil $input > ${output}.oil.txt 2> $stderr_file
  local status=$?

  return $status
}

_parse-and-copy-one() {
  local src_base=$1
  local dest_base=$2
  local rel_path=$3

  local input=$src_base/$rel_path
  local output=$dest_base/$rel_path

  if grep -E 'exec wish|exec tclsh' $input; then
    echo "$rel_path SKIPPED"

    local html="
    $rel_path SKIPPED because it has 'exec wish' or 'exec tclsh'
    <hr/>
    "
    echo $html >>$dest_base/FAILED.html
    return 0
  fi

  mkdir -p $(dirname $output)
  echo $input

  # Add .txt extension so it's not executable, and use 'cat' instead of cp
  # So it's not executable.
  cat < $input > ${output}.txt

  if ! _parse-one $input $output; then  # Convert to text AST
    echo $rel_path >>$dest_base/FAILED.txt

    # Append
    cat >>$dest_base/FAILED.html <<EOF
    <a href="$rel_path.txt">$rel_path.txt</a>
    <a href="${rel_path}__err.txt">${rel_path}__err.txt</a>
    <a href="$rel_path-AST.txt">$rel_path-AST.txt</a>
    <br/>
    <pre>
    $(cat ${output}__err.txt)
    </pre>
    <hr/>
EOF

    log "*** Failed to parse $rel_path"
    return 1  # no point in continuing
  fi
  #rm ${output}__err.txt

  if ! _osh-html-one $input $output; then  # Convert to HTML AST
    log "*** Failed to convert $input to AST"
    return 1  # no point in continuing
  fi

  if ! _osh-to-oil-one $input $output; then  # Convert to Oil
    # Append
    cat >>$dest_base/FAILED.html <<EOF
    <a href="$rel_path.txt">$rel_path.txt</a>
    <a href="${rel_path}__osh-to-oil-err.txt">${rel_path}__osh-to-oil-err.txt</a>
    <a href="$rel_path.oil.txt">$rel_path.oil.txt</a>
    <br/>
    <pre>
    $(cat ${output}__osh-to-oil-err.txt)
    </pre>
    <hr/>
EOF

    log "*** Failed to convert $input to Oil"
    return 1  # failed
  fi
}

_link-or-copy() {
  # Problem: Firefox treats symlinks as redirects, which breaks the AJAX.  Copy
  # it for now.
  local src=$1
  local dest=$2
  #ln -s -f --verbose ../../../$src $dest
  cp -f --verbose $src $dest
}

_parse-many() {
  local src_base=$1
  local dest_base=$2
  shift 2
  # Rest of args are relative paths

  mkdir -p $dest_base

  { pushd $src_base >/dev/null
    wc -l "$@"
    popd >/dev/null
  } > $dest_base/LINE-COUNTS.txt

  # Don't call it index.html
  make-index < $dest_base/LINE-COUNTS.txt > $dest_base/FILES.html

  _link-or-copy web/osh-to-oil.html $dest_base
  _link-or-copy web/osh-to-oil.js $dest_base
  _link-or-copy web/osh-to-oil-index.css $dest_base

  # Truncate files
  echo -n '' >$dest_base/FAILED.txt
  echo -n '' >$dest_base/FAILED.html

  local failed=''

  for f in "$@"; do echo $f; done |
    sort |
    xargs -n 1 -- $0 _parse-and-copy-one $src_base $dest_base ||
    failed=1

  tree -p $dest_base

  if test -n "$failed"; then
    log ""
    log "*** Some tasks failed.  See messages above."
  fi
  echo "Results: file://$PWD/$dest_base"
}

make-index() {
  cat << EOF
<html>
<head>
  <link rel="stylesheet" type="text/css" href="osh-to-oil-index.css" />
</head>
<body>
<p> <a href="..">Up</a> </p>

<h2>Files in this Project</h2>

<table>
EOF
  echo "<thead> <tr> <td align=right>Count</td> <td>Name</td> </tr> </thead>";
  while read count name; do
    echo -n "<tr> <td align=right>$count</td> "
    if test $name == 'total'; then
      echo -n "<td>$name</td>"
    else
      echo -n "<td><a href=\"osh-to-oil.html#${name}\">$name</a></td> </tr>"
    fi
    echo "</tr>"
  done
  cat << EOF
</table>
</body>
</html>
EOF
}

# TODO: Modify this  to work with wild.
_all-parallel() {
  mkdir -p _tmp/wild

  # wild.sh
  write-all-manifests
  # TODO: Write manifest.txt?
  # Everything is single-threaded except the top level?  OK fine.

  # NOTE: For spec tests, they get HTML for free here.  We need to make our
  # own HTML for each project.
  # And then a summary for all projects.

  head -n $NUM_TASKS _tmp/wild/MANIFEST.txt \
    | xargs -n 1 -P $JOBS --verbose -- $0 run-cases || true

  #ls -l _tmp/spec

  #all-tests-to-html

  link-css

  html-summary
}


if test "$(basename $0)" = 'wild-runner.sh'; then
  "$@"
fi
