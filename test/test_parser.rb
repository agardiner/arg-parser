require 'arg-parser'
require 'test/unit'


class TestParser < Test::Unit::TestCase

    include ArgParser::DSL

    title 'FooBar Tester'
    purpose 'To test the fubar-ness of stuff'
    positional_arg :foo, 'Foo arg'
    keyword_arg :bar, 'Bar arg', short_key: 'b'
    flag_arg :baz, 'Baz arg', short_key: 'z'
    rest_arg :files, 'List of files to process with fubar', required: false

    def test_parse_positional
        res = parse_arguments('Here')
        assert_equal('Here', res.foo)
        assert_nil(res.bar)
        assert_nil(res.baz)
        assert_equal([], res.files)
    end

    def test_parse_with_flag
        res = parse_arguments(['Here', '--baz'])
        assert_equal('Here', res.foo)
        assert_nil(res.bar)
        assert(res.baz)
        assert_equal([], res.files)
    end

    def test_parse_with_no_flag
        res = parse_arguments(['Here', '--no-baz'])
        assert_equal('Here', res.foo)
        assert_nil(res.bar)
        assert_equal(false, res.baz)
        assert_equal([], res.files)
    end

    def test_parse_with_keyword
        res = parse_arguments('Here --bar bold')
        assert_equal('Here', res.foo)
        assert_equal('bold', res.bar)
        assert_nil(res.baz)
        assert_equal([], res.files)
    end

    def test_parse_with_rest
        res = parse_arguments('Here bar bold')
        assert_equal('Here', res.foo)
        assert_nil(res.bar)
        assert_nil(res.baz)
        assert_equal(['bar', 'bold'], res.files)
    end

    def test_parse_order
        res = parse_arguments('-b gold Here bar --no-baz bold')
        assert_equal('Here', res.foo)
        assert_equal('gold', res.bar)
        assert_equal(false, res.baz)
        assert_equal(['bar', 'bold'], res.files)
    end

    def test_parse_with_repeated_arg
        res = parse_arguments('Here -b gold --bar silver')
        assert_equal('silver', res.bar)
    end

end

