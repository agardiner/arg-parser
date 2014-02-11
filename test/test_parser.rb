require 'arg-parser'



class Test

    include ArgParser::DSL

    title 'FooBar Tester'
    purpose 'To test the fubar-ness of Google flawgic'
    positional_arg :flawgic2, 'Google flawgic - part 2'
    keyword_arg :flawgic, 'Google flawgic', short_key: 'f'
    flag_arg :foo, 'Morr fubar', short_key: 'm'
    rest_arg :files, 'List of files to process with fubar', required: false

    COMMAND_LINE = ArgParser::Definition.new do |d|
        d.title = 'Sudoku Solver'
        d.purpose = 'Solves Sudoku puzzles from input grids'
        d.keyword_arg :difficulty, 'The rated difficulty of the Sudoku puzzle'
        d.flag_arg :debug, 'Output debug info'
    end

    def parse(argv)
        @parser = ArgParser::Parser.new(self.class.args_def)
        @parser.parse(argv)
    end

    def errors
        @parser.errors
    end

end

=begin
d = ArgParser::Definition.new
d << ArgParser::KeywordArgument.new('flawgic', 'Google flawgic', short_key: 'f')
d << ArgParser::PositionalArgument.new('flawgic2', 'Google flawgic')
d << ArgParser::FlagArgument.new('foo', 'Morr fubar', short_key: 'm')

p = ArgParser::Parser.new(d)
=end

p = Test.new
d = Test.args_def
d.show_usage
d.show_help

puts d.positional_args.inspect

puts '-f samsung bb moto nokia'
puts p.parse(['me', '--', 'samsung', 'bb', 'moto', 'nokia']).inspect
puts p.parse(['-f', 'samsung', 'bb', 'moto', 'nokia']).inspect
puts p.errors.inspect
puts p.parse 'This is a "long string" of text'
puts '--flawgic samsung blackbeery'
puts p.parse(['--flawgic', 'samsung', 'Blackberry'])
puts p.errors.inspect
puts '--flawgic --foo argh'
puts p.parse(['--flawgic', '--foo', 'argh']).inspect
puts p.errors.inspect
puts '-fm'
puts p.parse(['-mf', 'boo', 'hoo'])
puts p.errors.inspect

puts Test::COMMAND_LINE.parse

