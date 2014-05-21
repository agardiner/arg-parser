# ArgParser

ArgParser is a small library for parsing command-line arguments (or indeed any string or Array of text).
It provides a simple DSL for defining the possible arguments, which may be one of the following:
* Positional arguments, where values are specified without any keyword, and their meaning is based on the
  order in which they appear in the command-line.
* Keyword arguments, which are identified by a long- or short-key preceding the value.
* Flag arguments, which are essentially boolean keyword arguments. The presence of the key implies a true
  value.
* A Rest argument, which is an argument definition that takes 0 or more trailing positional arguments.

## Usage

ArgParser is supplied as a gem, and has no dependencies. To use it, simply:
```
gem install arg-parser
```

ArgParser provides a DSL module that can be included into any class to provide argument parsing.

```ruby
require 'arg-parser'

class MyClass

    include ArgParser::DSL

    purpose <<-EOT
        This is where you specify the purpose of your program. It will be displayed in the
        generated help screen if you pass /? or --help on the command-line.
    EOT

    positional_arg :my_positional_arg, 'This is a positional arg'
    keyword_arg :my_keyword_arg, 'This is a keyword arg'
    flag_arg :flag, 'This is a flag argument'
    rest_arg :files, 'This is where we specify tha


    def run
        if opts = parse_arguments
            # Do something with opts.my_positional_arg, opts.my_keyword_arg,
            # opts.flag, and opts.files
            # ...
        else
            show_help? ? show_help : show_usage
        end
    end

end


MyClass.new.run

```

## Functionality

ArgParser provides a fairly broad range of functionality for argument parsing. Following is a non-exhaustive
list of features:
* Built-in usage and help display
* Mandatory vs Optional: All arguments your program accepts can be defined as optional or mandatory.
  By default, positional arguments are considered mandatory, and all others default to optional. To change
  the default, simply specify `required: true` or `required: false` when defining the argument.
* Short-keys and long-keys: Arguments are defined with a long_key name which will be used to access the
  parsed value in the results. However, arguments can also define a single letter or digit short-key form
  which can be used as an alternate means for indicating a value. To define a short key, simply pass
  `short_key: '<letter_or_digit>'` when defining an argument.
* Validation: Arguments can define validation requirements that must be satisfied. This can take several
  forms:
     - List of values: Pass an array containing the allowed values the argument can take.
     - Regular expression: Pass a regular expression that the argument value must satisfy.
     - Proc: Pass a proc that will be called to validate the supplied argument value. If the proc returns
       a non-falsey value, the argument is accepted, otherwise it is rejected.
* On-parse handler: A proc can be passed that will be called when the argument value is encountered
  during parsing. The return value of the proc will be used as the argument result.

