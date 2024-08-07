# encoding: binary

#  Copyright (c) 2016 Phusion Holding B.V.
#
#  "Union Station" and "Passenger" are trademarks of Phusion Holding B.V.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.

require 'strscan'

module CxxHintedParser
  class Parser
    STRUCT_BEGIN_HINT = /- ?begin hinted parseable (struct|class) ?-/
    STRUCT_END_HINT = /- ?end hinted parseable (struct|class) ?-/
    FIELD_HINT = /@hinted_parseable$/
    ALL_HINTS = Regexp.union(STRUCT_BEGIN_HINT, STRUCT_END_HINT, FIELD_HINT)

    attr_reader :structs
    attr_reader :errors

    def self.load_file(path)
      File.open(path, 'rb') do |f|
        Parser.new(f.read)
      end
    end

    def initialize(str)
      @str = str
      @scanner = StringScanner.new(str)
      @structs = {}
      @errors = []
      @newline_positions = [0]
    end

    def parse
      index_line_endings
      while !@scanner.eos?
        matched = @scanner.skip_until(ALL_HINTS)
        break if !matched
        process_match
      end
      self
    end

    def has_errors?
      !errors.empty?
    end

  private
    Field = Struct.new(:type, :name, :metadata)
    Error = Struct.new(:line, :column, :message)

    def index_line_endings
      pos = 0
      @str.split("\n", -1).each do |line|
        pos += line.size + 1
        @newline_positions << pos
      end
    end

    def process_match
      if @scanner.matched =~ STRUCT_BEGIN_HINT
        process_struct_begin_hint
      elsif @scanner.matched =~ STRUCT_END_HINT
        process_struct_end_hint
      else
        process_field_hint
      end
    end

    def process_struct_begin_hint
      if @current_struct
        error 'Class/struct begin hint encountered, but previous class/struct begin hint was never ended'
      end

      process_until_end_of_comment
      regex = /(class|struct)\s+(\w+)/m
      if match = @scanner.scan_until(regex)
        match =~ regex
        @current_struct = $2
        @structs[@current_struct] = []
      else
        error 'Unable to parse class/struct name'
      end
    end

    def process_struct_end_hint
      if @current_struct
        @current_struct = nil
      else
        error 'Class/struct end hint encountered, but no corresponding class/struct begin hint was found'
      end
    end

    def process_field_hint
      metadata = process_until_end_of_comment
      @scanner.skip(/\s+/m)
      begin_pos = @scanner.pos

      regex = /(.+?)\s+(\**\w+(\[.*?\])*)(\s*:\s*\d+)?\s*;/m
      if match = @scanner.scan(regex)
        if match =~ /\//
          # We skipped to the next comment, so something went wrong.
          temporarily_set_pos(begin_pos) do
            error 'Unable to parse field name and type'
          end
        else
          match =~ regex
          type = $1
          name = $2
          type, name = move_pointer_and_array_notations_to_type(type, name)
          type = strip_attribute(type)

          if @current_struct
            @structs[@current_struct] << Field.new(type, name, metadata)
          else
            temporarily_set_pos(begin_pos) do
              error 'Field hint encountered, but no corresponding class/struct begin hint was found'
            end
          end
        end
      else
        error 'Unable to parse field name and type'
      end
    end

    def process_until_end_of_comment
      begin_pos = @scanner.pos

      # Skip until end of comment
      @scanner.pre_match =~ /.*\n(.*)\Z/m
      last_line = $1
      if last_line =~ /^\s*\/\//
        # Single-line comment
        done = false
        while !done
          # Skip until next line
          @scanner.skip_until(/\n/m)
          # Is this also another comment? If so, continue looping
          done = @scanner.post_match !~ /\A\s*\/\//
        end
      else
        # Assume multi-line comment
        @scanner.skip_until(/\*\//)
      end

      end_pos = @scanner.pos

      # Extract all metadata from the location where
      # we encountered `@hinted_parseable` until end
      # of comment
      metadata = {}
      @str[begin_pos..end_pos].split("\n").each do |line|
        if line =~ /^[\s\*\/]*@(\w+)(.*)$/
          key = $1
          value = $2.strip
          if value.empty?
            metadata[key.to_sym] = true
          else
            metadata[key.to_sym] = value
          end
        end
      end

      metadata
    end

    def strip_attribute(type)
      type = type.gsub(/__attribute__\(.*?\)+/, '')
      type.split(/\s+/).reject { |x| x.empty? }.join(' ')
    end

    def move_pointer_and_array_notations_to_type(type, name)
      type = type.dup
      name = name.dup

      if name =~ /^(\*+)/
        type << " #{$1}"
        name.gsub!(/^\*+/, '')
      end
      if name =~ /(\[.*?\]+)$/
        type << " #{$1}"
        name.gsub!(/\[.*?\]+$/, '')
      end

      [type, name]
    end

    def temporarily_set_pos(pos)
      current_pos = @scanner.pos
      @scanner.pos = pos
      begin
        yield
      ensure
        @scanner.pos = current_pos
      end
    end

    def line_and_column(pos = @scanner.pos)
      low = 0
      high = @newline_positions.size - 1
      while low <= high
        mid = (low + high) / 2
        if @newline_positions[mid] >= pos
          high = mid - 1
        else
          low = mid + 1
        end
      end

      if @newline_positions[low] == pos
        [low + 1, pos - @newline_positions[low] + 1]
      else
        [high + 1, pos - @newline_positions[high] + 1]
      end
    end

    def error(message)
      line, column = line_and_column
      @errors << Error.new(line, column, message)
    end
  end
end
