#!/usr/bin/python
"""
wild_report.py
"""

import csv
import glob
import os
import sys


def main(argv):
  action = argv[1]

  # TODO: copy from treemap/treesum
  if action == 'summarize-dirs':
    # lines and size, oops
    HEADER = (
        'filename',
        'parse_status', 'parse_proc_secs', 'parse_internal_secs',
        'osh2oil_status', 'osh2oil_proc_secs',
        )
    suffix = '__parse.task.txt'

    for line in sys.stdin:
      d = line.strip()

      paths = glob.glob(os.path.join(d, '*' + suffix))
      if not paths:
        continue

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
