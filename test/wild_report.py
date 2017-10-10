#!/usr/bin/python
"""
wild_report.py
"""

import csv
import glob
import os
import sys
from collections import defaultdict


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


    # Collect work into dirs
    for line in sys.stdin:
      #d = line.strip()
      proj, abs_path, rel_path = line.split()
      print proj, '-', abs_path, '-', rel_path

      base_path = os.path.join('_tmp/wild', proj, rel_path)
      print base_path
      d = os.path.dirname(base_path)
      dirs[d].append(base_path)
      continue

    print(dirs)

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
