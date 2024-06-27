# cxxcodebuilder: generate C/C++ code with a Builder-style DSL

Cxxcodebuilder gives you a simple Ruby API for programmatically outputting C/C++ code with proper indenting and formatting. Code using this API is much more readable than code building raw strings. Cxxcodebuilder is similar to [Jbuilder](https://github.com/rails/jbuilder), which is for outputting JSON.

## Use cases

This library is useful in build systems for automatically generating C/C++ code. It is much cleaner compared to using ERB or other generic text templating systems for the job.

## Example

Suppose that you want to write the following piece of code:

~~~c++
#include <stdio.h>

static int limit = 0;
static int magicNumbers[] = [1, 2, 3];
static Foo foos[] = [
    { "hello", 1 },
    { "world", 2 }
];

/*
 * This is an awesome model
 * for a futuristic car.
 */
struct Car {
    unsigned int seats;
};

static int
modifyLimit(int diff) {
    int oldLimit = limit;
    limit += diff;
    printf("The new limit is: %s\n", limit);
    return oldLimit;
}
~~~

Use Cxxcodebuilder as follows:

~~~ruby
require 'cxxcodebuilder'

builder = CxxCodeBuilder::Builder.new do
  include '<stdio.h>'

  separator

  field 'static int limit', 0

  field 'static int magicNumbers[]' do
    array_initializer do
      element 1
      element 2
      element 3
    end
  end

  field 'static Foo foo[]' do
    array_initializer do
      struct_element do
        string_element 'hello'
        element 1
      end
      struct_element do
        string_element 'world'
        element 2
      end
    end
  end

  separator

  comment %q{
    This is an awesome model
    for a futuristic car.
  }
  struct 'Car' do
    field 'unsigned int seats'
  end

  separator

  function('static int modifyLimit(int diff)', %q{
    int oldLimit = limit;
    limit += diff;
    printf("The new limit is: %s\n", limit);
    return oldLimit;
  })
end

puts(builder)
~~~

## API

See the comments in lib/cxxcodebuilder/builder.rb for the full API.
