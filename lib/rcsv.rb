require "rcsv/rcsv"
require "rcsv/version"

require "stringio"
require "English"

require_relative "rcsv/table"
require_relative "rcsv/row"

class Rcsv
  # The error thrown when the parser encounters illegal CSV formatting.
  class MalformedCSVError < RuntimeError
    attr_reader :line_number
    alias_method :lineno, :line_number
    def initialize(message, line_number)
      @line_number = line_number
      super("#{message} in line #{line_number}.")
    end
  end

  #
  # This method is a shortcut for converting a single line of a CSV String into
  # an Array.  Note that if +line+ contains multiple rows, anything beyond the
  # first row is ignored.
  #
  # The +options+ parameter can be anything CSV::new() understands.
  #
  def self.parse_line(line, **options)
    # new(line, options).shift
    # self.parse(line, **options)
    self.parse(line, **options)&.flatten
  end

  #
  # This method is a shortcut for converting a single row (Array) into a CSV
  # String.
  #
  # The +options+ parameter can be anything CSV::new() understands.  This method
  # understands an additional <tt>:encoding</tt> parameter to set the base
  # Encoding for the output.  This method will try to guess your Encoding from
  # the first non-+nil+ field in +row+, if possible, but you may need to use
  # this parameter as a backup plan.
  #
  # The <tt>:row_sep</tt> +option+ defaults to <tt>$INPUT_RECORD_SEPARATOR</tt>
  # (<tt>$/</tt>) when calling this method.
  #
  def self.generate_line(row, **options)
    options = {row_sep: $INPUT_RECORD_SEPARATOR}.merge(options)
    str = String.new
    if options[:encoding]
      str.force_encoding(options[:encoding])
    elsif field = row.find { |f| not f.nil? }
      str.force_encoding(String(field).encoding)
    end
    # (new(str, options) << row).string
    new(options).generate_row(row)
  end







  attr_reader :write_options

  BOOLEAN_FALSE = [nil, false, 0, 'f', 'false']

  def self.parse(csv_data, options = {}, &block)
    #options = {
      #:column_separator => "\t",
      #:only_listed_columns => true,
      #:header => :use, # :skip, :none
      #:offset_rows => 10,
      #:columns => {
        #'a' => { # can be 0, 1, 2, ... -- column position
          #:alias => :a, # only for hashes
          #:type => :int,
          #:default => 100,
          #:match => '10'
        #},
        #...
      #}
    #}

    # TODO:
    return nil if csv_data.nil? || csv_data.empty?
    # options[:header] ||= :use
    options[:header] ||= :none
    raw_options = {}

    # raw_options[:col_sep] = options[:column_separator] && options[:column_separator][0] || ','
    raw_options[:col_sep] = options[:col_sep] && options[:col_sep][0] || ','
    raw_options[:quote_char] = options[:quote_char] && options[:quote_char][0] || '"'
    raw_options[:offset_rows] = 0
    raw_options[:nostrict] = options[:nostrict]
    raw_options[:parse_empty_fields_as] = options[:parse_empty_fields_as]
    raw_options[:buffer_size] = options[:buffer_size] || 1024 * 1024 # 1 MiB

# puts "# ========================================================================="
    if csv_data.is_a?(String)
      csv_data = StringIO.new(csv_data)
# puts "csv_data_is_a?(String)"
    elsif !(csv_data.respond_to?(:each_line) && csv_data.respond_to?(:read))
# puts "csv_data.respond_to?(:each_line) && csv_data.respond_to?(:read)"
      inspected_csv_data = csv_data.inspect
      raise ParseError.new("Supplied CSV object #{inspected_csv_data[0..127]}#{inspected_csv_data.size > 128 ? '...' : ''} is neither String nor looks like IO object.")
    end

    if csv_data.respond_to?(:external_encoding)
      raw_options[:output_encoding] = csv_data.external_encoding.to_s
    end

    initial_position = csv_data.pos

# puts "options[:header]: #{options[:header]}"
    case options[:header]
    when :use
# puts "csv_data: #{csv_data.each_line.first}"
# puts "StringIO: #{StringIO.new(csv_data.each_line.first.to_s)}"
# puts "raw_options: #{raw_options}"
      # TODO:
      header = if csv_data.each_line.first.nil?
                 nil
               else
                 # header = self.raw_parse(StringIO.new(csv_data.each_line.first), raw_options).first
                 self.raw_parse(StringIO.new(csv_data.each_line.first), raw_options).first
               end
      raw_options[:offset_rows] = corrected_offset_rows(options[:offset_rows])
    when :skip
      header = (0..(csv_data.each_line.first.split(raw_options[:col_sep]).count)).to_a
      raw_options[:offset_rows] = corrected_offset_rows(options[:offset_rows])
    when :none
