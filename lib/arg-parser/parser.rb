module ArgParser

    # Parser for parsing a command-line
    class Parser

        # @return [Definition] The supported Arguments to be used when parsing
        #   the command-line.
        attr_reader :definition
        # @return [Array] An Array of error message Strings generated during
        #   parsing.
        attr_reader :errors
        # @return [Boolean] Flag set during parsing if the usage display should
        #   be shown. Set if there are any parse errors encountered.
        def show_usage?
            @show_usage
        end
        # @return [Boolean] Flag set during parsing if the user has requested
        #   the help display to be shown (via --help or /?).
        def show_help?
            @show_help
        end


        # Instantiates a new command-line parser, with the specified command-
        # line definition. A Parser instance delegates unknown methods to the
        # Definition, so its possible to work only with a Parser instance to
        # both define and parse a command-line.
        #
        # @param [Definition] definition A Definition object that defines the
        #   possible arguments that may appear in a command-line. If no definition
        #   is supplied, an empty definition is created.
        def initialize(definition = nil)
            @definition = definition || Definition.new
            @errors = []
        end


        # Parse the specified Array[String] of +tokens+, or ARGV if +tokens+ is
        # nil. Returns false if unable to parse successfully, or an OpenStruct
        # with accessors for every defined argument. Arguments whose values are
        # not specified will contain the agument default value, or nil if no
        # default is specified.
        def parse(tokens = ARGV)
            @show_usage = nil
            @show_help = nil
            @errors = []
            begin
                pos_vals, kw_vals, rest_vals = classify_tokens(tokens)
                args = process_args(pos_vals, kw_vals, rest_vals) unless @show_help
            rescue NoSuchArgumentError => ex
                self.errors << ex.message
                @show_usage = true
            end
            (@show_usage || @show_help) ? false : args
        end


        # Delegate unknown methods to the associated argument Definition object.
        def method_missing(mthd, *args)
            if @definition.respond_to?(mthd)
                @definition.send(mthd, *args)
            else
                super
            end
        end


        # Evaluate the list of values in +tokens+, and classify them as either
        # keyword/value pairs, or positional arguments. Ideally this would be
        # done without any reference to the defined arguments, but unfortunately
        # a keyword arg cannot be distinguished from a flag arg followed by a
        # positional arg without the context of what arguments are expected.
        def classify_tokens(tokens)
            if tokens.is_a?(String)
                require 'csv'
                tokens = CSV.parse(tokens, col_sep: ' ').first
            end
            tokens = [] unless tokens
            pos_vals = []
            kw_vals = {}
            rest_vals = []

            arg = nil
            tokens.each_with_index do |token, i|
                case token
                when '/?', '-?', '--help'
                    @show_help = true
                when /^-([a-z0-9]+)/i
                    $1.to_s.each_char do |sk|
                        kw_vals[arg] = nil if arg
                        arg = @definition[sk]
                        if FlagArgument === arg
                            kw_vals[arg] = true
                            arg = nil
                        end
                    end
                when /^(?:--|\/)(no-)?(.+)/i
                    kw_vals[arg] = nil if arg
                    arg = @definition[$2]
                    if FlagArgument === arg || (KeywordArgument === arg && $1)
                        kw_vals[arg] = $1 ? false : true
                        arg = nil
                    end
                when '--'
                    # All subsequent values are rest args
                    kw_vals[arg] = nil if arg
                    rest_vals = tokens[(i + 1)..-1]
                    break
                else
                    if arg
                        kw_vals[arg] = token
                    else
                        pos_vals << token
                        arg = @definition.positional_args[i]
                    end
                    tokens[i] = '******' if arg && arg.sensitive?
                    arg = nil
                end
            end
            kw_vals[arg] = nil if arg
            [pos_vals, kw_vals, rest_vals]
        end


        # Process arguments using the supplied +pos_vals+ Array of positional
        # argument values, and the +kw_vals+ Hash of keyword/value.
        def process_args(pos_vals, kw_vals, rest_vals)
            result = {}

            # Process positional arguments
            pos_args = @definition.positional_args
            pos_args.each_with_index do |arg, i|
                break if i >= pos_vals.length
                result[arg.key] = process_arg_val(arg, pos_vals[i], result)
            end
            if pos_vals.size > pos_args.size
                if @definition.rest_args?
                    rest_vals = pos_vals[pos_args.size..-1] + rest_vals
                else
                    self.errors << "#{pos_vals.size} positional #{pos_vals.size == 1 ? 'argument' : 'arguments'} #{
                        pos_vals.size == 1 ? 'was' : 'were'} supplied, but only #{pos_args.size} #{
                        pos_args.size == 1 ? 'is' : 'are'} defined"
                end
            end

            # Process key-word based arguments
            kw_vals.each do |arg, val|
                result[arg.key] = process_arg_val(arg, val, result)
            end

            # Process rest values
            if rest_arg = @definition.rest_args
                result[rest_arg.key] = process_arg_val(rest_arg, rest_vals, result)
            elsif rest_vals.size > 0
                self.errors << "#{rest_vals.size} rest #{rest_vals.size == 1 ? 'value' : 'values'} #{
                    rest_vals.size == 1 ? 'was' : 'were'} supplied, but no rest argument is defined"
            end

            # Default unspecified arguments
            @definition.args.select{ |arg| !result.has_key?(arg.key) }.each do |arg|
                result[arg.key] = process_arg_val(arg, arg.default, result, true)
            end

            # Validate if any set requirements have been satisfied
            self.errors.concat(@definition.validate_requirements(result))
            if self.errors.size > 0
                @show_usage = true
            elsif result.empty?
                BasicObject.new
            else
                props = result.keys
                @definition.args.each{ |arg| props << arg.key unless result.has_key?(arg.key) }
                args = Struct.new(*props)
                args.new(*result.values)
            end
        end


        protected


        # Process a single argument value
        def process_arg_val(arg, val, hsh, is_default = false)
            if is_default && arg.required? && (val.nil? || val.empty?)
                self.errors << "No value was specified for required argument '#{arg}'"
                return
            end
            if !is_default && val.nil? && KeywordArgument === arg && !arg.value_optional?
                self.errors << "No value was specified for keyword argument '#{arg}'"
                return
            end

            # Argument value validation
            if ValueArgument === arg && arg.validation && val
                case arg.validation
                when Regexp
                    [val].flatten.each do |v|
                        add_value_error(arg, val) unless v =~ arg.validation
                    end
                when Array
                    [val].flatten.each do |v|
                        add_value_error(arg, val) unless arg.validation.include?(v)
                    end
                when Proc
                    begin
                        arg.validation.call(val, arg, hsh)
                    rescue StandardError => ex
                        self.errors << "An error occurred in the validation handler for argument '#{arg}': #{ex}"
                        return
                    end
                else
                    raise "Unknown validation type: #{arg.validation.class.name}"
                end
            end

            # TODO: Argument value coercion

            # Call any registered on_parse handler
            begin
                val = arg.on_parse.call(val, arg, hsh) if val && arg.on_parse
            rescue StandardError => ex
                self.errors << "An error occurred in the on_parse handler for argument '#{arg}': #{ex}"
                return
            end

            # Return result
            val
        end


        # Add an error for an invalid value
        def add_value_error(arg, val)
            self.errors << "The value '#{val}' is not valid for argument '#{arg}'"
        end

    end

end

