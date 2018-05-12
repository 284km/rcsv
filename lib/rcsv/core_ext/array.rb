class Array # :nodoc:
  # Equivalent to CSV::generate_line(self, options)
  #
  #   ["CSV", "data"].to_csv
  #     #=> "CSV,data\n"
  def to_csv(**options)
    Rcsv.generate_line(self, options)
  end
end