# puts "split: #{csv_data.each_line.first.split(raw_options[:col_sep])}"
      header = (0..(csv_data.each_line.first.split(raw_options[:col_sep]).count)).to_a
    end
# puts "header: #{header}"

    raw_options[:row_as_hash] = options[:row_as_hash] # Setting after header parsing

# puts "options[:columns]: #{options[:columns]}"
    if options[:columns]
      only_rows = []
      except_rows = []
      row_defaults = []
      column_names = []
      row_conversions = ''

      header.each do |column_header|
        column_options = options[:columns][column_header]
        if column_options
          if (options[:row_as_hash])
            column_names << (column_options[:alias] || column_header)
          end

          row_defaults << column_options[:default] || nil

          only_rows << case column_options[:match]
          when Array
            column_options[:match]
          when nil
            nil
          else
            [column_options[:match]]
          end

          except_rows << case column_options[:not_match]
          when Array
            column_options[:not_match]
          when nil
            nil
          else
            [column_options[:not_match]]
          end

          row_conversions << case column_options[:type]
          when :int
            'i'
          when :float
            'f'
          when :string
            's'
          when :bool
            'b'
          when nil
            's' # strings by default
          else
            fail "Unknown column type #{column_options[:type].inspect}."
          end
        elsif options[:only_listed_columns]
          column_names << nil
          row_defaults << nil
          only_rows << nil
          except_rows << nil
          row_conversions << ' '
        else
          column_names << column_header
          row_defaults << nil
          only_rows << nil
          except_rows << nil
          row_conversions << 's'
        end
      end

      raw_options[:column_names] = column_names if options[:row_as_hash]
      raw_options[:only_rows] = only_rows unless only_rows.compact.empty?
      raw_options[:except_rows] = except_rows unless except_rows.compact.empty?
      raw_options[:row_defaults] = row_defaults unless row_defaults.compact.empty?
      raw_options[:row_conversions] = row_conversions
    end

# puts "initial_position: #{initial_position}"
# puts "raw_options: #{raw_options}"
# puts "raw_parse: #{self.raw_parse(csv_data, raw_options, &block)}"
# puts "csv_data: #{csv_data}"
    csv_data.pos = initial_position
    return self.raw_parse(csv_data, raw_options, &block)
  end

  def initialize(write_options = {})
    @write_options = write_options
    # @write_options[:column_separator] ||= ','
    @write_options[:col_sep] ||= ','
    # @write_options[:newline_delimiter] ||= $INPUT_RECORD_SEPARATOR
    @write_options[:row_sep] ||= $INPUT_RECORD_SEPARATOR
    @write_options[:header] ||= false

    @quote = '"'
    @escaped_quote = @quote * 2
    @quotable_chars = Regexp.new('[%s%s%s]' % [
      # Regexp.escape(@write_options[:column_separator]),
      Regexp.escape(@write_options[:col_sep]),
      # Regexp.escape(@write_options[:newline_delimiter]),
      Regexp.escape(@write_options[:row_sep]),
      Regexp.escape(@quote)
    ])
  end

  def write(io, &block)
    io.write generate_header if @write_options[:header]
    while row = yield
      io.write generate_row(row)
    end
  end

  def generate_header
    return @write_options[:columns].map { |c|
      c[:name].to_s
    # }.join(@write_options[:column_separator]) << @write_options[:newline_delimiter]
    }.join(@write_options[:col_sep]) << @write_options[:row_sep]
  end

  def generate_row(row)
    # column_separator = @write_options[:column_separator]
    column_separator = @write_options[:col_sep]
    csv_row = ''
    max_index = row.size - 1

    row.each_with_index do |field, index|
      unquoted_field = process(field, @write_options[:columns] && @write_options[:columns][index])
      csv_row << (unquoted_field.match(@quotable_chars) ? "\"#{unquoted_field.gsub(@quote, @escaped_quote)}\"" : unquoted_field)
      csv_row << column_separator unless index == max_index
    end

    # return csv_row << @write_options[:newline_delimiter]
    return csv_row << @write_options[:row_sep]
  end

  protected

  def process(field, column_options)
    return '' if field.nil?
    return case column_options && column_options[:formatter]
    when :strftime
      format = column_options[:format] || "%Y-%m-%d %H:%M:%S %z"
      field.strftime(format)
    when :printf
      format = column_options[:format] || "%s"
      printf_options = column_options[:printf_options]
      printf_options ? sprintf(format, printf_options.merge(:field => field)) : sprintf(format, field)
    when :boolean
      BOOLEAN_FALSE.include?(field.respond_to?(:downcase) ? field.downcase : field) ? 'false' : 'true'
    else
      field.to_s
    end
  end

  private

  def self.corrected_offset_rows(offset_rows)
    return 1 if offset_rows.nil? || offset_rows <= 0

    offset_rows
  end
end

require_relative "rcsv/core_ext/array"
require_relative "rcsv/core_ext/string"
