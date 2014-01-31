class ArgParser

    # Exception class for command-line parse errors
    class ParseException < RuntimeError; end


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
        attr_reader :show_usage
        # @return [Boolean] Flag set during parsing if the user has requested
        #   the help display to be shown (via --help or /?).
        attr_reader :show_help


        def initialize(definition = nil)
            @definition = definition || Definition.new
            @errors = []
        end


        # Parse the specified Array[String] of +tokens+, or ARGV if +tokens+ is
        # nil. Returns false if unable to parse successfully, or an OpenStruct
        # with accessors for every defined argument. Arguments whose values are
        # not specified will contain the agument default value, or nil if no
        # default is specified.
        def parse(tokens = nil)
            @show_usage = false
            @show_help = false
            tokens = ARGV unless tokens
            tokens = [] unless tokens
            pos_vals, kw_vals = classify_tokens(tokens)
            args = process_args(pos_vals, kw_vals) unless @show_help
            (@show_usage || @show_help) ? false : args
        end


        # Delegate unknown methods to the argument definition
        def method_missing(mthd, *args)
            if @definition.respond_to?(mthd)
                @definition.send(mthd, *args)
            else
                super
            end
        end


        protected


        # Evaluate the list of values in +tokens+, and classify them as either
        # keyword/value pairs, or positional arguments. Ideally this would be
        # done without any reference to the defined arguments, but unfortunately
        # a keyword arg cannot be distinguished from a flag arg followed by a
        # positional arg without the context of what arguments are expected.
        def classify_tokens(tokens)
            pos_vals = []
            kw_vals = {}

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
                    arg = @definition[$2] || @definition["#{$1}#{$2}"]
                    if FlagArgument === arg || (KeywordArgument === arg && $1)
                        kw_vals[arg] = $1 ? false : true
                        arg = nil
                    end
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
            [pos_vals, kw_vals]
        end


        # Process arguments using the supplied +pos_vals+ Array of positional
        # argument values, and the +kw_vals+ Hash of keyword/value.
        def process_args(pos_vals, kw_vals)
            result = {}

            # Process positional arguments
            pos_args = @definition.positional_args
            pos_args.each_with_index do |arg, i|
                break if i >= pos_vals.length
                val = process_arg_val(arg, pos_vals[i], result)
                result[arg.key] = val
            end
            if pos_vals.size > pos_args.size
                self.errors << "#{pos_vals.size} positional #{pos_vals.size == 1 ? 'argument' : 'arguments'} #{
                    pos_vals.size == 1 ? 'was' : 'were'} supplied, but only #{pos_args.size} #{
                    pos_args.size == 1 ? 'is' : 'are'} defined"
            end

            # Process key-word based arguments
            kw_vals.each do |arg, val|
                val = process_arg_val(arg, val, result)
                result[arg.key] = val
            end

            # Default unspecified arguments
            @definition.args.select{ |arg| !result.has_key?(arg.key) }.each do |arg|
                result[arg.key] = process_arg_val(arg, arg.default, result, true)
            end

            # Validate if any set requirements have been satisfied
            self.errors.concat(@definition.validate_requirements(result))
            if self.errors.size > 0
                @show_usage = true
            else
                props = result.keys
                @definition.args.each{ |arg| props << arg.key unless result.has_key?(arg.key) }
                args = Struct.new(*props)
                args.new(*result.values)
            end
        end


        # Process a single argument value
        def process_arg_val(arg, val, hsh, is_default = false)
            if is_default && arg.required? && val.nil?
                self.errors << "No value was specified for required argument '#{arg}'"
                return
            end
            if !is_default && val.nil? && KeywordArgument === arg && !arg.value_optional?
                self.errors << "No value was specified for argument '#{arg}'"
                return
            end

            # Argument value validation
            if ValueArgument === arg && arg.validation && val
                valid = case arg.validation
                when Regexp then val =~ arg.validation
                when Proc then arg.validation.call(val)
                when Array then arg.validation.include?(val)
                else raise "Unknown validation type: #{arg.validation.class.name}"
                end
                self.errors << "The value '#{val}' is not valid for argument '#{arg}'" unless valid
            end

            # TODO: Argument value coercion

            # Call any registered on_parse handler
            val = arg.on_parse.call(arg, val, hsh) if val && arg.on_parse

            # Return result
            val
        end

    end

end

