require 'arg-parser'
require 'test/unit'


class TestDSL < Test::Unit::TestCase

    ArgParser::Argument.register :test_arg,
        ArgParser::KeywordArgument.new(:test, 'A test argument', default: 'TEST')

    include ArgParser::DSL

    title 'FooBar Tester'
    purpose 'To test the fubar-ness of stuff'
    positional_arg :bar, 'Bar arg'
    keyword_arg :baz, 'Baz arg', short_key: 'z'
    flag_arg :bat, 'Bat arg', short_key: 't'
    rest_arg :files, 'List of files to process with fubar', required: false
    predefined_arg :test_arg, default: 'PASS'

    def test_title
        assert_equal('FooBar Tester', args_def.title)
    end

    def test_purpose
        assert_equal('To test the fubar-ness of stuff', args_def.purpose)
    end

    def test_predefined
        assert_equal('TEST', ArgParser::Argument.lookup(:test_arg).default)
    end

    def test_predefined_override
        assert_equal('PASS', args_def[:test].default)
    end

end

