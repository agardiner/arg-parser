class ArgParser

    module DSL

        module ClassMethods

            def args_def
                @args_def ||= ArgParser::Definition.new
            end

            def title(val)
                args_def.title = val
            end

            def purpose(desc)
                args_def.purpose = desc
            end

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

        def self.included(base)
            base.extend(ClassMethods)
        end

        def parse_arguments(args = ARGV)
          self.class.args_def.parse(args)
        end

    end

end
