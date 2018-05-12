#!/usr/bin/env ruby

# method redefine になってしまう...
# require "csv"
require "rcsv"

require "benchmark/ips"

csv_text = <<CSV
foo,bar,,baz
hoge,,temo,
roo,goo,por,kosh
CSV

convert_nil = ->(s) {s || ""}

Benchmark.ips do |r|
  r.report "not convert" do
    Rcsv.parse(csv_text)
  end
  r.report "converter" do
    Rcsv.parse(csv_text, converters: convert_nil)
  end
  r.report "option" do
    Rcsv.parse(csv_text, nil_value: "")
  end


  r.compare!
end
