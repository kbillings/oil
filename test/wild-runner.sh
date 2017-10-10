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

#

osh-html-one() {
  local input=$1
  local output=$2
  mkdir -p $(dirname $output)

}

osh2oil-one() {
  local input=$1
  local output=$2

  local task_file=${output}__osh2oil.task.txt
  local stderr_file=${output}__osh2oil.stderr.txt
  local out_file=${output}__oil.txt

  run-task-with-status $task_file \
    bin/osh -n --fix "$@" \
    > $out_file 2> $stderr_file
}

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

all-parallel() {
  local failed=''
  head -n 10 _tmp/wild/MANIFEST.txt |
    xargs -n 3 -P $JOBS -- $0 process-file || failed=1

  tree _tmp/wild

  return

  while read proj abs_path rel_path; do
    echo
    echo $proj - $abs_path - $rel_path
    echo
    #_parse-and-copy-one $abs_path $rel_path $out_dir || true
    local output=$out_dir/$rel_path 

    # Ignore errors because we wrote the taskf ile.
    osh-html-one $abs_path $output || true
  done < $manifest

  while read proj abs_path rel_path; do
    echo
    echo $proj - $abs_path - $rel_path
    echo
    #_parse-and-copy-one $abs_path $rel_path $out_dir || true
    local output=$out_dir/$rel_path 

    # Ignore errors because we wrote the taskf ile.
    osh2oil-one $abs_path $output || true
  done < $manifest

  # TODO:
  # - Make a RESULTS.csv file for each directory
  #   - size, line count, success/fail, time
  # - Then make an RESULTS.html per directory?
  #   - but it has to summarize the subtrees
  #   - so it has to be bfs?
  # - test/wild_report.py summary _tmp/wild
  # - test/wild_report.py ui _tmp/wild
  #   - technically you could do this in shell?
  #   - but easier in Python

  # _tmp/wild/
  #   MANIFEST.txt
  #   dokku.manifest.txt
  #   dokku/
  #     dokku.sh.txt  # copy of the script for viewing
  #     dokku.sh__count.txt  # line count

  #     dokku.sh__parse.html  # AST
  #     dokku.sh__parse.task.txt
  #     dokku.sh__parse.stderr.txt

  #     dokku.sh__osh2oil.task.txt
  #     dokku.sh__osh2oil.stderr.txt
  #     dokku.sh__osh2oil.code.txt
  #
  #     FAILED.html  # links to stderr.txt
  #
  #     RESULTS.csv - each row is a file
  #     SUMMARY.csv - each row is a subdir
  #   initd/
  #   SUMMARY.csv
  #     # no RESULTS.csv at the top level, because it's all dirs
  #
  #   RESULTS.html

  #   dokku.RESULTS.html    # something that can be published
  #   initd.RESULTS.html    # links to FAILED *.stderr.txt and so forth
  #                         # or maybe FAILED should not append?
  #                         # yeah I think you can just have links for each
  #                         one?
  #                         # FAILED can be made after the fact
  # Just find all the *.task.txt with non-zero status with Awk, and then
  # make it all at once.  No need to use append.  Then you can really run
  # all tasks in parallel.
  #
  # files that don't need to be published: *.task.txt, *.count.txt
  # everything else needs to be published
  #
  # 8 files from each file?  I guess that's OK?  Or the line count can be
  # done by Awk when it's summarizing.  The copy of the script can also be
  # done by Awk because we have the manifest.  Do it all in a fast batch for
  # publishing.

  # Only to HTML AST.  I don't need the text AST.  It doesn't even test
  # timing?  Well how do I isolate the timing of that?
  # Then I need Python again?  Or just run another one with
  # --ast-format=None or something?
  # Gah.
  #
  # _OIL_TIMING=parse and then grep stderr with awk?  As long as it
  # succeeds.

  # TODO:
  # - run-task-with-status $path.task.txt
  # 
  # And then join them how?
    # path = ( "_tmp/wild/" name "/" rel_path ".task.txt" )
    # path = ( "_tmp/wild/" name "/" rel_path ".count.txt" )
    # every individual fiel
    #
    # alternative: you could make a Python tool to do batch parsing?
    # Might be easier.
    # It can output the timing of the parse
    # It can count the lines.  All in one tool.
    # tools/batch_parse.py
    # But then it doesn't use osh -n and osh2oil?

  # - run wc -l on each file - $ path.count.txt
  #   - I guess this can be a separate awk step, for LINE-COUNTS.txt
  #   - maybe merge them with Awk or Python
  # - link CSS for the whole project
  # - FAILED is appended to

  #{ pushd $src_base >/dev/null
  #  wc -l "$@"
  #  popd >/dev/null
  #} > $dest_base/LINE-COUNTS.txt

  ## Don't call it index.html
  #make-index < $dest_base/LINE-COUNTS.txt > $dest_base/FILES.html

  #_link-or-copy web/osh-to-oil.html $dest_base
  #_link-or-copy web/osh-to-oil.js $dest_base
  #_link-or-copy web/osh-to-oil-index.css $dest_base

  ## Truncate files
  #echo -n '' >$dest_base/FAILED.txt
  #echo -n '' >$dest_base/FAILED.html

  #local failed=''

  #for f in "$@"; do echo $f; done |
  #  sort |
  #  xargs -n 1 -- $0 _parse-and-copy-one $src_base $dest_base ||
  #  failed=1

  #tree -p $dest_base

  #if test -n "$failed"; then
  #  log ""
  #  log "*** Some tasks failed.  See messages above."
  #fi
  #echo "Results: file://$PWD/$dest_base"
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

summarize-dirs() {
  #find _tmp/wild/dokku -type d | test/wild_report.py summarize-dirs
  #find _tmp/wild/dokku -name RESULTS.csv

  cat _tmp/wild/{dokku,wwwoosh}.manifest.txt | test/wild_report.py summarize-dirs
}

make-html() {
  find _tmp/wild -name RESULTS.csv | test/wild_report.py make-html
}


if test "$(basename $0)" = 'wild-runner.sh'; then
  "$@"
fi
