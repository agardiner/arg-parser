# Namespace for classes defined by ArgParser, the command-line argument parser.
module ArgParser

    # Abstract base class of all command-line argument types.
    #
    # @abstract
    class Argument

        # The key used to identify this argument value in the  parsed command-
        # line results Struct.
        # @return [Symbol] the key/method by which this argument can be retrieved
        #   from the parse result Struct.
        attr_reader :key
        # @return [String] the description for this argument, which will be shown
        #   in the usage display.
        attr_reader :description
        # @return [Symbol] a single letter or digit that can be used as a short
        #   alternative to the full key to identify an argument value in a command-
        #   line.
        attr_reader :short_key
        # @return [Boolean] whether this argument is a required (i.e. mandatory)
        #   argument. Mandatory arguments that do not get specified result in a
        #   ParseException.
        attr_accessor :required
        # @return [String] the default value for the argument, returned in the
        #   command-line parse results if no other value is specified.
        attr_accessor :default
        # An optional on_parse callback handler. The supplied block/Proc will be
        # called after this argument has been parsed, with three arguments:
        #   @param [Argument] The Argument sub-class object that represents the
        #     argument that was parsed.
        #   @param [String] The value from the command-line that was entered for
        #     this argument.
        #   @param [Hash] The results Hash containing the argument keys and their
        #     values parsed so far.
        # @return [Proc] the user supplied block to be called when the argument
        #   has been parsed.
        attr_accessor :on_parse
        # @return [String] a label to use for a new section of options in the
        #   argument usage display. Should be specified on the first argument in
        #   the group.
        attr_accessor :usage_break

        alias_method :required?, :required

        # Converts an argument key specification into a valid key, by stripping
        # leading dashes, converting remaining dashes to underscores, and lower-
        # casing all text. This is required to ensure the key name will be a
        # valid accessor name on the parse results.
        #
        # @return [Symbol] the key by which an argument can be retrieved from
        #   the arguments definition, and the parse results.
        def self.to_key(label)
            label.to_s.gsub(/^-+/, '').gsub('-', '_').downcase.intern
        end


        private

        def initialize(key, desc, opts = {}, &block)
            @key = self.class.to_key(key)
            @description = desc
            @default = opts[:default]
            @on_parse = block || opts[:on_parse]
            @usage_break = opts[:usage_break]
            if sk = opts[:short_key]
                if sk =~ /^-?([a-z0-9])$/i
                    @short_key = $1.intern
                else
                    raise ArgumentError, "An argument short key must be a single digit or letter"
                end
            end
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
        # @return [Array, Regexp, Proc] An optional validation that will be
        #   applied to the argument value for this argument, to determine if it
        #   is valid. The validation can take the following forms:
        #     @param [Array] If an Array is specified, the supplied value will be
        #       checked to verify it is one of the allowed values specified in the
        #       Array.
        #     @param [Regexp] If a Regexp object is supplied, the argument value
        #       will be tested against the Regexp to verify it is valid.
        #     @param [Proc] The most flexible option; this ValueArgument sub-class
        #       object, the supplied value and the parse results (thus far) will
        #       be passed to the Proc for validation. The Proc must return a non-
        #       falsy value for the argument to be accepted.
        attr_accessor :validation
        # @return [String] A label that will be used in the usage string printed
        #   for this ValueArgument. If not specified, defaults to the upper-case
        #   value of the argument key. For example, if the argument key is :foo_bar,
        #   the default usage value for this argument would be FOO-BAR, as in:
        #     Usage:
        #       my-prog.rb FOO-BAR
        attr_accessor :usage_value

        alias_method :sensitive?, :sensitive


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
        # @yield [arg, val, hsh] If supplied, the block passed will be invoked
        #   after this argument value has been parsed from the command-line.
        #   Blocks are usually used when the value to be returned needs to be
        #   converted from a String to some other type.
        # @yieldparam arg [PositionalArgument] this argument definition
        # @yieldparam val [String] the String value read from the command-line
        #   for this argument
        # @yieldparam hsh [Hash] a Hash containing the argument values parsed
        #   so far.
        # @yieldreturn [Object] the return value from the block will be used as
        #   the argument value  parsed from the command-line for this argument.
        def initialize(key, desc, opts = {}, &block)
            super
            @required = opts.fetch(:required, true)
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
        # value.
        # @return [Boolean] true if the keyword can be specified without a value.
        attr_accessor :value_optional

        alias_method :value_optional?, :value_optional


        # Creates a KeywordArgument, which is an argument that must be specified
        # on a command-line using either a long form key (i.e. --key), or
        # optionally, a short-form key (i.e. -k) should one be defined for this
        # argument.
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
        end

        def required
            false
        end

        def to_s
            "--#{self.default ? 'no-' : ''}#{key}".gsub('_', '-')
        end

        def to_use
            sk = short_key ? "-#{short_key}, " : ''
            "#{sk}#{self.to_s}"
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

