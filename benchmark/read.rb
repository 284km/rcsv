#!/usr/bin/env ruby

require 'rcsv'
require 'benchmark/ips'

Rcsv.open("/tmp/file.csv", "w") do |csv|
  csv << ["player", "gameA", "gameB"]
  1000.times do
    csv << ['"Alice"', "84.0", "79.5"]
    csv << ['"Bob"', "20.0", "56.5"]
  end
end

Benchmark.ips do |x|
  x.report "Rcsv.foreach" do
    Rcsv.foreach("/tmp/file.csv") do |row|
    end
  end

  x.report "CSV#shift" do
    Rcsv.open("/tmp/file.csv") do |csv|
      while _line = csv.shift
      end
    end
  end

  x.report "Rcsv.read" do
    Rcsv.read("/tmp/file.csv")
  end

  x.report "Rcsv.table" do
    Rcsv.table("/tmp/file.csv")
  end
end
