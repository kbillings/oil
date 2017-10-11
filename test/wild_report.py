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


def WriteFiles(node, out_dir):
  """
  Write a listing.json file for every directory.
  """
  path = os.path.join(out_dir, 'entries.json')
  with open(path, 'w') as f:
    d = {'files': node.files, 'dirs': node.dir_totals}
    json.dump(d, f)

    for name in node.files:
      pass
    for name in node.dir_totals:
      pass

  log('Wrote %s', path)

  for name, child in node.dirs.iteritems():
    WriteFiles(child, os.path.join(out_dir, name))


def main(argv):
  action = argv[1]

  if action == 'summarize-dirs':
    # lines and size, oops

    # TODO: Need read the manifest instead, and then go by dirname() I guess
    # I guess it is a BFS so you can just assume?
    # os.path.dirname() on the full path?
    # Or maybe you need the output files?

    HEADER = (
        'filename',
        'parse_status', 'parse_proc_secs', 'parse_internal_secs',
        'osh2oil_status', 'osh2oil_proc_secs',
    )

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
    WriteFiles(root_node, '_tmp/wild/www')

    # TODO: Also concat stderr?  Or is that a separate script?
    # Need to collect files by directory?
    # Need fragments 


    # This could just be a flat of dirs?
    # if you see *.task.txt
  elif action == 'make-html':
    # dict of directory -> sub dir stats?

    HEADER = (
        'directory',
        'num_files',  # total children
        'num_parse_failed',
        'parse_proc_secs',  # total for successes
        'parse_internal_secs',  # total for successes
        'num_osh2oil_failed',
        'osh2oil_proc_secs',  # ditto
    )

    dirs = {}

    # _tmp/wild is teh base dir.
    for line in sys.stdin:
      print line

    # Now iterate over RESULTS.csv
    # Assume BFS?
    # TODO: copy from treemap/treesum

    # RESULTS.html in every directory?
    # For every file, increment all its parents?
    pass

  else:
    raise RuntimeError('Invalid action %r' % action)

  print 'Hello from wild_report.py'


if __name__ == '__main__':
  try:
    main(sys.argv)
  except RuntimeError as e:
    print >>sys.stderr, 'FATAL: %s' % e
    sys.exit(1)
