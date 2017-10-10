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

      base_path = os.path.join('_tmp/wild', proj, rel_path)
      path_parts = base_path.split('/')[1:]  # get rid of _tmp/
      print path_parts

      d = os.path.dirname(base_path)
      dirs[d].append(base_path)

      file_stats = {}

      # TODO: Open stderr too to get internal time?
      parse_task_path = base_path + '__parse.task.txt'
      with open(parse_task_path) as f:
        try:
          x, y = f.read().split()
        except Exception:
          print >>sys.stderr, 'Error reading %s' % parse_task_path
          raise
        file_stats['parse_status'], file_stats['parse_proc_secs'] = x, y
      
      osh2oil_task_path = base_path + '__osh2oil.task.txt'
      with open(osh2oil_task_path) as f:
        try:
          x, y = f.read().split()
        except Exception:
          print >>sys.stderr, 'Error reading %s' % osh2oil_task_path
          raise
        file_stats['osh2oil_status'], file_stats['osh2oil_proc_secs'] = x, y

      print file_stats 
      UpdateNodes(root_node, path_parts, file_stats)
      continue

    #print(dirs)

    if False:
      paths = glob.glob(os.path.join(d, '*' + suffix))
      if not paths:
        #continue
        pass

      csv_path = os.path.join(d, 'RESULTS.csv')
      csv_out = csv.writer(open(csv_path, 'w'))
      csv_out.writerow(HEADER)

      for parse_task_path in paths:
        filename = os.path.basename(parse_task_path)
        filename = filename[:-len(suffix)]

        with open(parse_task_path) as f:
          parse_status, parse_proc_secs = f.read().split()

        osh2oil_task_path = os.path.join(d, filename + '__osh2oil.task.txt')
        with open(osh2oil_task_path) as f:
          osh2oil_status, osh2oil_proc_secs = f.read().split()

        row = (filename,
            parse_status, parse_proc_secs, '-',
            osh2oil_status, osh2oil_proc_secs)
        csv_out.writerow(row)

        # TODO:
        # - Append to a data structure instead of just raw CSV
        # - Update all parents with sums of failures and times, num_files,
        # num_lines, etc.


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
