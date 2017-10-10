#!/usr/bin/python
"""
wild_report.py
"""

import csv
import glob
import os
import sys
from collections import defaultdict

# Step 1: # manifest / File system -> files/dirs dicts
# Step 2: # files/dirs dicts ->  JSON per directory!
#   A dir lives within a dir!
#
# files = {
#   'dokku': {
#      dokku: (... row ...)
#      testing/: { 
#      }
#   }
# }
# dirs = {
#   dokku: {
#     testing/: summary for taht row
#   }
# }

class DirNode:
  def __init__(self):
    # filename -> stats for success, failure, time, size, etc.
    self.files = {}  
    # subdir -> Dir object
    self.dirs = {}  # List of Dir objects
    # subdir -> total stats failures, etc.
    self.dir_totals = {}

  def ToJson(self):
    # files and total
    # Need to turn these int proper table objects or something
    print self.files
    print self.dir_totals


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
  for name in node.files:
    print '%s%s - %s' % (ind, name, node.files[name])
  for name in node.dir_totals:
    print '%s%s/ - %s' % (ind, name, node.dir_totals[name])
  for name in node.dirs:
    child = node.dirs[name]
    PrintNodes(child, indent=indent+1)


def WriteFiles(node, out):
  """
  Write a listing.json file for every directory.
  """
  pass




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
    suffix = '__parse.task.txt'

    dirs = defaultdict(list)

    # Or you could just do it all in one pass.

    # Make a data frame per dir.  And then write those to CSV?
    # And then make HTML with the CSV?
    #
    # files have: links to success/fail
    # dirs have: number of files
    #
    # or make FILES.csv and DIRS.csv
    # And then join those into HTML?  Maybe two tables?  Separately sortable?
    # Actually they could be JSON tables, and then use a single HTML file?

    # I kind of want a table abstraction, which can be CSV or JSON.
    # CSV goes to R, JSON goes to the browser.

    root_node = DirNode()

    # Collect work into dirs
    for line in sys.stdin:
      #d = line.strip()
      proj, abs_path, rel_path = line.split()
      #print proj, '-', abs_path, '-', rel_path

      raw_base = os.path.join('_tmp/wild/raw', proj, rel_path)
      path_parts = raw_base.split('/')[1:]  # get rid of _tmp/
      print path_parts

      d = os.path.dirname(raw_base)
      dirs[d].append(raw_base)

      def _ReadTaskFile(path):
        with open(path) as f:
          parts = f.read().split()
          status, secs = parts
        return int(status), float(secs)

      st = {}

      # TODO: Open stderr too to get internal time?
      # Also what about exit code 2?  Translate to num_failed?

      parse_task_path = raw_base + '__parse.task.txt'
      st['parse_status'], st['parse_proc_secs'] = _ReadTaskFile(
          parse_task_path)
      
      osh2oil_task_path = raw_base + '__osh2oil.task.txt'
      st['osh2oil_status'], st['osh2oil_proc_secs'] = _ReadTaskFile(
          osh2oil_task_path)

      UpdateNodes(root_node, path_parts, st)

    PrintNodes(root_node)

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
