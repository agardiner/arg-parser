module ArgParser

    # Namespace for DSL methods that can be imported into a class for defining
    # command-line argument handling.
    #
    # @example
    #   class MyClass
    #       include ArgParser::DSL
    #
    #       # These class methods are added by the DSL, and allow us to define
    #       # the command-line arguments we want our class to handle.
    #       positional_arg :command, 'The name of the sub-command to run',
    #           validation: ['process', 'list'] do |arg, val, hsh|
    #               # On parse, return the argument value as a symbol
    #               val.intern
    #           end
    #       rest_arg :files, 'The file(s) to process'
    #
    #       def run
    #           # Parse the command-line arguments, and call the appropriate command
    #           args = parse_arguments
    #           send(args.command, *args.files)
    #       end
    #
    #       def process(*files)
    #           ...
    #       end
    #
    #       def list(*files)
    #           ...
    #       end
    #   end
    module DSL

        # Class methods added when DSL module is included into a class.
        module ClassMethods

            # Accessor to return a Definition object holding the command-line
            # argument definitions.
            def args_def
                @args_def ||= ArgParser::Definition.new
            end

            # Sets the title that will appear in the Usage output generated from
            # the Definition.
            def title(val)
                args_def.title = val
            end

            # Sets the descriptive text that describes the purpose of the job
            # represented by this class.
            def purpose(desc)
                args_def.purpose = desc
            end

            # Define a new positional argument.
            # @see PositionalArgument#initialize
            def positional_arg(key, desc, opts = {}, &block)
                args_def.positional_arg(key, desc, opts, &block)
            end

            def keyword_arg(key, desc, opts = {}, &block)
                args_def.keyword_arg(key, desc, opts, &block)
            end

            def flag_arg(key, desc, opts = {}, &block)
                args_def.flag_arg(key, desc, opts, &block)
            end

            def rest_arg(key, desc, opts = {}, &block)
                args_def.rest_arg(key, desc, opts, &block)
            end

            def require_one_of(*keys)
                args_def.require_one_of(*keys)
            end

            def require_any_of(*keys)
                args_def.require_any_of(*keys)
            end

        end

        # Hook used to extend the including class with class methods defined in
        # the DSL ClassMethods module.
        def self.included(base)
            base.extend(ClassMethods)
        end

        # Defines a +parse_arguments+ instance method to be added to classes that
        # include this module. Uses the +args_def+ argument definition stored on
        # on the class to define the arguments to parse.
        def parse_arguments(args = ARGV)
          self.class.args_def.parse(args)
        end

    end

end
