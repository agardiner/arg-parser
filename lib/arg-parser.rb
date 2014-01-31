require 'arg-parser\argument'
require 'arg-parser\definition'
require 'arg-parser\parser'



if __FILE__ == $0
    d = ArgParser::Definition.new
    d << ArgParser::KeywordArgument.new('flawgic', 'Google flawgic', short_key: 'f')
    d << ArgParser::PositionalArgument.new('flawgic2', 'Google flawgic')
    d << ArgParser::FlagArgument.new('foo', 'Morr fubar', short_key: 'm')

    p = ArgParser::Parser.new(d)
    d.show_usage
    d.show_help

    puts p.parse(['flawgic:samsung', 'bb']).inspect
    puts p.parse(['--flawgic', 'samsung', 'Blackberry'])
    puts p.errors.inspect
    puts p.parse.inspect
    puts p.parse(['--flawgic', '--foo', 'argh']).inspect
    p.parse(['-fm'])
end

