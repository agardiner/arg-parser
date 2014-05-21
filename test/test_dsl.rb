require 'arg-parser'
require 'test/unit'


class TestDSL < Test::Unit::TestCase

    include ArgParser::DSL

    title 'FooBar Tester'
    purpose 'To test the fubar-ness of stuff'
    positional_arg :bar, 'Bar arg'
    keyword_arg :baz, 'Baz arg', short_key: 'z'
    flag_arg :bat, 'Bat arg', short_key: 't'
    rest_arg :files, 'List of files to process with fubar', required: false

    def test_title
        assert_equal('FooBar Tester', args_def.title)
    end

    def test_purpose
        assert_equal('To test the fubar-ness of stuff', args_def.purpose)
    end

end

