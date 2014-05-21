require 'arg-parser'


class RestArgExample

    include ArgParser::DSL

    positional_arg :command, 'The command to run',
        validation: ['list', 'other'] do |val, arg, hsh|
            val.intern
        end
    keyword_arg :directory, 'The directory in which to run the command',
        default: '.'

    rest_arg :files, 'The files to operate on'


    def run
        if cmd = parse_arguments
            send(cmd.command, cmd.directory, *cmd.files)
        else
            puts parse_errors.inspect
        end
    end


    def list(dir, *files)
        Dir["#{dir}/*"].each do |file|
            if File.basename(file)
                # List file
                puts file
            end
        end
    end


    def other(dir, *files)
    end

end


RestArgExample.new.run if __FILE__ == $0
