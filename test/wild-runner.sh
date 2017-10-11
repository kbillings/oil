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

_parse-and-copy-one() {
  local input=$1
  local rel_path=$2
  local dest_base=$3

  #local src_base=$1
  #local dest_base=$2
  #local rel_path=$3

  #local input=$src_base/$rel_path
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

# Table:
#
# Underlying text file:
#
# rel_path num_bytes -> num_lines, parse task status/process time,
#                       internally measured parse time
#                       MAYBE: number of nodes, number of unique 
#                       node types!
#                       conversion task status/process time
#
# Blog post: what's the hairiest single script?  in terms of unique node
# types.  It would be see there are '87' node types, 228 op_ids, and which
# scripts use them all.
# Alpine scripts should be fairly limited
#
# Then in display mode:
# - link to HTML
# - link to errors: FAILED.html
#
# Write a Awk/Python script that makes a CSV
# THen write one that makes summaries per directory.
# I want

#
# Totals by dir
# - # shell scripts
# - # lines
# - failed parses
# - failed conversions
# - parse process time
# - parse time
#
# OK - time
# FAIL - link to stderr

process-file() {
  local proj=$1
  local abs_path=$2
  local rel_path=$3

  echo $proj - $abs_path - $rel_path

  local raw_base=_tmp/wild/raw/$proj/$rel_path
  local www_base=_tmp/wild/www/$proj/$rel_path
  mkdir -p $(dirname $raw_base)
  mkdir -p $(dirname $www_base)

  # Count the number of lines.  This creates a tiny file, but we're doing
  # everything involving $abs_path at once so it's in the FS cache.
  wc $abs_path > ${raw_base}__wc.txt

  # Make a literal copy with .txt extension, so we can browse it
  cp -v $abs_path ${www_base}.txt

  # Parse the file.
  local task_file=${raw_base}__parse.task.txt
  local stderr_file=${raw_base}__parse.stderr.txt
  local out_file=${www_base}__ast.html

  run-task-with-status $task_file \
    bin/osh --ast-format abbrev-html -n $abs_path \
    > $out_file 2> $stderr_file

  # Convert the file.
  task_file=${raw_base}__osh2oil.task.txt
  stderr_file=${raw_base}__osh2oil.stderr.txt
  out_file=${www_base}__oil.txt

  run-task-with-status $task_file \
    bin/osh -n --fix $abs_path \
    > $out_file 2> $stderr_file
}

print-manifest() {
  #head _tmp/wild/MANIFEST.txt 
  egrep '^dokku|^wwwoosh|^oil' _tmp/wild/MANIFEST.txt
}

all-parallel() {
  local failed=''
  #head -n 20 _tmp/wild/MANIFEST.txt |
  print-manifest | xargs -n 3 -P $JOBS -- $0 process-file || failed=1

  tree _tmp/wild
}

# TODO: Modify this  to work with wild.
_all-parallel() {
  # wild.sh
  write-all-manifests
  # TODO: Write manifest.txt?
  # Everything is single-threaded except the top level?  OK fine.

  # NOTE: For spec tests, they get HTML for free here.  We need to make our
  # own HTML for each project.
  # And then a summary for all projects.

  head -n $NUM_TASKS _tmp/wild/MANIFEST.txt \
    | xargs -n 1 -P $JOBS --verbose -- $0 parse-project || true

  #ls -l _tmp/spec

  #all-tests-to-html

  link-css

  html-summary
}

wild-report() {
  PYTHONPATH=~/hg/json-template/python test/wild_report.py "$@";
}

make-report() {
  print-manifest | wild-report summarize-dirs

  # NOTE: ajax.js is a copy of oilshell.org/analytics

  return
  ln -s -f -v \
    $PWD/web/wild-dir.html \
    $PWD/web/wild.css \
    $PWD/web/wild.js \
    $PWD/web/ajax.js \
    _tmp/wild/www
}

make-html() {
  find _tmp/wild -name RESULTS.csv | test/wild_report.py make-html
}

if test "$(basename $0)" = 'wild-runner.sh'; then
  "$@"
fi
