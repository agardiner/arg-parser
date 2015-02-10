require 'arg-parser'
require 'test/unit'


class TestParser < Test::Unit::TestCase

    class Arg1
        include ArgParser::DSL

        title 'FooBar Tester'
        purpose 'To test the fubar-ness of stuff'
        positional_arg :foo, 'Foo arg'
        keyword_arg :bar, 'Bar arg', short_key: 'b'
        flag_arg :baz, 'Baz arg', short_key: 'z'
        rest_arg :files, 'List of files to process with fubar', required: false
    end


    class Arg0
        include ArgParser::DSL

        title 'No args'
    end


    def setup
        @a1 = Arg1.new
    end

    def test_parse_positional
        res = @a1.parse_arguments('Here')
        assert_equal('Here', res.foo)
        assert_nil(res.bar)
        assert_nil(res.baz)
        assert_equal([], res.files)
    end

    def test_parse_with_flag
        res = @a1.parse_arguments(['Here', '--baz'])
        assert_equal('Here', res.foo)
        assert_nil(res.bar)
        assert(res.baz)
        assert_equal([], res.files)
    end

    def test_parse_with_no_flag
        res = @a1.parse_arguments(['Here', '--no-baz'])
        assert_equal('Here', res.foo)
        assert_nil(res.bar)
        assert_equal(false, res.baz)
        assert_equal([], res.files)
    end

    def test_parse_with_keyword
        res = @a1.parse_arguments('Here --bar bold')
        assert_equal('Here', res.foo)
        assert_equal('bold', res.bar)
        assert_nil(res.baz)
        assert_equal([], res.files)
    end

    def test_parse_with_rest
        res = @a1.parse_arguments('Here bar bold')
        assert_equal('Here', res.foo)
        assert_nil(res.bar)
        assert_nil(res.baz)
        assert_equal(['bar', 'bold'], res.files)
    end

    def test_parse_order
        res = @a1.parse_arguments('-b gold Here bar --no-baz bold')
        assert_equal('Here', res.foo)
        assert_equal('gold', res.bar)
        assert_equal(false, res.baz)
        assert_equal(['bar', 'bold'], res.files)
    end

    def test_parse_with_repeated_arg
        res = @a1.parse_arguments('Here -b gold --bar silver')
        assert_equal('silver', res.bar)
    end

    def test_no_definition
        a0 = Arg0.new
        res = a0.parse_arguments([])
    end

end

