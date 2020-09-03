module ArgParser

    # Exeption thrown when an attempt is made to access an argument that is not
    # defined.
    class NoSuchArgumentError < RuntimeError; end


    # Represents a scope within which an argument is defined/alid.
    # Scopes may be nested, and argument requests will search the scope chain to
    # find a matching argument.
    class ArgumentScope

        attr_reader :name, :parent
        attr_accessor :predefined_args


        def initialize(name, parent = nil)
            @name = name
            @parent = parent
            @parent.add_child(self) if @parent
            @children = []
            @arguments = {}
            @short_keys = {}
            @predefined_args = nil
        end


        # Adds a Scope as a child of this scope.
        def add_child(arg_scope)
            raise ArgumentError, "#{arg_scope} must be an ArgumentScope instance" unless arg_scope.is_a?(ArgumentScope)
            raise ArgumentError, "#{arg_scope} parent not set to this ArgumentScope" if arg_scope.parent != self
            @children << arg_scope
        end


        # Checks if a key has been used in this scope, any ancestor scopes, or
        # any descendant scopes.
        #
        # @param key [String] The key under which an argument is to be registered
        # @return [Argument|nil] The Argument that already uses the key, or nil
        #   if the key is not used.
        def key_used?(key)
            self.walk_ancestors do |anc|
                arg = anc[key] if anc.has_key?(key)
                return arg if arg
            end
            self.walk_children do |child|
                arg = child[key] if child.has_key?(key)
                return arg if arg
            end
            nil
        end


        # Yields each key/argument pair for this ArgumentScope
        def walk_arguments(&blk)
            @arguments.each(&blk)
        end


        # Yields each ancestor of this scope, optionally including this scope.
        def walk_ancestors(inc_self = true, &blk)
            scope = inc_self ? self : self.parent
            while scope do
                yield scope
                scope = scope.parent
            end
        end
            

        # Recursively walks and yields each descendant scopes of this scope.
        def walk_children(inc_self = false, &blk)
            yield self if inc_self
            @children.each do |child|
                yield child
                child.walk_children(&blk)
            end
        end


        # @return [Argument] the argument for the given key if it exists, or nil
        #   if it does not.
        def has_key?(key)
            k = Argument.to_key(key)
            @arguments.has_key?(k) || @short_keys.has_key?(k)
        end


        # @return [Argument] the argument with the specified key
        # @raise [ArgumentError] if no argument has been defined with the
        #   specified key.
        def [](key)
            k = Argument.to_key(key)
            arg = @arguments[k] || @short_keys[k]
            arg or raise NoSuchArgumentError, "No argument defined for key '#{Argument.to_key(key)}'"
        end


        # Adds the specified argument to the command-line definition.
        #
        # @param arg [Argument] An Argument sub-class to be added to the command-
        #   line definition.
        def <<(arg)
            case arg
            when CommandArgument, PositionalArgument, KeywordArgument, FlagArgument, RestArgument
                if used = self.key_used?(arg.key)
                    raise ArgumentError, "An argument with key '#{arg.key}' has already been defined: #{used}"
                end
                if arg.short_key && used = self.key_used?(arg.short_key)
                    raise ArgumentError, "The short key '#{arg.short_key}' has already been registered: #{used}"
                end
                if arg.is_a?(RestArgument) && rest_args?
                    raise ArgumentError, "Only one rest argument can be defined"
                end
                @arguments[arg.key] = arg
                @short_keys[arg.short_key] = arg if arg.short_key
            else
                raise ArgumentError, "arg must be an instance of CommandArgument, PositionalArgument, " +
                    "KeywordArgument, FlagArgument or RestArgument (got #{arg.class.name})"
            end
        end


        # Add a command argument to the set of arguments in this command-line
        # argument definition.
        # @see CommandArgument#initialize
        def command_arg(key, desc, opts = {}, &block)
            cmd_arg = ArgParser::CommandArgument.new(key, desc, opts)
            CommandBlock.new(self, cmd_arg, &block)
            self << cmd_arg
        end


        # Add a positional argument to the set of arguments in this command-line
        # argument definition.
        # @see PositionalArgument#initialize
        def positional_arg(key, desc, opts = {}, &block)
            self << ArgParser::PositionalArgument.new(key, desc, opts, &block)
        end


        # Add a keyword argument to the set of arguments in this command-line
        # argument definition.
        # @see KeywordArgument#initialize
        def keyword_arg(key, desc, opts = {}, &block)
            self << ArgParser::KeywordArgument.new(key, desc, opts, &block)
        end


        # Add a flag argument to the set of arguments in this command-line
        # argument definition.
        # @see FlagArgument#initialize
        def flag_arg(key, desc, opts = {}, &block)
            self << ArgParser::FlagArgument.new(key, desc, opts, &block)
        end


        # Add a rest argument to the set of arguments in this command-line
        # argument definition.
        # @see RestArgument#initialize
        def rest_arg(key, desc, opts = {}, &block)
            self << ArgParser::RestArgument.new(key, desc, opts, &block)
        end


        # Lookup a pre-defined argument (created earlier via Argument#register),
        # and add it to this arguments definition.
        #
        # @see Argument#register
        #
        # @param lookup_key [String, Symbol] The key under which the pre-defined
        #   argument was registered.
        # @param desc [String] An optional override for the argument description
        #   for this use of the pre-defined argument.
        # @param opts [Hash] An options hash for those select properties that
        #   can be overridden on a pre-defined argument.
        # @option opts [String] :description The argument description for this
        #   use of the pre-defined argument.
        # @option opts [String] :usage_break The usage break for this use of
        #   the pre-defined argument.
        # @option opts [Boolean] :required Whether this argument is a required
        #   (i.e. mandatory) argument.
        # @option opts [String] :default The default value for the argument,
        #   returned in the command-line parse results if no other value is
        #   specified.
        def predefined_arg(lookup_key, opts = {})
            arg = nil
            self.walk_ancestors do |scope|
                if scope.predefines_args && scope.predefined_args.has_key?(lookup_key)
                    arg = scope.predefined_args[lookup_key]
                    break
                end
            end
            raise ArgumentError, "No predefined argument with key '#{lookup_key}' found" unless arg
            arg.short_key = opts[:short_key] if opts.has_key?(:short_key)
            arg.description = opts[:description] if opts.has_key?(:description)
            arg.usage_break = opts[:usage_break] if opts.has_key?(:usage_break)
            arg.required = opts[:required] if opts.has_key?(:required)
            arg.default = opts[:default] if opts.has_key?(:default)
            arg.on_parse = opts[:on_parse] if opts.has_key?(:on_parse)
            self << arg
        end


        # @return [Array] all argument keys that have been defined.
        def keys
            @arguments.keys
        end


        # @return [Array] all argument short keys that have been defined.
        def short_keys
            @short_keys.keys
        end


        # @return [Array] all arguments that have been defined.
        def args
            @arguments.values
        end


        # @return [Array] all command arguments that have been defined
        def command_args
            @arguments.values.select{ |arg| CommandArgument === arg }
        end


        # @return True if a command arg has been defined
        def command_args?
            command_args.size > 0
        end


        # @return [Array] all positional arguments that have been defined
        def positional_args
            @arguments.values.select{ |arg| CommandArgument === arg ||
                                            CommandInstance === arg ||
                                            PositionalArgument === arg }
        end


        # @return True if any positional arguments have been defined.
        def positional_args?
            positional_args.size > 0
        end


        # @return [Array] the non-positional (i.e. keyword and flag)
        #    arguments that have been defined.
        def non_positional_args
            @arguments.values.reject{ |arg| CommandArgument === arg || 
                                            CommandInstance === arg ||
                                            PositionalArgument === arg ||
                                            RestArgument === arg }
        end


        # @return True if any non-positional arguments have been defined.
        def non_positional_args?
            non_positional_args.size > 0
        end


        # @return [Array] the keyword arguments that have been defined.
        def keyword_args
            @arguments.values.select{ |arg| KeywordArgument === arg }
        end


        # @return True if any keyword arguments have been defined.
        def keyword_args?
            keyword_args.size > 0
        end


        # @return [Array] the flag arguments that have been defined
        def flag_args
            @arguments.values.select{ |arg| FlagArgument === arg }
        end


        # @return True if any flag arguments have been defined.
        def flag_args?
            flag_args.size > 0
        end


        # @return [RestArgument] the RestArgument defined for this command-line,
        #   or nil if no RestArgument is defined.
        def rest_args
            @arguments.values.find{ |arg| RestArgument === arg }
        end


        # @return True if a RestArgument has been defined.
        def rest_args?
            !!rest_args
        end


        # @return [Array] all the positional, keyword, and rest arguments
        #   that have been defined.
        def value_args
            @arguments.values.select{ |arg| ValueArgument === arg }
        end


        # @return [Array] all the sensitive arguments that have been defined
        def sensitive_args
            self.value_args.select{ |arg| arg.sensitive? }
        end


        # @return [Integer] the number of arguments that have been defined.
        def size
            @arguments.size
        end

    end


    # Used to define arguments specific to a CommandInstance
    class CommandBlock

        def initialize(arg_scope, cmd_arg, &block)
            @parent = arg_scope
            @command_arg = cmd_arg
            self.instance_eval(&block)
        end


        def define_args(&block)
            pre_def_arg_scope = ArgumentScope.new("Predefined args for #{@command_arg}")
            pre_def_arg_scope.instance_eval(&block)
            @parent.predefined_args = pre_def_arg_scope
        end


        def command(key, desc, opts = {}, &block)
            cmd_arg_scope = ArgumentScope.new("Arguments for #{key} command", @parent)
            cmd_arg_scope.instance_eval(&block) if block_given?
            cmd_inst = CommandInstance.new(key, desc, @command_arg, cmd_arg_scope, opts)
            @command_arg << cmd_inst
        end

    end


    # Represents the collection of possible command-line arguments for a script.
    class Definition < ArgumentScope

        # @return [String] A title for the script, displayed at the top of the
        #   usage and help outputs.
        attr_accessor :title
        # @return [String] A short description of the purpose of the script, for
        #   display when showing the usage help.
        attr_accessor :purpose
        # @return [String] A copyright notice, displayed in the usage and help
        #   outputs.
        attr_accessor :copyright


        # Create a new Definition, which is a collection of valid Arguments to
        # be used when parsing a command-line.
        def initialize(name = 'ArgParser::Definition')
            super(name)
            @require_set = []
            @title = $0.respond_to?(:titleize) ? $0.titleize : $0
            yield self if block_given?
        end


        # Collapses an ArgumentScope into this Definition, representing the
        # collapsed argument possibilities once a command has been identitfied
        # for a CommandArgument. Think of the original Definition as being a
        # superposition of possible argument definitions, with one possible
        # state for each CommandInstance of each commad. Once the actual
        # CommandInstance is known, we are collapsing the superposition of
        # possible definitions to a lower dimensionality; only one possible
        # definition remains once all CommandArgument objects are replaced by
        # CommandInstances.
        #
        # @param cmd_inst [CommandInstance] The instance of a command that has
        #   been specified.
        # @return [Definition] A new Definition with a set of arguments combined
        #   from this Definition and the selected ArgumentScope for a specific
        #   command instance.
        def collapse(cmd_inst)
            new_def = self.clone
            child = cmd_inst.argument_scope
            new_args = {}
            new_short_keys = {}
            @arguments.each do |key, arg|
                if arg == cmd_inst.command_arg
                    new_args[key] = cmd_inst
                    child.walk_arguments do |key, arg|
                        new_args[key] = arg
                        new_short_keys[arg.short_key] = arg if arg.short_key
                    end
                else
                    new_args[key] = arg
                    new_short_keys[arg.short_key] = arg if arg.short_key
                end
            end
            new_children = @children.reject{ |c| c == cmd_inst.argument_scope } &
                child.instance_variable_get(:@children)
            new_def.instance_variable_set(:@arguments, new_args)
            new_def.instance_variable_set(:@short_keys, new_short_keys)
            new_def.instance_variable_set(:@children, new_children)
            new_def
        end


        # Lookup a pre-defined argument (created earlier via Argument#register),
        # and add it to this arguments definition.
        #
        # @see Argument#register
        #
        # @param lookup_key [String, Symbol] The key under which the pre-defined
        #   argument was registered.
        # @param desc [String] An optional override for the argument description
        #   for this use of the pre-defined argument.
        # @param opts [Hash] An options hash for those select properties that
        #   can be overridden on a pre-defined argument.
        # @option opts [String] :description The argument description for this
        #   use of the pre-defined argument.
        # @option opts [String] :usage_break The usage break for this use of
        #   the pre-defined argument.
        # @option opts [Boolean] :required Whether this argument is a required
        #   (i.e. mandatory) argument.
        # @option opts [String] :default The default value for the argument,
        #   returned in the command-line parse results if no other value is
        #   specified.
        def predefined_arg(lookup_key, opts = {})
            arg = (self.predefined_args && self.predefined_args.key_used?(lookup_key)) ||
                Argument.lookup(lookup_key)
            arg.short_key = opts[:short_key] if opts.has_key?(:short_key)
            arg.description = opts[:description] if opts.has_key?(:description)
            arg.usage_break = opts[:usage_break] if opts.has_key?(:usage_break)
            arg.required = opts[:required] if opts.has_key?(:required)
            arg.default = opts[:default] if opts.has_key?(:default)
            arg.on_parse = opts[:on_parse] if opts.has_key?(:on_parse)
            self << arg
        end


        # Individual arguments are optional, but exactly one of +keys+ arguments
        # is required.
        def require_one_of(*keys)
            @require_set << [:one, keys.map{ |k| self[k] }]
        end


        # Individual arguments are optional, but at least one of +keys+ arguments
        # is required.
        def require_any_of(*keys)
            @require_set << [:any, keys.map{ |k| self[k] }]
        end


        # True if at least one argument is required out of multiple optional args.
        def requires_some?
            @require_set.size > 0
        end


        # @return [Parser] a Parser instance that can be used to parse this
        #   command-line Definition.
        def parser
            @parser ||= Parser.new(self)
        end


        # Parse the +args+ array of arguments using this command-line definition.
        #
        # @param args [Array, String] an array of arguments, or a String representing
        #   the command-line that is to be parsed.
        # @return [OpenStruct, false] if successful, an OpenStruct object with all
        # arguments defined as accessors, and the parsed or default values for each
        # argument as values. If unsuccessful, returns false indicating a parse
        # failure.
        # @see Parser#parse, Parser#errors, Parser#show_usage, Parser#show_help
        def parse(args = ARGV)
            parser.parse(args)
        end


        # Return an array of parse errors.
        # @see Parser#errors
        def errors
            parser.errors
        end


        # Whether user indicated they would like help on usage.
        # @see Parser#show_usage
        def show_usage?
            parser.show_usage?
        end


        # Whether user indicated they would like help on supported arguments.
        # @see Parser#show_help
        def show_help?
            parser.show_help?
        end


        # Validates the supplied +args+ Hash object, verifying that any argument
        # set requirements have been satisfied. Returns an array of error
        # messages for each set requirement that is not satisfied.
        #
        # @param args [Hash] a Hash containing the keys and values identified
        #   by the parser.
        # @return [Array] a list of errors for any argument requirements that
        #   have not been satisfied.
        def validate_requirements(args)
            errors = []
            @require_set.each do |req, set|
                count = set.count{ |arg| args.has_key?(arg.key) && args[arg.key] }
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
            errors
        end


        # Generates a usage display string
        def show_usage(out = STDERR, width = 80)
            lines = ['']
            usage_args = []
            usage_args.concat(positional_args.map(&:to_use))
            opt_args = size - usage_args.size
            usage_args << (requires_some? ? 'OPTIONS' : '[OPTIONS]') if opt_args > 0
            usage_args << rest_args.to_use if rest_args?
            lines.concat(wrap_text("USAGE: #{RUBY_ENGINE} #{$0} #{usage_args.join(' ')}", width))
            lines << ''
            lines << 'Specify the /? or --help option for more detailed help'
            lines << ''
            lines.each{ |line| out.puts line } if out
            lines
        end


        # Generates a more detailed help screen.
        # @param out [IO] an IO object on which the help information will be
        #   output. Pass +nil+ if no output to any device is desired.
        # @param width [Integer] the width at which to wrap text.
        # @return [Array] An array of lines of text, containing the help text.
        def show_help(out = STDOUT, width = 80)
            lines = ['', '']
            lines << title
            lines << title.gsub(/./, '=')
            lines << ''
            if purpose
                lines.concat(wrap_text(purpose, width))
                lines << ''
            end
            if copyright
                lines.concat(wrap_text("Copyright (c) #{copyright}", width))
                lines << ''
            end

            lines << 'USAGE'
            lines << '-----'
            pos_args = positional_args
            opt_args = size - pos_args.size
            usage_args = []
            usage_args.concat(pos_args.map(&:to_use))
            usage_args << (requires_some? ? 'OPTIONS' : '[OPTIONS]') if opt_args > 0
            usage_args << rest_args.to_use if rest_args?
            lines.concat(wrap_text("  #{RUBY_ENGINE} #{$0} #{usage_args.join(' ')}", width))
            lines << ''

            if positional_args?
                max = positional_args.map{ |arg| arg.to_s.length }.max
                pos_args = positional_args
                pos_args << rest_args if rest_args?
                pos_args.each do |arg|
                    if arg.usage_break
                        lines << ''
                        lines << arg.usage_break
                    end
                    desc = arg.description
                    desc += "\n[Default: #{arg.default}]" unless arg.default.nil?
                    wrap_text(desc, width - max - 6).each_with_index do |line, i|
                        lines << "  %-#{max}s    %s" % [[arg.to_s][i], line]
                    end
                end
                lines << ''
            end
            if command_args?
                max = command_args.reduce(0) do |max, cmd_arg|
                    m = cmd_arg.commands.map{ |_, arg| arg.to_s.length }.max
                    m > max ? m : max
                end
                command_args.each do |cmd_arg|
                    lines << ''
                    lines << "#{cmd_arg.to_use}S"
                    lines << '--------'
                    cmd_arg.commands.each do |_, arg|
                        if arg.usage_break
                            lines << ''
                            lines << arg.usage_break
                        end
                        desc = arg.description
                        wrap_text(desc, width - max - 6).each_with_index do |line, i|
                            lines << "  %-#{max}s    %s" % [[arg.to_s][i], line]
                        end
                    end
                    lines << ''
                end
            end

            if non_positional_args?
                lines << ''
                lines << 'OPTIONS'
                lines << '-------'
                max = non_positional_args.map{ |arg| arg.to_use.length }.max
                non_positional_args.each do |arg|
                    if arg.usage_break
                        lines << ''
                        lines << arg.usage_break
                    end
                    desc = arg.description
                    desc += "\n[Default: #{arg.default}]" unless arg.default.nil?
                    wrap_text(desc, width - max - 6).each_with_index do |line, i|
                        lines << "  %-#{max}s    %s" % [[arg.to_use][i], line]
                    end
                end
            end
            lines << ''

            lines.each{ |line| line.length < width ? out.puts(line) : out.print(line) } if out
            lines
        end


        # Utility method for wrapping lines of +text+ at +width+ characters.
        #
        # @param text [String] a string of text that is to be wrapped to a
        #   maximum width.
        # @param width [Integer] the maximum length of each line of text.
        # @return [Array] an Array of lines of text, each no longer than +width+
        #   characters.
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

