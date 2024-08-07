# encoding: utf-8

#  Copyright (c) 2016-2018 Phusion Holding B.V.
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

require File.expand_path(File.dirname(__FILE__) + '/initializer_builder')

module CxxCodeBuilder
  # Builds C/C++ code. Use it as follows:
  #
  #  1. Create a CxxCodeBuilder::Builder object.
  #  2. Call API methods in the Builder object to generate C/C++ code.
  #  3. When done, call `#to_s` to obtain the generated code.
  #
  # There are two ways to use CxxCodeBuilder::Builder:
  #
  #  1. By passing a block to the constructor. The block is evaluated in
  #     the context of the builder object, so inside the block you have
  #     access to all the API methods of the Builder class. See README.md
  #     for an example of this usage.
  #  2. By calling the API methods of the Builder class, without passing
  #     a block to the constructor.
  #
  # ## Internal buffer
  #
  # Builder has an internal buffer containing the code generated so far.
  # Most API methods, such as `#function` and `#field`, generate new code
  # and append to this internal buffer. `#to_s` returns the contents of
  # the buffer.
  #
  # ## Indentation
  #
  # Builder keeps track of the current indentation level and generates
  # code accordingly. You can temporarily increase it with the `indent`
  # method. Builder generates tabs for indentation.
  class Builder
    def initialize(&block)
      @indent_string = "\t"
      @indent_level = 0
      @code = ""

      if block
        instance_eval(&block)
      end
    end

    # Customizes the indentation string. The default is a tab,
    # but you can use this to set it to e.g. 4 spaces. You should
    # call this method as early as possible because it won't
    # affect the indentation of already generated code.
    def set_indent_string(str)
      @indent_string = str
    end

    # Adds some code to the internal buffer. Before adding to the internal
    # buffer, extraneous indentation and leading and trailing empty lines in
    # `code` are removed, and new  indentation is added based on the current
    # indentation level. The code is suffixed with a newline.
    #
    #
    # Example 1:
    #
    #   add_code 'foo();'
    #
    # Output 1:
    #
    #   foo();
    #
    #
    # Example 2:
    #
    #   # The argument contains extraneous leading and trailing empty lines,
    #   # as well as extraneous indenting.
    #   add_code %q{
    #     foo();
    #     if (true) {
    #         bar();
    #     }
    #   }
    #
    # Output 2 (extraneous leading/trailing newlines and extraneous indenting removed):
    #
    #   foo();
    #   if (true) {
    #       bar();
    #   }
    def add_code(code)
      add_code_without_newline(code)
      newline
    end

    # Like `#add_code`, but does not suffix the generated code with a newline.
    def add_code_without_newline(code)
      @code << reindent(unindent(code.to_s), @indent_string * @indent_level, true)
    end

    # Adds some raw code to the internal buffer. Unlike `#add_code`, no
    # preprocessing is performed to remove extraneous newlines or indenting.
    def add_raw_code(code)
      @code << code
    end

    # Temporarily increase the indentation level by 1. This new indentation
    # level is only active inside the given block.
    #
    # Example:
    #
    #   add_code 'foo();'
    #
    #   indent do
    #     add_code 'bar();'
    #   end
    #
    # Output:
    #
    #   foo();
    #       bar();
    def indent
      @indent_level += 1
      begin
        yield
      ensure
        @indent_level -= 1
      end
    end

    # Adds a newline to the internal buffer.
    def separator
      @code << "\n"
    end

    alias newline separator

    # Adds an `#include` statement to the internal buffer.
    # `header_name` is verbatim added to the statement, so you
    # need to pass either `"<header_name.h>"` or `'"header_name.h"'`
    # as argument.
    #
    # Example:
    #
    #   include '<stdio.h>'
    #   include '"Config.h"'
    #
    # Output:
    #
    #   #include <stdio.h>
    #   #include "Config.h"
    def include(header_name)
      add_code("#include #{header_name}")
    end

    # Adds a `#define` statement to the internal buffer.
    # `macro` is verbatim added to the statement. If you want
    # to #define a string constant then you should use the
    # `#define_string` method.
    #
    # Example:
    #
    #   define 'HAVE_STDINT_H'
    #   define 'FOO bar'
    #   define 'TWO 1 + 2'
    #
    # Output:
    #
    #   #define HAVE_STDINT_H
    #   #define FOO bar
    #   #define TWO 1 + 2
    def define(macro)
      add_code("#define #{macro}")
    end

    # Adds a `#define` statement to the internal buffer for defining
    # a string macro.
    #
    # Example:
    #
    #   define 'NAME', 'Joe Dalton'
    #
    # Output:
    #
    #   #define NAME "Joe Dalton"
    def define_string(name, value)
      define("#{name} #{str_val(value)}")
    end

    # Adds header guard macros to the internal buffer. Expects
    # a block which generates the code to insert inside the guard.
    #
    # Example:
    #
    #   guard_macros 'MY_HEADER_H' do
    #     field 'int foo'
    #   end
    #
    # Output:
    #
    #   #ifndef MY_HEADER_H
    #   #define MY_HEADER_H
    #
    #   int foo;
    #
    #   #endif /* MY_HEADER_H */
    def guard_macros(name)
      add_code("#ifndef #{name}")
      define(name)
      separator
      yield
      separator
      add_code("#endif /* #{name} */")
    end

    # Adds a comment to the internal buffer. Before adding to the internal
    # buffer, extraneous indentation and leading and trailing empty lines in
    # `text` are removed, and new indentation is added based on the current
    # indentation level. The text is also prefixed with the '*' character.
    #
    # Example:
    #
    #   comment "hello\nworld"
    #   comment %q{
    #     foo
    #     bar
    #   }
    #
    # Output:
    #
    #   /*
    #    * hello
    #    * world
    #    */
    #   /*
    #    * foo
    #    * bar
    #    */
    def comment(text, indent_level = 0)
      add_code '/*'
      prefix = @indent_string * @indent_level
      prefix << ' * '
      if indent_level > 0
        prefix << ' ' * indent_level
      end
      @code << reindent(unindent(text.to_s), prefix, false)
      @code << "\n"
      add_code_without_newline '-'
      @code.gsub!(/-\Z/, ' ')
      add_raw_code "*/\n"
    end

    # Adds a struct definition to the internal buffer. Expects a block
    # in which you must define the struct's contents. Inside the block
    # you can use any Builder API methods, but you are most likely
    # interested in `#member`, `#comment`, `#separator` and `#function`.
    #
    # Example:
    #
    #   struct 'Car' do
    #     comment "The car's name"
    #     member 'string name'
    #
    #     separator
    #     member 'unsigned int seats'
    #   end
    #
    # Outputs:
    #
    #   struct Car {
    #       /*
    #        * The car's name.
    #        */
    #       string name;
    #
    #       unsigned int seats;
    #   };
    def struct(name)
      add_code "struct #{name} {"
      indent do
        yield
      end
      add_code '};'
    end

    # Adds a struct typedef definition to the internal buffer. This works
    # like the `#struct` method, but outputs a typedef struct instead.
    #
    # Example:
    #
    #   typedef_struct 'Car' do
    #     comment "The car's name"
    #     member 'string name'
    #
    #     separator
    #     member 'unsigned int seats'
    #   end
    #
    # Outputs:
    #
    #   typedef struct {
    #       /*
    #        * The car's name.
    #        */
    #       string name;
    #
    #       unsigned int seats;
    #   } Car;
    def typedef_struct(name)
      add_code 'typedef struct {'
      indent do
        yield
      end
      add_code "} #{name};"
    end

    # Adds a function definition to the internal buffer. There are two ways to
    # supply the function body. The first is by passing a string. The second is
    # by passing a block, which is expected to use Builder API methods to
    # generate code for the body.
    #
    # If a string is passed, then extraneous indentation and leading and trailing
    # empty lines inside it are removed.
    #
    # No matter how the body is body is supplied, the generated body is indented.
    #
    # Example:
    #
    #   function 'static void foo(int x)', %q{
    #       printf("x = %d\n", x);
    #   }
    #
    #   function 'static void bar(int x)' do
    #     add_code 'printf("x = %d\n", x);'
    #   end
    #
    # Output:
    #
    #   static void
    #   foo(int x) {
    #       printf("x = %d\n", x);
    #   }
    #
    #   static void
    #   bar(int x) {
    #       printf("x = %d\n", x);
    #   }
    def function(declaration, body = nil, &block)
      function_or_constructor(declaration, nil, body, &block)
    end

    # Adds a C++ constructor definition to the internal buffer. This is
    # like #function, but also allows defining member initializers.
    # `member_initializers` is a Hash which maps field names to their
    # initialization expressions.
    #
    # Example:
    #
    #   member_initializers = {
    #     'name' => '"Delorean"',
    #     'color' => 'COLOR_RED'
    #   }
    #   constructor('Car::Car()', member_initializers) do
    #     add_code 'printf("Created a car\n");'
    #   end
    #
    # Output:
    #
    #   Car::Car()
    #       : name("Delorean"),
    #         color(COLOR_RED)
    #   {
    #       printf("Created a car\n");
    #   }
    def constructor(declaration, member_initializers, body = nil, &block)
      function_or_constructor(declaration, member_initializers, body, &block)
    end

    def function_or_constructor(declaration, member_initializers, body = nil)
      declaration =~ /(.*?)([a-z0-9_:]+)\s*\((.*)\s*(const)?/mi
      return_type_and_attributes = $1
      name_and_params = "#{$2}(#{$3} #{$4}".strip

      add_code return_type_and_attributes.strip
      if member_initializers && !member_initializers.empty?
        add_code "#{name_and_params.strip}"
        indent do
          member_initializers.each_with_index do |elem, i|
            field, expr = elem
            if i == 0
              prefix = @indent_string * @indent_level + ': '
            else
              prefix = @indent_string * @indent_level + '  '
            end
            if i == member_initializers.size - 1
              suffix = nil
            else
              suffix = ','
            end
            add_raw_code("#{prefix}#{field}(#{expr})#{suffix}\n")
          end
        end
        add_code '{'
      else
        add_code "#{name_and_params.strip} {"
      end

      indent do
        if block_given?
          yield
        else
          add_code body
        end
      end
      add_code '}'
      separator
    end

    # Adds a field/member/variable definition to the internal buffer.
    # You can optionally supply a value, either by passing it directly as
    # an argument, or by passing a block which will generate the code for
    # the value.
    #
    # When supplying an argument, the argument is added verbatim to the
    # internal buffer, so you can even supply an expression. If you want to
    # set the value to a string, then you should use the `#str_val` helper
    # method. See the example below.
    #
    # The block form is especially useful for generating
    # array/struct initializer code (see also `#array_initializer` and
    # `#struct_initializer` in that case).
    #
    # Example:
    #
    #     field('int a')
    #     field('int b', 123);
    #     field('int c', '1 + 2')
    #     field('const char *str', str_val("hello world"));
    #
    #     separator
    #
    #     field('int magicNumbers[]') do
    #       array_initializer do
    #         element 1
    #         element 2
    #       end
    #     end
    #
    #     separator
    #
    #     field('const char *magicStrings[]') do
    #       array_initializer do
    #         string_element "foo"
    #         # Equivalent:
    #         element str_val("foo")
    #       end
    #     end
    #
    # Output:
    #
    #     int a;
    #     int b = 123;
    #     int c = 1 + 2;
    #     const char *str = "hello world";
    #
    #     int magicNumbers[] = [
    #         1,
    #         2
    #     ];
    #
    #     const char *magicStrings[] = [
    #         "foo",
    #         "foo"
    #     ];
    #
    def field(declaration, value = nil)
      if block_given?
        add_code_without_newline "#{declaration} ="
        add_raw_code ' '
        yield
        @code.gsub!(/\n*\Z/m, '')
        add_raw_code ';'
        newline
      elsif value
        add_code "#{declaration} = #{value};"
      else
        add_code "#{declaration};"
      end
    end

    alias variable field
    alias member field

    # Adds an array initializer (in the form of `[x, y, z]`) to the internal
    # buffer. Expects a block which defines the elements inside the array.
    # The block does not expose the Builder API methods, but exposes the
    # InitializerBuilder API methods instead. See the comments in
    # initializer_builder.rb for an example and to learn what API methods
    # are available.
    #
    # Does not add a trailing newline.
    #
    # Example:
    #
    #     array_initializer do
    #       element 1
    #       element 2
    #     end
    #
    #     separator
    #
    #     array_initializer do
    #       string_element "foo"
    #       # Equivalent:
    #       element str_val("foo")
    #     end
    #
    # Output:
    #
    #     [
    #         1,
    #         2
    #     ]
    #
    #     [
    #         "foo",
    #         "foo"
    #     ]
    def array_initializer(&block)
      subbuilder = InitializerBuilder.new(self, '[', ']')
      subbuilder.instance_eval(&block)
      subbuilder.write_code_without_newline
    end

    # Adds a struct initializer (in the form of `{x, y, z}`) to the internal
    # buffer. Expects a block which defines the elements inside the array.
    # The block does not expose the Builder API methods, but exposes the
    # InitializerBuilder API methods instead. See the comments in
    # initializer_builder.rb for an example and to learn what API methods
    # are available.
    #
    # Does not add a trailing newline.
    #
    # Example:
    #
    #     struct_initializer do
    #       element 1
    #       element 2
    #     end
    #
    #     separator
    #
    #     struct_initializer do
    #       string_element "foo"
    #       # Equivalent:
    #       element str_val("foo")
    #     end
    #
    # Output:
    #
    #     {
    #         1,
    #         2
    #     }
    #
    #     {
    #         "foo",
    #         "foo"
    #     }
    def struct_initializer(&block)
      subbuilder = InitializerBuilder.new(self, '{', '}')
      subbuilder.instance_eval(&block)
      subbuilder.write_code_without_newline
    end

    # Returns (and does not modify the internal buffer!) a C string representation
    # of `str`. This is especially useful for supplying a string value to `#field`.
    def str_val(str)
      str.to_s.inspect
    end

    def to_s
      @code
    end

  private
    def unindent(str)
      str = str.dup
      str.gsub!(/\A([\s\t]*\n)+/, '')
      str.gsub!(/[\s\t\n]+\Z/, '')
      indent = str.split("\n").select{ |line| !line.strip.empty? }.map{ |line| line.index(/[^\s]/) }.compact.min || 0
      str.gsub!(/^[[:blank:]]{#{indent}}/, '')
      str
    end

    def reindent(str, prefix, convert_ruby_indentation)
      str = unindent(str)

      # Convert Ruby two-space indentation to our own indentation format
      if convert_ruby_indentation
        str.gsub!(/^(  )+/) do |match|
          @indent_string * (match.size / 2)
        end
      end

      # Prepend supplied prefix to each line
      str.gsub!(/^/, prefix)

      # Remove trailing whitespaces
      str.gsub!(/[ \t]+$/, '')

      str
    end
  end
end
