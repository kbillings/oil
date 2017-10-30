#!/usr/bin/Rscript
#
# osh-parser.R
#
# Analyze output from shell scripts.

library(dplyr)
library(tidyr)

Log = function(fmt, ...) {
  cat(sprintf(fmt, ...))
  cat('\n')
}

main = function(argv) {
  # TODO: join multiple?
  # Or have pairs?
  # Should we join pairs first?
  # How to extract the Interpreter: OVM?  for OSH only
  # assert that the number of lines are the same or what?

  # TODO:
  # shell_name, shell_id (version and build tools)
  # host_name, host_id (kernel and distro and so forth)
  #
  # and then infer "shell" and "host" from these
  # osh-ovm and osh-host-cpython

  # usage:
  # out_dir, TIMES... and then "lines.csv" is automatcailly joined?
  #


  out_dir = argv[[1]]

  hosts = list()
  for (i in 2:length(argv)) {
    times_path = argv[[i]]
    lines_path = gsub('.times.', '.lines.', times_path, fixed = T)

    Log('times: %s', times_path)
    Log('lines: %s', lines_path)

    times = read.csv(times_path)
    lines = read.csv(lines_path)

    # Remove failures
    times %>% filter(status == 0) %>% select(-c(status)) -> times

    # Add the number of lines, joining on path, and compute lines/sec
    # TODO: Is there a better way compute lines_per_ms and then drop
    # lines_per_sec?
    times %>%
      left_join(lines, by = c('path')) %>%
      mutate(elapsed_ms = elapsed_secs * 1000,
             lines_per_ms = num_lines / elapsed_ms) %>%
      select(-c(elapsed_secs)) ->
      host_rows

    hosts[[i-1]] = host_rows
  }
  all_times = bind_rows(hosts)
  print(all_times)

  # status, elapsed, shell, path
  #times = read.csv(argv[[2]])
  return()

  # TODO:
  # - compute lines per second for every cell?

  #print(lines)
  #print(times)

  # Remove failures
  times %>% filter(status == 0) %>% select(-c(status)) -> times

  # Add the number of lines, joining on path, and compute lines/sec
  # TODO: Is there a better way compute lines_per_ms and then drop lines_per_sec?
  times %>%
    left_join(lines, by = c('path')) %>%
    mutate(elapsed_ms = elapsed_secs * 1000,
           lines_per_ms = num_lines / elapsed_ms) %>%
    select(-c(elapsed_secs)) ->
    joined
  #print(joined)

  # Summarize rates
  joined %>%
    group_by(shell_id) %>%
    summarize(total_lines = sum(num_lines), total_ms = sum(elapsed_ms)) %>%
    mutate(lines_per_ms = total_lines / total_ms) ->
    rate_summary

  # Put OSH last!
  #first = rate_summary %>% filter(shell != 'osh')
  #last = rate_summary %>% filter(shell == 'osh')
  #rate_summary = bind_rows(list(first, last))
  print(rate_summary)

  # Elapsed seconds by file and shell
  joined %>%
    select(-c(lines_per_ms)) %>% 
    spread(key = shell_id, value = elapsed_ms) %>%
    arrange(num_lines) ->
    elapsed
    #select(c(bash, dash, mksh, zsh, osh, num_lines, path)) ->
  print(elapsed)

  # Rates by file and shell
  joined %>%
    select(-c(elapsed_ms)) %>% 
    spread(key = shell_id, value = lines_per_ms) %>%
    arrange(num_lines) ->
    rate
    #select(c(bash, dash, mksh, zsh, osh, num_lines, path)) ->
  print(rate)

  write.csv(elapsed, file.path(out_dir, 'elapsed.csv'), row.names = F)
  write.csv(rate, file.path(out_dir, 'rate.csv'), row.names = F)
  write.csv(rate_summary, file.path(out_dir, 'rate_summary.csv'), row.names = F)

  Log('Wrote %s', out_dir)

  Log('PID %d done', Sys.getpid())
}

if (length(sys.frames()) == 0) {
  # increase ggplot font size globally
  #theme_set(theme_grey(base_size = 20))

  main(commandArgs(TRUE))
}
