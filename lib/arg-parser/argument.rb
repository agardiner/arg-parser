# Namespace for classes defined by ArgParser, the command-line argument parser.
module ArgParser

    # Hash containing registered handlers for :on_parse options
    OnParseHandlers = {
        :split_to_array => lambda{ |val, arg, hsh| val.split(',') }
    }
    # Hash containing globally registered predefined arguments available via
    # #predefined_arg.
    # TODO: Document preferred scoped usage
    PredefinedArguments = { }


    # Abstract base class of all command-line argument types.
    #
    # @abstract
    class Argument

        # @return [Symbol] the key/method by which this argument can be retrieved
        #   from the parse result Struct.
        attr_reader :key
        # @return [String] the description for this argument, which will be shown
        #   in the usage display.
        attr_accessor :description
        # @return [Symbol] a single letter or digit that can be used as a short
        #   alternative to the full key to identify an argument value in a command-
        #   line.
        attr_reader :short_key
        # @return [Boolean] whether this argument is a required (i.e. mandatory)
        #   argument. Mandatory arguments that do not get specified result in a
        #   ParseException.
        attr_accessor :required
        alias_method :required?, :required
        # @return [String] the default value for the argument, returned in the
        #   command-line parse results if no other value is specified.
        attr_accessor :default
        # An optional on_parse callback handler. The supplied block/Proc will be
        # called after this argument has been parsed, with three arguments:
        #   @param [String] The value from the command-line that was entered for
        #     this argument.
        #   @param [Argument] The Argument sub-class object that represents the
        #     argument that was parsed.
        #   @param [Hash] The results Hash containing the argument keys and their
        #     values parsed so far.
        # @return [Proc] the user supplied block to be called when the argument
        #   has been parsed.
        attr_accessor :on_parse
        # @return [String] a label to use for a new section of options in the
        #   argument usage display. Should be specified on the first argument in
        #   the group.
        attr_accessor :usage_break

        # Converts an argument key specification into a valid key, by stripping
        # leading dashes, converting remaining dashes to underscores, and lower-
        # casing all text. This is required to ensure the key name will be a
        # valid accessor name on the parse results.
        #
        # @param label [String|Symbol] the value supplied for an argument key
        # @return [Symbol] the key by which an argument can be retrieved from
        #   the arguments definition and the parse results.
        def self.to_key(label)
            k = label.to_s.gsub(/^-+/, '').gsub('-', '_')
            k.length > 1 ? k.downcase.intern : k.intern
        end

        # Register a common argument for use in multiple argument definitions. The
        # registered argument is a completely defined argument that can be added to
        # any argument definition via Definition#predefined_arg.
        #
        # @see Definition#predefined_arg
        #
        # @param lookup_key [String, Symbol] The key with which to register the
        #   argument for subsequent lookup. This can be different from the key
        #   which will represent the argument when parsed etc; this makes it
        #   possible to register several alternate versions of the same argument
        #   for use in different circumstances.
        # @param arg [Argument] An Argument sub-class that represents the arg
        #   that is to be registered for later use. #TODO: Document how arg is
        #   created.
        def self.register(lookup_key, arg)
            key = self.to_key(lookup_key)
            if PredefinedArguments.has_key?(key)
                raise ArgumentError, "An argument has already been registered under key '#{lookup_key}'"
            end
            PredefinedArguments[key] = arg
        end

        # Return a copy of a pre-defined argument for use in an argument
        # definition.
        #
        # @param lookup_key [String, Symbol] The key with which to register the
        #   argument for subsequent lookup. This can be different from the key
        #   which will represent the argument when parsed etc; this makes it
        #   possible to register several alternate versions of the same argument
        #   for use in different circumstances.
        # @return [Argument] A copy of the registered argument.
        def self.lookup(lookup_key)
            key = self.to_key(lookup_key)
            unless arg = PredefinedArguments[key]
                raise ArgumentError, "No pre-defined argument has been registered under key '#{lookup_key}'"
            end
            arg.clone
        end

        # Set the short key (a single letter or digit) that may be used as an
        # alternative when specifyin gthis argument.
        #
        # @param sk [String] The short key specification
        def short_key=(sk)
            if sk =~ /^-?([a-z0-9])$/i
                @short_key = $1.intern
            else
                raise ArgumentError, "An argument short key must be a single digit or letter"
            end
        end


        private

        # Private to prevent instantiation of this abstract class
        def initialize(key, desc, opts = {}, &block)
            @key = self.class.to_key(key)
            @description = desc
            @default = opts[:default]
            @on_parse = block || opts[:on_parse]
            if @on_parse.is_a?(Symbol)
                op = opts[:on_parse]
                @on_parse = case
                when OnParseHandlers.has_key?(op)
                    OnParseHandlers[op]
                when "".respond_to?(op)
                    lambda{ |val, arg, hsh| val.send(op) }
                else
                    raise ArgumentError, "No on_parse handler registered for #{op.inspect}"
                end
            end
            @usage_break = opts[:usage_break]
            if sk = opts[:short_key]
                self.short_key=(sk)
            end
        end

    end


    # An argument type that defines a command. Only a single command placeholder
    # can be defined per ArgumentSet, but each command placeholder can have one
    # or more command arguments (i.e. allowed values). Depending on the command,
    # different additional arguments may then be specified in the command's
    # ArgumentSet.
    class CommandArgument < Argument

        # @return [Array<Symbol] List of valid commands that may be specified.
        attr_accessor :commands


        # Create an instance of a CommandArgument, a positional argument that
        # indicates a particular command to be invoked.
        #
        # @param key [String|Symbol] The value under which the specified command
        #   can be retrieved following parsing (e.g. :command)
        # @param desc [String] A description for the command argument.
        # @param opts [Hash] An options hash. See Argument#initialize for supported
        #   option values.
        def initialize(key, desc, opts = {})
            super(key, desc, opts)
            @commands = {}
            @usage_value = opts.fetch(:usage_value, key.to_s.gsub('_', '-').upcase)
        end

        # Adds a specific command verb/value to this command argument
        def <<(cmd_instance)
            raise ArgumentError, "must be a CommandInstance object" unless cmd_instance.is_a?(CommandInstance)
            @commands[cmd_instance.command_value] = cmd_instance
        end

        # Return the CommandInstance for a particular command value
        #
        # @param cmd_val [String|Symbol] A command token identifying the command
        # @return [CommandInstance] The CommandInstance for the specified command
        def [](cmd_val)
            k = Argument.to_key(cmd_val)
            @commands[k]
        end

        def to_s
            @usage_value
        end

        def to_use
            @usage_value
        end

    end


    # Represents a specific command value for a CommandArgument, along with any
    # additional arguments specific to this command.
    class CommandInstance < Argument

        # @return the constant value that identifies this CommandInstance
        attr_reader :command_value
        # Return the CommandArgument to which this CommandInstance relates
        attr_reader :command_arg
        # Return an ArgumentScope for any additional arguments this command takes 
        attr_reader :argument_scope


        def initialize(cmd_val, desc, cmd_arg, arg_scope, opts = {})
            super(cmd_arg.key, desc, opts)
            @command_value = cmd_val
            @command_arg = cmd_arg
            @argument_scope = arg_scope
        end

        def to_s
            @command_value
        end

        def to_use
            @command_value
        end

    end


    # Abstract base class of arguments that take a value (i.e. positional and
    # keyword arguments).
    #
    # @abstract
    class ValueArgument < Argument

        # @return [Boolean] Flag indicating that the value for this argument is
        #   a sensitive value (e.g. a password) that should not be displayed.
        attr_accessor :sensitive
        alias_method :sensitive?, :sensitive
        # @return [Array, Regexp, Proc] An optional validation that will be
        #   applied to the argument value for this argument, to determine if it
        #   is valid. The validation can take the following forms:
        #     @param [Array] If an Array is specified, the supplied value will be
        #       checked to verify it is one of the allowed values specified in the
        #       Array.
        #     @param [Regexp] If a Regexp object is supplied, the argument value
        #       will be tested against the Regexp to verify it is valid.
        #     @param [Proc] The most flexible option; the supplied value, this
        #       ValueArgument sub-class object, and the parse results (thus far)
        #       will be passed to the Proc for validation. The Proc must return a
        #       non-falsey value for the argument to be accepted.
        attr_accessor :validation
        # @return [String] A label that will be used in the usage string printed
        #   for this ValueArgument. If not specified, defaults to the upper-case
        #   value of the argument key. For example, if the argument key is :foo_bar,
        #   the default usage value for this argument would be FOO-BAR, as in:
        #     Usage:
        #       my-prog.rb FOO-BAR
        attr_accessor :usage_value


        private

        def initialize(key, desc, opts = {}, &block)
            super
            @sensitive = opts[:sensitive]
            @validation = opts[:validation]
            @usage_value = opts.fetch(:usage_value, key.to_s.gsub('_', '-').upcase)
        end

    end


    # An argument that is set by position on the command-line. PositionalArguments
    # do not require a --key to be specified before the argument value; they are
    # typically used when there are a small number of mandatory arguments.
    #
    # Positional arguments still have a key that is used to identify the parsed
    # argument value in the results Struct. As such, it is not an error for a
    # positional argument to be specified with its key - its just not mandatory
    # for the key to be provided.
    class PositionalArgument < ValueArgument

        # Creates a new positional argument, which is an argument value that may
        # be specified without a keyword, in which case it is matched to the
        # available positional arguments by its position on the command-line.
        #
        # @param [Symbol] key The name that will be used for the accessor used
        #   to return this argument value in the parse results.
        # @param [String] desc A description for this argument. Appears in the
        #   help output that is generated when the user specifies the --help or
        #   /? flags on the command-line.
        # @param [Hash] opts Contains any options that are desired for this
        #   argument.
        # @yield [val, arg, hsh] If supplied, the block passed will be invoked
        #   after this argument value has been parsed from the command-line.
        #   Blocks are usually used when the value to be returned needs to be
        #   converted from a String to some other type.
        # @yieldparam val [String] the String value read from the command-line
        #   for this argument
        # @yieldparam arg [PositionalArgument] this argument definition
        # @yieldparam hsh [Hash] a Hash containing the argument values parsed
        #   so far.
        # @yieldreturn [Object] the return value from the block will be used as
        #   the argument value  parsed from the command-line for this argument.
        def initialize(key, desc, opts = {}, &block)
            super
            @required = opts.fetch(:required, !opts.has_key?(:default))
        end

        # @return [String] the word that will appear in the help display for
        #   this argument.
        def to_s
            usage_value
        end

        # @return [String] the string for this argument position in a command-line
        #   usage display.
        def to_use
            required? ? usage_value : "[#{usage_value}]"
        end

    end


    # An argument that is specified via a keyword prefix; typically used
    # for optional arguments, although Keyword arguments can also be used for
    # mandatory arguments where there is no natural ordering of arguments.
    class KeywordArgument < ValueArgument

        # Whether the keyword argument must be specified with a non-missing
        # value. The default is false, meaning the keyword argument must be
        # specified together with a value. When this property is set to a
        # non-falsy value (i.e. not nil or false), the keyword argument can
        # be specified either with or without a value (or not at all):
        # - If specified with a value, the value will be returned.
        # - If specified without a value, the value of this property will be
        #   returned.
        # - If not specified at all, the default value will be returned.
        #
        # @return [Object] If truthy, the argument does not require a value.
        #   If the argument is specified but no value is provided, the value
        #   of this property will be the argument value.
        attr_accessor :value_optional
        alias_method :value_optional?, :value_optional


        # Creates a KeywordArgument, which is an argument that must be specified
        # on a command-line using either a long form key (i.e. --key), or
        # optionally, a short-form key (i.e. -k) should one be defined for this
        # argument.
        #
        # @param key [Symbol] the key that will be used to identify this argument
        #   value in the parse results.
        # @param desc [String] the description of this argument, displayed in the
        #   generated help screen.
        # @param opts [Hash] a hash of options that govern the behaviour of this
        #   argument.
        # @option opts [Boolean] :required whether the keyword argument is a required
        #   argument that must appear in the command-line. Defaults to false.
        # @option opts [Boolean] :value_optional whether the keyword argument can be
        #   specified without a value. For example, a keyword argument might
        #   be used both as a flag, and to override a default value. Specifying
        #   the argument without a value would signify that the option is set,
        #   but the default value for the option should be used. Defaults to
        #   false (keyword argument cannot be specified without a value).
        def initialize(key, desc, opts = {}, &block)
            super
            @required = opts.fetch(:required, false)
            @value_optional = opts.fetch(:value_optional, false)
        end

        def to_s
            "--#{key}".gsub('_', '-')
        end

        def to_use
            sk = short_key ? "-#{short_key}, " : ''
            uv = value_optional ? "[#{usage_value}]" : usage_value
            "#{sk}#{self.to_s} #{uv}"
        end

    end


    # A boolean argument that is set if its key is encountered on the command-line.
    # Flag arguments normally default to false, and become true if the argument
    # key is specified. However, it is also possible to define a flag argument
    # that defaults to true, in which case the option can be disabled by pre-
    # pending the argument key with a 'no-' prefix, e.g. --no-export can be
    # specified to disable the normally enabled --export flag.
    class FlagArgument < Argument

        # Creates a new flag argument, which is an argument with a boolean value.
        #
        # @param [Symbol] key The name that will be used for the accessor used
        #   to return this argument value in the parse results.
        # @param [String] desc A description for this argument. Appears in the
        #   help output that is generated when the user specifies the --help or
        #   /? flags on the command-line.
        # @param [Hash] opts Contains any options that are desired for this
        #   argument.
        # @param [Block] block If supplied, the block passed will be invoked
        #   after this argument value has been parsed from the command-line.
        #   The block will be called with three arguments: this argument
        #   definition, the String value read from the command-line for this
        #   argument, and a Hash containing the argument values parsed so far.
        #   The return value from the block will be used as the argument value
        #   parsed from the command-line for this argument. Blocks are usually
        #   used when the value to be returned needs to be converted from a
        #   String to some other type.
        def initialize(key, desc, opts = {}, &block)
            super
            @usage_value = opts[:usage_value]
        end

        def required
            false
        end

        def to_s
            "--#{self.default ? 'no-' : ''}#{key}".gsub('_', '-')
        end

        def to_use
            sk = short_key ? "-#{short_key}, " : ''
            if @usage_value
                "#{sk}#{@usage_value[0..1] == '--' ? '' : '--'}#{@usage_value}"
            else
                "#{sk}#{self.to_s}"
            end
        end

    end


    # A command-line argument that takes 0 to N values from the command-line.
    class RestArgument < ValueArgument

        # Creates a new rest argument, which is an argument that consumes all
        # remaining positional argument values.
        #
        # @param [Symbol] key The name that will be used for the accessor used
        #   to return this argument value in the parse results.
        # @param [String] desc A description for this argument. Appears in the
        #   help output that is generated when the user specifies the --help or
        #   /? flags on the command-line.
        # @param [Hash] opts Contains any options that are desired for this
        #   argument.
        # @option opts [Fixnum] :min_values The minimum number of rest values
        #   that must be supplied. Defaults to 1 if the RestArgument is
        #   required, or 0 if it is not.
        # @param [Block] block If supplied, the block passed will be invoked
        #   after this argument value has been parsed from the command-line.
        #   The block will be called with three arguments: this argument
        #   definition, the String value read from the command-line for this
        #   argument, and a Hash containing the argument values parsed so far.
        #   The return value from the block will be used as the argument value
        #   parsed from the command-line for this argument. Blocks are usually
        #   used when the value to be returned needs to be converted from a
        #   String to some other type.
        def initialize(key, desc, opts = {}, &block)
            super
            @min_values = opts.fetch(:min_values, opts.fetch(:required, true) ? 1 : 0)
            @default = [@default] if @default.is_a?(String)
        end

        def required
          @min_values > 0
        end

        # @return [String] the word that will appear in the help display for
        #   this argument.
        def to_s
            usage_value
        end

        # @return [String] The string for this argument position in a command-line.
        #  usage display.
        def to_use
            required? ? "#{usage_value} [...]" : "[#{usage_value} [...]]"
        end

    end

end

