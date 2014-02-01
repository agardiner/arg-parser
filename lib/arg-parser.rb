require 'arg-parser/argument'
require 'arg-parser/definition'
require 'arg-parser/parser'



if __FILE__ == $0
    d = ArgParser::Definition.new
    d << ArgParser::KeywordArgument.new('flawgic', 'Google flawgic', short_key: 'f')
    d << ArgParser::PositionalArgument.new('flawgic2', 'Google flawgic')
    d << ArgParser::FlagArgument.new('foo', 'Morr fubar', short_key: 'm')

    p = ArgParser::Parser.new(d)
    d.show_usage
    d.show_help

    puts '-f samsung bb'
    puts p.parse(['-f', 'samsung', 'bb']).inspect
    puts p.errors.inspect
    puts '--flawgic samsung blackbeery'
    puts p.parse(['--flawgic', 'samsung', 'Blackberry'])
    puts p.errors.inspect
    puts '--flawgic --foo argh'
    puts p.parse(['--flawgic', '--foo', 'argh']).inspect
    puts p.errors.inspect
    puts '-fm'
    puts p.parse(['-mf', 'boo', 'hoo'])
    puts p.errors.inspect
end

