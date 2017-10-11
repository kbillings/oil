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
    <div id="topbox">
{.template NAV}
    </div>

    <div id="">
{.template BODY}
    </div>
  </body>

</html>
""", default_formatter='html')

# NOTE: {.link} {.or id?} {.or} {.end} doesn't work?  That is annoying.
NAV_TEMPLATE = jsontemplate.Template("""\
{.section nav}
<div id="nav">
{.repeated section @}
  {.link?}
    <a href="{link|htmltag}">{anchor}</a>
  {.or}
    {.id?}
      <span id="{id|htmltag}">{anchor}</span>
    {.or}
      {anchor}
    {.end}
  {.end}
{.alternates with}
  /
{.end}
</div>
{.end}
""", default_formatter='html')


FILES_HEADER = (
    'filename',
    'parse_status', 'parse_proc_secs', 'parse_internal_secs',
    'osh2oil_status', 'osh2oil_proc_secs',
)

DIR_HEADER = (
    'directory',
    'num_files',  # total children
    'num_parse_failed',
    'parse_proc_secs',  # total for successes
    'parse_internal_secs',  # total for successes
    'num_osh2oil_failed',
    'osh2oil_proc_secs',  # ditto
)

PAGE_TEMPLATES = {}

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
      <td align="right">Total Parse Time</td>
      <td align="right">Parsed Lines Per Second</td>
      <td align="right">Translation Failures</td>
      <td>Name</td>
    </tr>
  </thead>
  {.repeated section @}
    <tr>
      <td align="right">{num_files|commas}</td>
      <td align="right">{num_files|commas}</td>
      <td align="right">{num_files|commas}</td>
      <td align="right">{num_files|commas}</td>
      <td align="right">{num_files|commas}</td>
      <td align="right">{num_files|commas}</td>
      <td><a href="{name|htmltag}/listing.html">{name|html}/</a></td>
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
      <td align="right">Parse Process Time</td>
      <td align="right">Internal Parse Time</td>
      <td align="right">Translation Status</td>
      <td>Name</td>
    </tr>
  </thead>
  {.repeated section @}
    <tr>
      <td align="right">{num_files|commas}</td>
      <td align="right">{num_files|commas}</td>
      <td align="right">{num_files|commas}</td>
      <td align="right">{num_files|commas}</td>
      <td align="right">{num_files|commas}</td>
      <td><a href="{name|htmltag}">{name|html}</a></td>
    </tr>
  {.end}
<table>
{.end}

{.section symlinks}
<table>
  <thead>
    <tr>
      <td>Name</td>
      <td></td>
      <td>Target</td>
    </tr>
  </thead>
  {.repeated section @}
    <tr>
      <td>{name}</td>
      <td>&rarr;</td> {# right arrow}
      <td>{target}</td>
    </tr>
  {.end}
</table>
{.end}

{.if test empty}
  <i>(empty dir)</i>
{.end}

{.section dir_text}
<hr/>
<pre>
{@}
</pre>
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
      if name in sums:
        sums[name] += value
      else:
        # NOTE: Could be int or float!!!
        sums[name] = value

    UpdateNodes(child, rest, file_stats)
  else:
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


def WriteHtmlFiles(node, out_dir, rel_path='ROOT', base_url=''):
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
        return int(status), float(secs)

      raw_base = os.path.join('_tmp/wild/raw', proj, rel_path)
      st = {}

      # TODO: Open stderr too to get internal time?
      # Also what about exit code 2?  Translate to num_failed?

      parse_task_path = raw_base + '__parse.task.txt'
      st['parse_status'], st['parse_proc_secs'] = _ReadTaskFile(
          parse_task_path)
      
      osh2oil_task_path = raw_base + '__osh2oil.task.txt'
      st['osh2oil_status'], st['osh2oil_proc_secs'] = _ReadTaskFile(
          osh2oil_task_path)

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
