#!/usr/bin/python
"""
wild_report.py
"""

#import csv
import json
import glob
import os
import sys
from collections import defaultdict

import urllib
import jsontemplate

# JSON Template Evaluation:
#
# - {.if}{.or} is confusing
# I think there is even a bug with {.if}{.else}{.end} -- it accepts it but
# doesn't do the right thing!
#   - {.if test} does work though, but it took me awhile to remember that or
#   - I forgot about {.link?} too
#   even find it in the source code.  I don't like this separate predicate
#   language.  Could just be PHP-ish I guess.
# - Predicates are a little annoying.
# - Lack of location information on undefined variables is annoying.  It spews
# a big stack trace.
# - The styles thing seems awkward.  Copied from srcbook.
#
# Good parts:
# Just making one big dict is pretty nice.

T = jsontemplate.Template

F = {
    'commas': lambda n: '{:,}'.format(n),
    # NOTE: matches urlesc in handlers/lists.py
    'urlesc': urllib.quote_plus,
    }

def MakeHtmlGroup(title_str, body_str):
  """Make a group of templates that we can expand with a common style."""
  return {
      'TITLE': T(title_str, default_formatter='html', more_formatters=F),
      'BODY': T(body_str, default_formatter='html', more_formatters=F),
      'NAV': NAV_TEMPLATE,
  }

BODY_STYLE = jsontemplate.Template("""\
<!DOCTYPE html>
<html>
  <head>
    <title>{.template TITLE}</title>

    <script src="{base_url}wild.js" type="text/javascript"></script>
    <link rel="stylesheet" type="text/css" href="{base_url}wild.css" />
  </head>

  <body>
    <p id="topbox">
{.template NAV}
    </p>

    <p id="">
{.template BODY}
    </p>
  </body>

</html>
""", default_formatter='html')

# NOTE: {.link} {.or id?} {.or} {.end} doesn't work?  That is annoying.
NAV_TEMPLATE = jsontemplate.Template("""\
{.section nav}
<div id="nav">
<code>
{.repeated section @}
  {.link?}
    <a href="{link|htmltag}">{anchor}</a>
  {.or}
    {anchor}
  {.end}
{.alternates with}
  /
{.end}
</code>
</div>
{.end}
""", default_formatter='html')


PAGE_TEMPLATES = {}

# TODO:
# - Measure internal process time
# - Add CSS
# - Run it on all files
#
# - Delete lots of old code in wild.sh

# - DONE Fill in the Nav
#
# - DONE Turn failure into boolean, not exit code
# - DONE On succes: Show links to AST and conversion
#   - OK OK -- and maybe the filename is all 3 side by side

# - DONE On errors: link to stderr
#   - DONE Probably want to combine stderr
#   - DONE move from /raw/ to www.  Could even put them on the listing itself?


