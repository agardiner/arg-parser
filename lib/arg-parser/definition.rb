class ArgParser

    # Represents the collection of possible command-line arguments for a script.
    class Definition

        # @return [String] A title for the script, displayed at the top of the
        #   usage information.
        attr_accessor :title
        # @return [String] A short description of the purpose of the script, for
        #   display when showing the usage help.
        attr_accessor :purpose


        def initialize
            @arguments = {}
            @short_keys = {}
            @require_set = Hash.new{ |h,k| h[k] = [] }
            @title = $0.respond_to?(:titleize) ? $0.titleize : $0
        end


        # Returns the argument with the specified key
        def [](key)
            k = key.to_s.downcase.gsub('-', '_').intern
            arg = @arguments[k] || @short_keys[key.intern]
            arg or raise ArgumentError, "No argument defined for key '#{k}'"
        end


        # Adds the specified argument to the command-line definition.
        #
        # @param arg [Argument] An Argument sub-class to be added to the command-
        #   line definition.
        def <<(arg)
            case arg
            when PositionalArgument, KeywordArgument, FlagArgument
                if @arguments[arg.key]
                    raise ArgumentError, "An argument with key '#{arg.key}' has already been defined"
                end
                if arg.short_key && @short_keys[arg.short_key]
                    raise ArgumentError, "An argument with short key '#{arg.short_key}' has already been defined"
                end
                @arguments[arg.key] = arg
                @short_keys[arg.short_key] = arg if arg.short_key
            else
                raise ArgumentError, "arg must be an instance of PositionalArgument, KeywordArgument, or FlagArgument"
            end
        end


        # Individual arguments are optional, but exactly one of +keys+ arguments
        # is required.
        def require_one_of(*keys)
            @require_set[:one] << keys.map{ |k| self[k] }
        end


        # Individual arguments are optional, but at least one of +keys+ arguments
        # is required.
        def require_any_of(*keys)
            @require_set[:any] << keys.map{ |k| self[k] }
        end


        # True if at least one argument is required out of multiple optional args.
        def requires_some?
            @require_set.size > 0
        end


        # Validates the supplied +args+ Hash object, verifying that any argument
        # set requirements have been satisfied. Returns an array of error
        # messages for each set requirement that is not satisfied.
        def validate_requirements(args)
            errors = []
            @require_set.each do |req, sets|
                sets.each do |set|
                    count = set.count{ |arg| args[arg.key] }
                    case req
                    when :one
                        if count == 0
                            errors << "No argument has been specified for one of: #{set.join(', ')}"
                        elsif count > 1
                            errors << "Only one argument can been specified from: #{set.join(', ')}"
                        end
                    when :any
                        if count == 0
                            errors << "At least one of the arguments must be specified from: #{set.join(', ')}"
                        end
                    end
                end
            end
            errors
        end

        # Returns all arguments that have been defined
        def args
            @arguments.values
        end


        # Returns the positional arguments that have been defined
        def positional_args
            @arguments.values.select{ |arg| PositionalArgument === arg }
        end


        # True if any positional arguments have been defined
        def positional_args?
            positional_args.size > 0
        end


        # Returns the non-positional arguments that have been defined
        def non_positional_args
            @arguments.values.reject{ |arg| PositionalArgument === arg }
        end


        # True if any non-positional arguments have been defined
        def non_positional_args?
            non_positional_args.size > 0
        end


        # Returns the keyword arguments that have been defined
        def keyword_args
            @arguments.values.select{ |arg| KeywordArgument === arg }
        end


        # True if any keyword arguments have been defined
        def keyword_args?
            keyword_args.size > 0
        end


        # Returns the flag arguments that have been defined
        def flag_args
            @arguments.values.select{ |arg| FlagArgument === arg }
        end


        # True if any flag arguments have been defined
        def flag_args?
            flag_args.size > 0
        end


        # Returns the positional and keyword arguments that have been defined
        def value_args
            @arguments.values.select{ |arg| ValueArgument === arg }
        end


        # Returns the number of arguments that have been defined
        def size
            @arguments.size
        end


        # Generates a usage display string
        def show_usage(out = STDERR, width = 80)
            lines = ['']
            pos_args = positional_args
            opt_args = size - pos_args.size
            usage_args = pos_args.map(&:to_use)
            usage_args << (requires_some? ? 'OPTIONS' : '[OPTIONS]') if opt_args > 0
            lines.concat(wrap_text("USAGE: #{RUBY_ENGINE} #{$0} #{usage_args.join(' ')}", width))
            lines << ''
            lines << 'Specify the /? or --help option for more detailed help'
            lines << ''
            lines.each{ |line| out.puts line } if out
            lines
        end


        # Generates a more detailed help screen
        def show_help(out = STDOUT, width = 80)
            lines = ['', '']
            lines << title
            lines << title.gsub(/./, '=')
            lines << ''
            if purpose
                lines.concat(wrap_text(purpose, width))
                lines << ''
                lines << ''
            end

            lines << 'USAGE'
            lines << '-----'
            pos_args = positional_args
            opt_args = size - pos_args.size
            usage_args = pos_args.map(&:to_use)
            usage_args << (requires_some? ? 'OPTIONS' : '[OPTIONS]') if opt_args > 0
            lines.concat(wrap_text("  #{RUBY_ENGINE} #{$0} #{usage_args.join(' ')}", width))
            lines << ''

            if positional_args?
                max = positional_args.map{ |a| a.to_s.length }.max
                positional_args.each do |arg|
                    if arg.usage_break
                        lines << ''
                        lines << arg.usage_break
                    end
                    desc = arg.description
                    desc << "\n[Default: #{arg.default}]" unless arg.default.nil?
                    wrap_text(desc, width - max - 6).each_with_index do |line, i|
                        lines << "  %-#{max}s    %s" % [[arg.to_s][i], line]
                    end
                end
                lines << ''
            end
            if non_positional_args?
                lines << ''
                lines << 'OPTIONS'
                lines << '-------'
                max = non_positional_args.map{ |a| a.to_use.length }.max
                non_positional_args.each do |arg|
                    if arg.usage_break
                        lines << ''
                        lines << arg.usage_break
                    end
                    desc = arg.description
                    desc << "\n[Default: #{arg.default}]" unless arg.default.nil?
                    wrap_text(desc, width - max - 6).each_with_index do |line, i|
                        lines << "  %-#{max}s    %s" % [[arg.to_use][i], line]
                    end
                end
            end
            lines << ''

            lines.each{ |line| line.length < width ? out.puts(line) : out.print(line) } if out
            lines
        end


        def wrap_text(text, width)
            if width > 0 && (text.length > width || text.index("\n"))
                lines = []
                start, nl_pos, ws_pos, wb_pos, end_pos = 0, 0, 0, 0, text.rindex(/[^\s]/)
                while start < end_pos
                    last_start = start
                    nl_pos = text.index("\n", start)
                    ws_pos = text.rindex(/ +/, start + width)
                    wb_pos = text.rindex(/[\-,.;#)}\]\/\\]/, start + width - 1)
                    ### Debug code ###
                    #STDERR.puts self
                    #ind = ' ' * end_pos
                    #ind[start] = '('
                    #ind[start+width < end_pos ? start+width : end_pos] = ']'
                    #ind[nl_pos] = 'n' if nl_pos
                    #ind[wb_pos] = 'b' if wb_pos
                    #ind[ws_pos] = 's' if ws_pos
                    #STDERR.puts ind
                    ### End debug code ###
                    if nl_pos && nl_pos <= start + width
                        lines << text[start...nl_pos].strip
                        start = nl_pos + 1
                    elsif end_pos < start + width
                        lines << text[start..end_pos]
                        start = end_pos
                    elsif ws_pos && ws_pos > start && ((wb_pos.nil? || ws_pos > wb_pos) ||
                          (wb_pos && wb_pos > 5 && wb_pos - 5 < ws_pos))
                        lines << text[start...ws_pos]
                        start = text.index(/[^\s]/, ws_pos + 1)
                    elsif wb_pos && wb_pos > start
                        lines << text[start..wb_pos]
                        start = wb_pos + 1
                    else
                        lines << text[start...(start+width)]
                        start += width
                    end
                    if start <= last_start
                        # Detect an infinite loop, and just return the original text
                        STDERR.puts "Inifinite loop detected at #{__FILE__}:#{__LINE__}"
                        STDERR.puts "  width: #{width}, start: #{start}, nl_pos: #{nl_pos}, " +
                                    "ws_pos: #{ws_pos}, wb_pos: #{wb_pos}"
                        return [text]
                    end
                end
                lines
            else
                [text]
            end
        end

    end

end

