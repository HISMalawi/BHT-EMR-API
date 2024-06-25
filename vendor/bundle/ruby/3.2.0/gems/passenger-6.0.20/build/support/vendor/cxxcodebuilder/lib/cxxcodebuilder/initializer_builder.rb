# encoding: utf-8

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

module CxxCodeBuilder
  # Builds array and struct initialization code.
  class InitializerBuilder
    def initialize(builder, start_character, end_character)
      @builder = builder
      @start_character = start_character
      @end_character = end_character
      @elements = []
    end

    # Adds an array/struct initializer element to the internal buffer.
    # The code is added verbatim, so you can supply expressions. If you
    # want to add a string element, use `#string_element` instead.
    #
    # Example:
    #
    #   array_initializer do
    #     element '1 + 2'
    #   end
    #
    # Output:
    #
    #   [
    #       1 + 2
    #   ]
    def element(code)
      @elements << code
    end

    # Adds an array/struct initializer string element to the internal buffer.
    #
    # Example:
    #
    #   array_initializer do
    #     string_element 'hello world'
    #   end
    #
    # Output:
    #
    #   [
    #       "hello world"
    #   ]
    def string_element(str)
      element(str.inspect)
    end

    # Adds an array initializer (in the form of `[x, y, z]`) to the internal
    # buffer. This works exactly the same as `Builder#array_initializer`, and
    # allows you to nest an array initializer inside a parent array/struct
    # initializer.
    #
    # Example:
    #
    #   struct_initializer do
    #     array_initializer_element do
    #       element 1
    #       element 2
    #     end
    #     array_initializer_element do
    #       element 3
    #       element 4
    #     end
    #   end
    #
    # Output:
    #
    #   {
    #       [
    #           1,
    #           2
    #       ],
    #       [
    #           3,
    #           4
    #       ]
    #   }
    def array_initializer_element(&block)
      subbuilder = InitializerBuilder.new(@builder, '[', ']')
      subbuilder.instance_eval(&block)
      @elements << subbuilder
    end

    # Adds a struct initializer (in the form of `{x, y, z}`) to the internal
    # buffer. This works exactly the same as `Builder#struct_initializer`, and
    # allows you to nest a struct initializer inside a parent array/struct
    # initializer.
    #
    # Example:
    #
    #   array_initializer do
    #     struct_initializer_element do
    #       string_element 'Joe'
    #       element 1
    #     end
    #     struct_initializer_element do
    #       string_element 'Jane'
    #       element 2
    #     end
    #   end
    #
    # Output:
    #
    #   [
    #       {
    #           "Joe",
    #           1
    #       },
    #       {
    #           "Jane",
    #           2
    #       }
    #   ]
    def struct_initializer_element(&block)
      subbuilder = InitializerBuilder.new(@builder, '{', '}')
      subbuilder.instance_eval(&block)
      @elements << subbuilder
    end

    alias array_element array_initializer_element
    alias struct_element struct_initializer_element

    # @private
    def write_code_without_newline
      @builder.add_code(@start_character)
      @builder.indent do
        @elements.each_with_index do |elem, i|
          if elem.respond_to?(:write_code_without_newline)
            elem.write_code_without_newline
          else
            @builder.add_code_without_newline(elem)
          end

          if i != @elements.size - 1
            @builder.add_raw_code(',')
          end
          @builder.newline
        end
      end
      @builder.add_code_without_newline(@end_character)
    end
  end
end
