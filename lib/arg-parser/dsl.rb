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

            # Returns true if any arguments have been defined
            def args_defined?
                @args_def && @args_def.args.size > 0
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

            # Define a new positional argument.
            # @see KeywordArgument#initialize
            def keyword_arg(key, desc, opts = {}, &block)
                args_def.keyword_arg(key, desc, opts, &block)
            end

            # Define a new flag argument.
            # @see FlagArgument#initialize
            def flag_arg(key, desc, opts = {}, &block)
                args_def.flag_arg(key, desc, opts, &block)
            end

            # Define a rest argument.
            # @see RestArgument#initialize
            def rest_arg(key, desc, opts = {}, &block)
                args_def.rest_arg(key, desc, opts, &block)
            end

            # Make exactly one of the specified arguments mandatory.
            # @see Definition#require_one_of
            def require_one_of(*keys)
                args_def.require_one_of(*keys)
            end

            # Make one or more of the specified arguments mandatory.
            # @see Definition#require_any_of
            def require_any_of(*keys)
                args_def.require_any_of(*keys)
            end

        end

        # Hook used to extend the including class with class methods defined in
        # the DSL ClassMethods module.
        def self.included(base)
            base.extend(ClassMethods)
        end

        # @return [Definition] The arguments Definition object defined on this
        #   class.
        def args_def
            self.class.args_def
        end

        # Defines a +parse_arguments+ instance method to be added to classes that
        # include this module. Uses the +args_def+ argument definition stored on
        # on the class to define the arguments to parse.
        def parse_arguments(args = ARGV)
          args_def.parse(args)
        end


        # Defines a +parse_errors+ instance method to be added to classes that
        # include this module.
        def parse_errors
            args_def.errors
        end


        # Whether usage information should be displayed.
        def show_usage?
            args_def.show_usage?
        end


        # Whether help should be displayed.
        def show_help?
            args_def.show_usage?
        end


        # Outputs brief usgae details.
        def show_usage(*args)
            args_def.show_usage(*args)
        end


        # Outputs detailed help about available arguments.
        def show_help(*args)
            args_def.show_help(*args)
        end

    end

end
