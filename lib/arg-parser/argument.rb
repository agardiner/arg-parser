class ArgParser

    # Abstract base class of all command-line argument types.
    class Argument

        # @return [Symbol] The key used to identify this argument value in the
        # parsed command-line results Hash.
        attr_reader :key
        # @return [String] The description for this argument, used in the usage
        # display.
        attr_reader :description
        # @return [Symbol] The single letter or digit that can be used instead
        # of the full key to identify this argument value.
        attr_reader :short_key
        # @return [Boolean] Whether this argument is a required (i.e. mandatory)
        #   argument. Mandatory arguments that do not get specified result in a
        #   ParseException.
        attr_accessor :required
        # @return [String] The default value for the argument, returned if no
        # value is specified for this argument on the command-line.
        attr_accessor :default
        # @return [Proc] The block to be called when the argument has been parsed.
        # This block will be called with three arguments:
        #   @param [Argument] The Argument sub-class object that represents the
        #     argument that was parsed.
        #   @param [String] The value from the command-line that was entered for
        #     this argument.
        #   @param [Hash] The results Hash containing the argument keys and their
        #     values parsed so far.
        attr_accessor :on_parse
        # @return [Boolean] If true, a line-break is inserted before the argument
        # description in the usage output.
        attr_accessor :usage_break

        alias_method :required?, :required


        private

        def initialize(key, desc, opts = {}, &block)
            @key = key.to_s.downcase.intern
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


    # Abstract base class of arguments that take a value.
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
        #   of the argument key.
        attr_accessor :usage_value

        alias_method :sensitive?, :sensitive


        private

        def initialize(key, desc, opts = {}, &block)
            super(key, desc, opts, &block)
            @sensitive = opts[:sensitive]
            @validation = opts[:validation]
            @usage_value = opts.fetch(:usage_value, key.to_s.upcase)
        end

    end


    # An argument that is set by position on the command-line. PositionalArguments
    # do not require a --key to be specified before the argument value; they are
    # typically used when there are a small number of mandatory arguments.
    class PositionalArgument < ValueArgument

        def initialize(key, desc, opts = {}, &block)
            super(key, desc, opts, &block)
            @required = opts.fetch(:required, true)
        end

        def to_s
            usage_value
        end

        def to_use
            required? ? usage_value : "[#{usage_value}]"
        end

    end


    # An argument that is specified via a keyword prefix; typically used
    # for optional arguments, although Keyword arguments can also be used for
    # mandatory arguments where there is no natural ordering of arguments.
    class KeywordArgument < ValueArgument

        attr_accessor :value_optional

        alias_method :value_optional?, :value_optional


        def initialize(key, desc, opts = {}, &block)
            super(key, desc, opts, &block)
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

        def initialize(key, desc, opts = {}, &block)
            super(key, desc, opts, &block)
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

end

