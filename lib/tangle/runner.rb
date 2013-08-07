require 'optparse'
require 'json'
require 'set'

module Tangle
  class Runner
    def initialize(mode, files, options)
      @mode = mode
      @files = files
      @options = { :keys => ['id'], :attach_keys => ['children'], :out => STDOUT }.merge options
    end

    def run
      data = @files.map { |f| read_json(f) }
      data_by_file_by_key = []
      data.each_with_index do |json, index|
        file_key = get_key(index)
        data_by_file_by_key << {}
        json.each do |row|
          key_value = row[file_key]
          if key_value
            if data_by_file_by_key[index][key_value] && @mode == 'merge'
              raise ArgumentError, "Duplicate key found in first file, aborting." if index == 0
            else
              data_by_file_by_key[index][key_value] ||= []
              data_by_file_by_key[index][key_value] << row # TODO: check
            end
          end
        end
      end

      case @mode
      when 'merge'
        all_keys = data_by_file_by_key.map(&:keys).flatten.uniq
        all = all_keys.map do |key|
          data_by_file_by_key.each_with_index.reduce({}) do |memo, (file_data,index)|
            memo.merge(file_data[key] && file_data[key].first || {})
          end
        end
      when 'attach'
        raise ArgumentError, "Must supply `attach_keys` if more than one file attached." if @options[:attach_keys].size < @files.size - 1 && @files.size > 2
        all_keys = data_by_file_by_key.first.keys
        all = all_keys.map do |key|
          base = data_by_file_by_key.first[key].first
          data_by_file_by_key[1..2].each_with_index do |file_data, index|
            base.merge!({ @options[:attach_keys][index] => file_data[key] || [] })
          end
          base
        end
      end

      all.each do |row|
        @options[:out].puts row.to_json
      end
    end

    private

    def read_json(file)
      File.open(file, 'r').each_line.map do |line|
        JSON.parse(line)
      end
    end

    def get_key(index)
      @options[:keys].size > 1 ? @options[:keys][index] : @options[:keys].first
    end
  end
end
