#!/usr/bin/env ruby

require "rcsv"
require "optparse"

require "benchmark/ips"

n_rows = 1000

parser = OptionParser.new
parser.on("--n-rows=N", Integer,
          "The number of rows to be parsed",
          "(#{n_rows})") do |n|
  n_rows = n
end
parser.parse!(ARGV)

Benchmark.ips do |x|
  alphas = ["AAAAA"] * 50
  unquoted = (alphas.join(",") + "\r\n") * n_rows
  quoted = (alphas.map { |s| %("#{s}") }.join(",") + "\r\n") * n_rows
  inc_col_sep = (alphas.map { |s| %(",#{s}") }.join(",") + "\r\n") * n_rows
  inc_row_sep = (alphas.map { |s| %("#{s}\r\n") }.join(",") + "\r\n") * n_rows

  hiraganas = ["あああああ"] * 50
  enc_utf8 = (hiraganas.join(",") + "\r\n") * n_rows
  enc_sjis = enc_utf8.encode("Windows-31J")

  x.report("unquoted") { Rcsv.parse(unquoted) }
  x.report("quoted") { Rcsv.parse(quoted) }
  x.report("include col_sep") { Rcsv.parse(inc_col_sep) }
  x.report("include row_sep") { Rcsv.parse(inc_row_sep) }
  x.report("encode utf-8") { Rcsv.parse(enc_utf8) }
  x.report("encode sjis") { Rcsv.parse(enc_sjis) }
end
