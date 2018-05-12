#!/usr/bin/env ruby -w
# encoding: UTF-8
# frozen_string_literal: false

# tc_interface.rb
#
# Created by James Edward Gray II on 2005-10-31.

require_relative "base"
require "tempfile"

class TestCSV::Interface < TestCSV
  extend DifferentOFS

  def setup
    super
    @tempfile = Tempfile.new(%w"temp .csv")
    @tempfile.close
    @path = @tempfile.path

    File.open(@path, "wb") do |file|
      file << "1\t2\t3\r\n"
      file << "4\t5\r\n"
    end

    @expected = [%w{1 2 3}, %w{4 5}]
  end

  def teardown
    @tempfile.close(true)
    super
  end

  ### Test Read Interface ###

  def test_foreach
    Rcsv.foreach(@path, col_sep: "\t", row_sep: "\r\n") do |row|
      assert_equal(@expected.shift, row)
    end
  end

  def test_foreach_enum
    Rcsv.foreach(@path, col_sep: "\t", row_sep: "\r\n").zip(@expected) do |row, exp|
      assert_equal(exp, row)
    end
  end

  def test_open_and_close
    csv = Rcsv.open(@path, "r+", col_sep: "\t", row_sep: "\r\n")
    assert_not_nil(csv)
    assert_instance_of(CSV, csv)
    assert_not_predicate(csv, :closed?)
    csv.close
    assert_predicate(csv, :closed?)

    ret = Rcsv.open(@path) do |new_csv|
      csv = new_csv
      assert_instance_of(CSV, new_csv)
      "Return value."
    end
    assert_predicate(csv, :closed?)
    assert_equal("Return value.", ret)
  end

  def test_open_encoding_valid
    # U+1F600 GRINNING FACE
    # U+1F601 GRINNING FACE WITH SMILING EYES
    File.open(@path, "w") do |file|
      file << "\u{1F600},\u{1F601}"
    end
    Rcsv.open(@path, encoding: "utf-8") do |csv|
      assert_equal([["\u{1F600}", "\u{1F601}"]],
                   csv.to_a)
    end
  end

  # TODO:
  # def test_open_encoding_invalid
  #   # U+1F600 GRINNING FACE
  #   # U+1F601 GRINNING FACE WITH SMILING EYES
  #   File.open(@path, "w") do |file|
  #     file << "\u{1F600},\u{1F601}"
  #   end
  #   Rcsv.open(@path, encoding: "EUC-JP") do |csv|
  #     error = assert_raise(CSV::MalformedCSVError) do
  #       csv.shift
  #     end
  #     assert_equal("Invalid byte sequence in EUC-JP in line 1.",
  #                  error.message)
  #   end
  # end

  # TODO:
  # def test_open_encoding_nonexistent
  #   _output, error = capture_io do
  #     Rcsv.open(@path, encoding: "nonexistent") do
  #     end
  #   end
  #   assert_equal("path:0: warning: Unsupported encoding nonexistent ignored\n",
  #                error.gsub(/\A.+:\d+: /, "path:0: "))
  # end

  # TODO:
  # def test_open_encoding_utf_8_with_bom
  #   # U+FEFF ZERO WIDTH NO-BREAK SPACE, BOM
  #   # U+1F600 GRINNING FACE
  #   # U+1F601 GRINNING FACE WITH SMILING EYES
  #   File.open(@path, "w") do |file|
  #     file << "\u{FEFF}\u{1F600},\u{1F601}"
  #   end
  #   Rcsv.open(@path, encoding: "bom|utf-8") do |csv|
  #     assert_equal([["\u{1F600}", "\u{1F601}"]],
  #                  csv.to_a)
  #   end
  # end

  def test_parse
    data = File.binread(@path)
    assert_equal( @expected,
                  Rcsv.parse(data, col_sep: "\t", row_sep: "\r\n") )

    Rcsv.parse(data, col_sep: "\t", row_sep: "\r\n") do |row|
      assert_equal(@expected.shift, row)
    end
  end

  def test_parse_line
    row = Rcsv.parse_line("1;2;3", col_sep: ";")
    assert_not_nil(row)
    assert_instance_of(Array, row)
    assert_equal(%w{1 2 3}, row)

    # shortcut interface
    row = "1;2;3".parse_csv(col_sep: ";")
    assert_not_nil(row)
    assert_instance_of(Array, row)
    assert_equal(%w{1 2 3}, row)
  end

  def test_parse_line_with_empty_lines
    assert_equal(nil,       Rcsv.parse_line(""))  # to signal eof
    assert_equal(Array.new, Rcsv.parse_line("\n1,2,3"))
  end

  def test_read_and_readlines
    assert_equal( @expected,
                  Rcsv.read(@path, col_sep: "\t", row_sep: "\r\n") )
    assert_equal( @expected,
                  Rcsv.readlines(@path, col_sep: "\t", row_sep: "\r\n") )


    data = Rcsv.open(@path, col_sep: "\t", row_sep: "\r\n") do |csv|
      csv.read
    end
    assert_equal(@expected, data)
    data = Rcsv.open(@path, col_sep: "\t", row_sep: "\r\n") do |csv|
      csv.readlines
    end
    assert_equal(@expected, data)
  end

  def test_table
    table = Rcsv.table(@path, col_sep: "\t", row_sep: "\r\n")
    assert_instance_of(CSV::Table, table)
    assert_equal([[:"1", :"2", :"3"], [4, 5, nil]], table.to_a)
  end

  def test_shift  # aliased as gets() and readline()
    Rcsv.open(@path, "rb+", col_sep: "\t", row_sep: "\r\n") do |csv|
      assert_equal(@expected.shift, csv.shift)
      assert_equal(@expected.shift, csv.shift)
      assert_equal(nil, csv.shift)
    end
  end

  def test_enumerators_are_supported
    Rcsv.open(@path, col_sep: "\t", row_sep: "\r\n") do |csv|
      enum = csv.each
      assert_instance_of(Enumerator, enum)
      assert_equal(@expected.shift, enum.next)
    end
  end

  # TODO:
  # def test_nil_is_not_acceptable
  #   assert_raise_with_message ArgumentError, "Cannot parse nil as CSV" do
  #     Rcsv.new(nil)
  #   end
  # end

  def test_open_handles_prematurely_closed_file_descriptor_gracefully
    assert_nothing_raised(Exception) do
      Rcsv.open(@path) do |csv|
        csv.close
      end
    end
  end

  ### Test Write Interface ###

  # TODO:
  # def test_generate
  #   str = Rcsv.generate do |csv|  # default empty String
  #     assert_instance_of(CSV, csv)
  #     assert_equal(csv, csv << [1, 2, 3])
  #     assert_equal(csv, csv << [4, nil, 5])
  #   end
  #   assert_not_nil(str)
  #   assert_instance_of(String, str)
  #   assert_equal("1,2,3\n4,,5\n", str)
  #
  #   Rcsv.generate(str) do |csv|   # appending to a String
  #     assert_equal(csv, csv << ["last", %Q{"row"}])
  #   end
  #   assert_equal(%Q{1,2,3\n4,,5\nlast,"""row"""\n}, str)
  #
  #   out = Rcsv.generate("test") { |csv| csv << ["row"] }
  #   assert_equal("testrow\n", out)
  # end

  def test_generate_line
    line = Rcsv.generate_line(%w{1 2 3}, col_sep: ";")
    assert_not_nil(line)
    assert_instance_of(String, line)
    assert_equal("1;2;3\n", line)

    # shortcut interface
    line = %w{1 2 3}.to_csv(col_sep: ";")
    assert_not_nil(line)
    assert_instance_of(String, line)
    assert_equal("1;2;3\n", line)

    line = Rcsv.generate_line(%w"1 2", row_sep: nil)
    assert_equal("1,2", line)
  end

  def test_write_header_detection
    File.unlink(@path)

    headers = %w{a b c}
    Rcsv.open(@path, "w", headers: true) do |csv|
      csv << headers
      csv << %w{1 2 3}
      assert_equal(headers, csv.instance_variable_get(:@headers))
    end
  end

  def test_write_lineno
    File.unlink(@path)

    Rcsv.open(@path, "w") do |csv|
      lines = 20
      lines.times { csv << %w{a b c} }
      assert_equal(lines, csv.lineno)
    end
  end

  def test_write_hash
    File.unlink(@path)

    lines = [{a: 1, b: 2, c: 3}, {a: 4, b: 5, c: 6}]
    Rcsv.open( @path, "wb", headers:           true,
                           header_converters: :symbol ) do |csv|
      csv << lines.first.keys
      lines.each { |line| csv << line }
    end
    Rcsv.open( @path, "rb", headers:           true,
                           converters:        :all,
                           header_converters: :symbol ) do |csv|
      csv.each { |line| assert_equal(lines.shift, line.to_hash) }
    end
  end

  def test_write_hash_with_string_keys
    File.unlink(@path)

    lines = [{a: 1, b: 2, c: 3}, {a: 4, b: 5, c: 6}]
    Rcsv.open( @path, "wb", headers: true ) do |csv|
      csv << lines.first.keys
      lines.each { |line| csv << line }
    end
    Rcsv.open( @path, "rb", headers: true ) do |csv|
      csv.each do |line|
        csv.headers.each_with_index do |header, h|
          keys = line.to_hash.keys
          assert_instance_of(String, keys[h])
          assert_same(header, keys[h])
        end
      end
    end
  end

  def test_write_hash_with_headers_array
    File.unlink(@path)

    lines = [{a: 1, b: 2, c: 3}, {a: 4, b: 5, c: 6}]
    Rcsv.open(@path, "wb", headers: [:b, :a, :c]) do |csv|
      lines.each { |line| csv << line }
    end

    # test writing fields in the correct order
    File.open(@path, "rb") do |f|
      assert_equal("2,1,3", f.gets.strip)
      assert_equal("5,4,6", f.gets.strip)
    end

    # test reading CSV with headers
    Rcsv.open( @path, "rb", headers:    [:b, :a, :c],
                           converters: :all ) do |csv|
      csv.each { |line| assert_equal(lines.shift, line.to_hash) }
    end
  end

  def test_write_hash_with_headers_string
    File.unlink(@path)

    lines = [{"a" => 1, "b" => 2, "c" => 3}, {"a" => 4, "b" => 5, "c" => 6}]
    Rcsv.open(@path, "wb", headers: "b|a|c", col_sep: "|") do |csv|
      lines.each { |line| csv << line }
    end

    # test writing fields in the correct order
    File.open(@path, "rb") do |f|
      assert_equal("2|1|3", f.gets.strip)
      assert_equal("5|4|6", f.gets.strip)
    end

    # test reading CSV with headers
    Rcsv.open( @path, "rb", headers:    "b|a|c",
                           col_sep:    "|",
                           converters: :all ) do |csv|
      csv.each { |line| assert_equal(lines.shift, line.to_hash) }
    end
  end

  def test_write_headers
    File.unlink(@path)

    lines = [{"a" => 1, "b" => 2, "c" => 3}, {"a" => 4, "b" => 5, "c" => 6}]
    Rcsv.open( @path, "wb", headers:       "b|a|c",
                           write_headers: true,
                           col_sep:       "|" ) do |csv|
      lines.each { |line| csv << line }
    end

    # test writing fields in the correct order
    File.open(@path, "rb") do |f|
      assert_equal("b|a|c", f.gets.strip)
      assert_equal("2|1|3", f.gets.strip)
      assert_equal("5|4|6", f.gets.strip)
    end

    # test reading CSV with headers
    Rcsv.open( @path, "rb", headers:    true,
                           col_sep:    "|",
                           converters: :all ) do |csv|
      csv.each { |line| assert_equal(lines.shift, line.to_hash) }
    end
  end

  def test_write_headers_empty
    File.unlink(@path)

    Rcsv.open( @path, "wb", headers:       "b|a|c",
                           write_headers: true,
                           col_sep:       "|" ) do |csv|
    end

    File.open(@path, "rb") do |f|
      assert_equal("b|a|c", f.gets.strip)
    end
  end

  def test_append  # aliased add_row() and puts()
    File.unlink(@path)

    Rcsv.open(@path, "wb", col_sep: "\t", row_sep: "\r\n") do |csv|
      @expected.each { |row| csv << row }
    end

    test_shift

    # same thing using CSV::Row objects
    File.unlink(@path)

    Rcsv.open(@path, "wb", col_sep: "\t", row_sep: "\r\n") do |csv|
      @expected.each { |row| csv << CSV::Row.new(Array.new, row) }
    end

    test_shift
  end

  ### Test Read and Write Interface ###

  def test_filter
    assert_respond_to(CSV, :filter)

    expected = [[1, 2, 3], [4, 5]]
    Rcsv.filter( "1;2;3\n4;5\n", (result = String.new),
                in_col_sep: ";", out_col_sep: ",",
                converters: :all ) do |row|
      assert_equal(row, expected.shift)
      row.map! { |n| n * 2 }
      row << "Added\r"
    end
    assert_equal("2,4,6,\"Added\r\"\n8,10,\"Added\r\"\n", result)
  end

  def test_instance
    csv = String.new

    first = nil
    assert_nothing_raised(Exception) do
      first =  Rcsv.instance(csv, col_sep: ";")
      first << %w{a b c}
    end

    assert_equal("a;b;c\n", csv)

    second = nil
    assert_nothing_raised(Exception) do
      second =  Rcsv.instance(csv, col_sep: ";")
      second << [1, 2, 3]
    end

    assert_equal(first.object_id, second.object_id)
    assert_equal("a;b;c\n1;2;3\n", csv)

    # shortcuts
    assert_equal(STDOUT, Rcsv.instance.instance_eval { @io })
    assert_equal(STDOUT, CSV { |new_csv| new_csv.instance_eval { @io } })
  end

  def test_options_are_not_modified
    opt = {}.freeze
    assert_nothing_raised {  Rcsv.foreach(@path, opt)       }
    assert_nothing_raised {  Rcsv.open(@path, opt){}        }
    assert_nothing_raised {  Rcsv.parse("", opt)            }
    assert_nothing_raised {  Rcsv.parse_line("", opt)       }
    assert_nothing_raised {  Rcsv.read(@path, opt)          }
    assert_nothing_raised {  Rcsv.readlines(@path, opt)     }
    assert_nothing_raised {  Rcsv.table(@path, opt)         }
    assert_nothing_raised {  Rcsv.generate(opt){}           }
    assert_nothing_raised {  Rcsv.generate_line([], opt)    }
    assert_nothing_raised {  Rcsv.filter("", "", opt){}     }
    assert_nothing_raised {  Rcsv.instance("", opt)         }
  end
end
