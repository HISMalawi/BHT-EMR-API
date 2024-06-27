# Simple C++ parser utilizing comment hints

This is a simple library for extracting information from C++ source files:

 * Class names.
 * Containing fields names and their types.

C++ is hard to parse, so this library requires the developer insert hints into the C++ code in the form of comments.

The main use case for this library is to automatically generate source code for processing the fields in a class, e.g. code for serializing a class. Instead of manually writing code for serializing each field, use this library to analyze the class and to automatically generate such source code. For this kind of use case, inserting hints to aid parsing is an acceptable trade-off.

## Usage

Insert hints into C++ source files as follows:

 * Before each class, add a comment containing the text "- begin hinted parseable class -"
 * After each class, add a comment containing the text "- end hinted parseable class -"
 * Before each struct, add a comment containing the text "- begin hinted parseable struct -"
 * After each struct, add a comment containing the text "- end hinted parseable struct -"
 * Before each field, add a comment containing the text "@hinted_parseable"

Example:

~~~c++
// - begin hinted parseable class -
class Foo {
    // @hinted_parseable
    int field1;

    // @hinted_parseable
    int field2;
};
// - end hinted parseable class -
~~~

It doesn't matter whether the comment is multi-line or single-line. Both are supported. The comment may also contain any other arbitrary text; it won't interfere with parsing.

Parse the file with the following code:

~~~ruby
require 'cxx_hinted_parser'

parser = CxxHintedParser::Parser.load_file('file.cpp').parse

parser.structs.keys             # => ['Foo']
parser.structs['Foo'].size      # => 2

parser.structs['Foo'][0].type   # => 'int'
parser.structs['Foo'][0].name   # => 'field1'

parser.structs['Foo'][1].type   # => 'int'
parser.structs['Foo'][1].name   # => 'field2'
~~~~

### Error handling

The parser may encounter errors during parsing. Errors do not stop parsing; they are remembered so that you can handle them later. Access errors with the `#errors` method on the parser object.

Example:

~~~ruby
parser = CxxHintedParser::Parser.load_file('file_with_errors.cpp').parse
parser.has_errors?        # => true
parser.errors.size        # => 1
parser.errors[0].line     # => 8
parser.errors[0].column   # => 22
parser.errors[0].message  # => "Unable to parse field name and type"
~~~

### Metadata

You can attach arbitrary metadata to a field by specifying them in the comments in the form of `@key value`. Metadata must appear *after* `@hinted_parseable`.

Example:

~~~c++
// - begin hinted parseable class -
class Foo {
    // @hinted_parseable
    // @author Joe
    // @written_on 2016-05-22
    // @serialize
    int field1;
};
// - end hinted parseable class -
~~~

You can access the metadata in the parser through the `metadata` method:

~~~ruby
parser.structs['Foo'][0].metadata
# => { :author => "Joe",
#      :written_on => "2016-05-22",
#      :serialize => true }
~~~