PAGE_TEMPLATES['LISTING'] = MakeHtmlGroup(
    '{rel_path}/',
"""\
{.section dirs}
<table>
  <thead>
    <tr>
      <td align="right">Files</td>
      <td align="right">Lines</td>
      <td align="right">Parse Failures</td>
      <td align="right">Total Parse Time (secs)</td>
      <td align="right">Internal Parse Time (secs)</td>
      <td align="right">Parsed Lines/sec</td>
      <td align="right">Translation Failures</td>
      <td>Name</td>
    </tr>
  </thead>
  {.repeated section @}
    <tr>
      <td align="right">{num_files|commas}</td>
      <td align="right">{num_lines|commas}</td>
      <td align="right">{parse_failed|commas}</td>
      <td align="right">{parse_proc_secs}</td>
      <td align="right">{parse_proc_secs}</td>
      <td align="right">{num_files|commas}</td>
      <td align="right">{osh2oil_failed|commas}</td>
      <td><code><a href="{name|htmltag}/listing.html">{name|html}/</a></code></td>
    </tr>
  {.end}
</table>
{.end}

{.section files}
<table>
  <thead>
    <tr>
      <td align="right">Lines</td>
      <td align="right">Parse Status</td>
      <td align="right">Parse Process Time (secs)</td>
      <td align="right">Internal Parse Time (secs)</td>
      <td align="right">Parsed Lines/sec</td>
      <td align="right">Translation Status</td>
      <td>Name</td>
    </tr>
  </thead>
  {.repeated section @}
    <tr>
      <td align="right">{num_lines|commas}</td>
      <td align="right">
        {.section parse_failed}
          <a href="#stderr_parse_{name}">FAIL</a>
        {.or}
          <a href="{name}__ast.html">OK</a>
        {.end}
      </td>
      <td align="right">{parse_proc_secs}</td>
      <td align="right">{parse_proc_secs}</td>
      <td align="right">{num_files|commas}</td>

      <td align="right">
        {# not sure how to use if? }
        {.section osh2oil_failed}
          <a href="#stderr_osh2oil_{name}">FAIL</a>
        {.or}
          <a href="{name}__oil.txt">OK</a>
        {.end}
      </td>
      <td><code><a href="{name|htmltag}.txt">{name|html}</a></code></td>
    </tr>
  {.end}
<table>
{.end}

{.if test empty}
  <i>(empty dir)</i>
{.end}

{.section stderr}
  <h2>stderr</h2>

  {.repeated section @}
    <p>
    <a name="stderr_{action}_{name|htmltag}"></a>
    {.if test parsing}
      Parsing {name|html}
    {.or}
      Translating {name|html}
    {.end}

    <pre>
    {contents|html}
    </pre>
    </p>

    <hr/>
  {.end}
{.end}

""")


def log(msg, *args):
  if msg:
    msg = msg % args
  print >>sys.stderr, msg


class DirNode:
  """Entry in the file system tree."""

  def __init__(self):
    self.files = {}  # filename -> stats for success/failure, time, etc.
    self.dirs = {}  # subdir name -> Dir object
    self.dir_totals = {}  # subdir -> summed stats

    # show all the non-empty stderr here?
    # __osh2oil.stderr.txt
    # __parse.stderr.txt
    self.stderr = []


# Traverse the root object with the relative path
# Update it with rows
def UpdateNodes(node, path_parts, file_stats):
  first = path_parts[0]
  rest = path_parts[1:]

  if rest:
    if first in node.dirs:
      child = node.dirs[first]
    else:
      child = DirNode()
      node.dirs[first] = child
      node.dir_totals[first] = {}  # Empty

    sums = node.dir_totals[first]
    for name, value in file_stats.iteritems():
      # Sum numerical properties, but not strings
      if isinstance(value, int) or isinstance(value, float):
        if name in sums:
          sums[name] += value
        else:
          # NOTE: Could be int or float!!!
          sums[name] = value

    UpdateNodes(child, rest, file_stats)
  else:
    # Include stderr if non-empty, or if FAILED
    parse_stderr = file_stats.pop('parse_stderr')
    if parse_stderr or file_stats['parse_failed']:
      node.stderr.append({
          'parsing': True,
          'action': 'parse',
          'name': first,
          'contents': parse_stderr,
      })
    osh2oil_stderr = file_stats.pop('osh2oil_stderr')
    if osh2oil_stderr or file_stats['osh2oil_failed']:
      node.stderr.append({
          'parsing': False,
          'action': 'osh2oil',
          'name': first,
          'contents': osh2oil_stderr,
      })

    # Attach to this dir
    node.files[first] = file_stats


def PrintNodes(node, indent=0):
  """
  For debugging, print the tree
  """
  ind = indent * '    '
  #print('FILES', node.files.keys())
  for name in node.files:
    print '%s%s - %s' % (ind, name, node.files[name])
  for name, child in node.dirs.iteritems():
    print '%s%s/ - %s' % (ind, name, node.dir_totals[name])
    PrintNodes(child, indent=indent+1)


def WriteJsonFiles(node, out_dir):
  """
  Write a listing.json file for every directory.
  """
  path = os.path.join(out_dir, 'INDEX.json')
  with open(path, 'w') as f:
    d = {'files': node.files, 'dirs': node.dir_totals}
    json.dump(d, f)

  log('Wrote %s', path)

  for name, child in node.dirs.iteritems():
    WriteJsonFiles(child, os.path.join(out_dir, name))


