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
    keyword_arg :my_keyword_arg, 'This is a keyword arg; if not specified, returns value1',
        default: 'value1'
    # An optional value keyword argument. If not specified, returns false. If specified
    # without a value, returns 'maybe'. If specified with a value, returns the value.
    keyword_arg :val_opt, 'This is a keyword arg with optional value',
        value_optional: 'maybe'
    flag_arg :flag, 'This is a flag argument'
    rest_arg :files, 'This is where we specify that remaining args will be collected in an array'


    def run
        if opts = parse_arguments
            # Do something with opts.my_positional_arg, opts.my_keyword_arg,
            # opts.flag, and opts.files
            # ...
        else
            # False is returned if argument parsing was not completed
            # This may be due to an error or because the help command
            # was used (by specifying --help or /?). The #show_help?
            # method returns true if help was requested, otherwise if
            # a parse error was encountered, #show_usage? is true and
            # parse errors are in #parse_errors
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
* Multiple different types of arguments can be defined:
    - Command arguments indicate an argument that can be one of a limited selection of pre-defined
      argument values. Each command argument must define its commands, as well as any command-specific
      arguments.
    - Positional arguments are arguments that are normally supplied without any key, and are matched
      to an argument definition based on the order in which they are encountered. Positional arguments
      can also be supplied using the key if preferred. Generally only a small number of positional
      arguments would be defined for those parameters required on every run.
    - Keyword arguments are arguments that must be specified by using a key to indicate which argument
      the subsequent value is for.
    - Flag arguments are boolean arguments that normally default to nil, but can be set to true just
      by specifying the argument key. It is also possible to define flag arguments with a default value
      of true; the argument can then be set to false by speciying the argument name with --no-<flag>
      (or --not-<flag> or --non-<flag> when those are more understandable).
    - Rest arguments use a single argument key to collect all remaining values from the command-line,
      and return these as an array in the resulting argument results.
* Parsed results are returned in an OpenStruct, with every defined argument having a value set (whether
  or not it was encountered on the command-line). Use the `default: <value>` option to set default
  values for non-specified arguments where you don't want nil returned in the parse results. Note that
  in the case of command arguments with command-specific arguments, only the arguments from the selected
  command appear in the results.
* Mandatory vs Optional: All arguments your program accepts can be defined as optional or mandatory.
  By default, positional arguments are considered mandatory, and all others default to optional. To change
  the default, simply specify `required: true` or `required: false` when defining the argument.
* Keyword arguments can also accept an optional value, using the `value_optional` option. If a keyword
  argument is supplied without a value, it returns the value of the `value_optional` option.
* Short-keys and long-keys: Arguments are defined with a long_key name which will be used to access the
  parsed value in the results. However, arguments can also define a single letter or digit short-key form
  which can be used as an alternate means for indicating a value. To define a short key, simply pass
  `short_key: '<letter_or_digit>'` when defining an argument.
* Requiring from a set of arguments: If you need to ensure that only one of several mutually exclusive
  arguments is specified, use `require_one_of <arg1>, <arg2>, ..., <argN>`. If you need to ensure that
  at least one argument is specified from a list of arguments, use
  `require_any_of <arg1>, <arg2>, ..., <argN>`
* Validation: Arguments can define validation requirements that must be satisfied. This can take several
  forms:
     - List of values: Pass an array containing the allowed values the argument can take.
       `validation: %w{one two three}`
     - Regular expression: Pass a regular expression that the argument value must satisfy.
       `validation: /.*\.rb$/`
     - Proc: Pass a proc that will be called to validate the supplied argument value. If the proc returns
       a non-falsey value, the argument is accepted, otherwise it is rejected.
       `validation: lambda{ |val, arg, hsh| val.upcase == 'TRUE' }`
* On-parse handler: A proc can be passed that will be called when the argument value is encountered
  during parsing. The return value of the proc will be used as the argument result.
  `on_parse: lambda{ |val, arg, hsh| val.split(',') }`
* On-parse handler reuse: Common parse handlers can be registered and used on multiple arguments.
  Handlers are registered for reuse via the DSL method #register_parse_handler. To use a registered
  parse handler for a particular argument, just pass the key under which the handler is registered.