def _MakeNav(rel_path):
  assert not rel_path.startswith('/'), rel_path
  assert not rel_path.endswith('/'), rel_path
  parts = rel_path.split('/')
  data = []
  n = len(parts)
  for i, p in enumerate(parts):
    if i == n - 1:
      link = None  # Current page shouldn't have link
    else:
      link = '../' * (n - 1 - i) + 'listing.html'
    data.append({'anchor': p, 'link': link})
  return data


def WriteHtmlFiles(node, out_dir, rel_path='WILD', base_url=''):
  path = os.path.join(out_dir, 'listing.html')
  with open(path, 'w') as f:
    files = []
    for name in sorted(node.files):
      stats = node.files[name]
      entry = dict(stats)
      entry['name'] = name
      files.append(entry)

    dirs = []
    for name in sorted(node.dir_totals):
      stats = node.dir_totals[name]
      entry = dict(stats)
      entry['name'] = name
      dirs.append(entry)

    data = {
        'rel_path': rel_path,
        'files': files,
        'dirs': dirs,
        'base_url': base_url,
        'stderr': node.stderr,
        'nav': _MakeNav(rel_path),
    }

    for name in node.files:
      pass
    for name in node.dir_totals:
      pass
    group = PAGE_TEMPLATES['LISTING']
    body = BODY_STYLE.expand(data, group=group)
    f.write(body)

  log('Wrote %s', path)
  for name, child in node.dirs.iteritems():
    child_out = os.path.join(out_dir, name)
    child_rel = os.path.join(rel_path, name)
    child_base = base_url + '../'
    WriteHtmlFiles(child, child_out, rel_path=child_rel, base_url=child_base)


def main(argv):
  action = argv[1]

  if action == 'summarize-dirs':
    # lines and size, oops

    # TODO: Need read the manifest instead, and then go by dirname() I guess
    # I guess it is a BFS so you can just assume?
    # os.path.dirname() on the full path?
    # Or maybe you need the output files?

    root_node = DirNode()

    # Collect work into dirs
    for line in sys.stdin:
      #d = line.strip()
      proj, abs_path, rel_path = line.split()
      #print proj, '-', abs_path, '-', rel_path

      def _ReadTaskFile(path):
        with open(path) as f:
          parts = f.read().split()
          status, secs = parts
        # Turn it into pass/fail
        num_failed = 1 if int(status) >= 1 else 0
        return num_failed, float(secs)

      raw_base = os.path.join('_tmp/wild/raw', proj, rel_path)
      st = {}

      # TODO:
      # - Open stderr to get internal time
      # - Open stderr only for the ones that failed?  Then put them literally
      #   'osh2oil_stderr'

      parse_task_path = raw_base + '__parse.task.txt'
      st['parse_failed'], st['parse_proc_secs'] = _ReadTaskFile(
          parse_task_path)

      with open(raw_base + '__parse.stderr.txt') as f:
        st['parse_stderr'] = f.read()
      
      osh2oil_task_path = raw_base + '__osh2oil.task.txt'
      st['osh2oil_failed'], st['osh2oil_proc_secs'] = _ReadTaskFile(
          osh2oil_task_path)

      with open(raw_base + '__osh2oil.stderr.txt') as f:
        st['osh2oil_stderr'] = f.read()

      wc_path = raw_base + '__wc.txt'
      with open(wc_path) as f:
        st['num_lines'] = int(f.read().split()[0])
      st['num_files'] = 1

      path_parts = [proj] + rel_path.split('/')
      print path_parts
      UpdateNodes(root_node, path_parts, st)

    # Debug print
    PrintNodes(root_node)
    WriteJsonFiles(root_node, '_tmp/wild/www')
    WriteHtmlFiles(root_node, '_tmp/wild/www')

    # TODO: Also concat stderr?  Or is that a separate script?
    # Need to collect files by directory?
    # Need fragments 

  else:
    raise RuntimeError('Invalid action %r' % action)


if __name__ == '__main__':
  try:
    main(sys.argv)
  except RuntimeError as e:
    print >>sys.stderr, 'FATAL: %s' % e
    sys.exit(1)