* Pre-defined arguments: Arguments can be registered under a key, and then re-used across multiple
  definitions via the #predefined_arg DSL method. Common arguments would typically be defined in a
  shared file that was included into each job. See Argument.register and DSL.predefined_arg.


### Commands

Often command-line utilities can perform several actions, and we want to define an argument that will
be used to indicate to the program which action it should perform. This can be done very easily using
positional arguments, and setting a list of allowed values in the argument validation, e.g.
`positional_arg :command, 'The command to perform', validation: %w{list export import}`

However, it is often the case that the different commands require different additional arguments
to be specified, and this makes it necessary to make any argument not required by all commands into
an optional argument. However, now the program has to ensure that it checks for those optional
arguments that are required for the command to actually be present.

In this circumstance, it is better to instead make use of command arguments. These are arguments
that look like positional arguments that accept only a specific set of values, however, each command
can then define its own set of additional arguments (of any type). During parsing, when a command
argument is found, the argument definition is updated on-the-fly to include any additional arguments
defined by the now-matched command. Additionally, the usage and help displays are also updated to
reflect the arguments defined by the specified command.

Defining command arguments is a little more complex, due to the need to associate command arguments
with the commands.


```ruby
require 'arg-parser'

class MyClass

    include ArgParser::DSL

    purpose <<-EOT
        This is where you specify the purpose of your program. It will be displayed in the
        generated help screen if you pass /? or --help on the command-line.
    EOT

    command_arg :command, 'The command to perform' do
        # We often want the same arguments to appear in several but not all commands.
        # Rather than re-defining them for each command, we can first define them, and
        # then reference them in the commands that need them.
        define_args do
            positional_arg :source, 'The source to use'
            positional_arg :target, 'The target to use'
            positional_arg :local_dir, 'The path to a local directory',
                default: 'extracts'
        end

        command :list, 'List available items for transfer' do
            predefined_arg :source
        end
        command :export, 'Export items to a local directory' do
            predefined_arg :source
            predefined_arg :local_dir
        end
        command :import, 'Import items from a local directory' do
            predefined_arg :local_dir
            predefined_arg :target
        end
    end

    positional_arg :user_id, 'The user id for connecting to the source/target'
    positional_arg :password, 'The password for connecting to the source/target',
        sensitive: true

    ...

    def run
        if opts = parse_arguments
            case opts.command
            when 'list'
                do_list(opts.source)
            when 'export'
                do_export(opts.source, opts.local_dir)
            when 'import'
                do_import(opts.local_dir, opts.target)
            end
        else
            show_help? ? show_help : show_usage
        end
    end

end

MyClass.new.run
```

## Pre-defined Arguments

We saw above in the case of commands that it can be useful to pre-define an argument with all its
parameters once, and then reference that argument in multiple separate commands. This allows us
to follow DRY principles when defining an argument, making maintenance simpler and reducing the
possibility of mis-configuring one or more instances of the same argument.

This principle does not only apply to arguments for use within a single utility or set of commands.
Arguments can also be pre-defined in an argument scope, and then referenced in multiple utilities.
Thus if there are common arguments needed in many utilities that share some common code, you can
also define these common arguments in the shared code, and then include the pre-defined arguments
into each utility that shares that functionality.


```ruby
require 'arg-parser'

class MyLibrary

    include ArgParser::DSL

    LIBRARY_ARGS = define_args('Database Args') do
        positional_arg :database, 'The name of the database to connect to',
            on_parse: lambda{ |val, arg, hsh| # Lookup database connection details and return as hash }
        positional_arg :user_id, 'The user id for connecting to the database'
        positional_arg :password, 'The password for connecting to the database',
            sensitive: true
    end

end


class Utility

    include 'arg-parser'

    with_predefined_args MyLibrary::LIBRARY_ARGS do
        predefined_arg :database
        predefined_arg :user_id
        predefined_arg :password
    end

    keyword_arg :log_level, 'Set the log level for database interactions'
    
    ...

    
    def run
        if opts = parse_arguments
            # Connect to database, set log level etc
        else
            show_help? ? show_help : show_usage
        end
    end

end

MyClass.new.run
```
