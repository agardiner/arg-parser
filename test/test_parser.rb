require 'arg-parser'
require 'test/unit'


class TestParser < Test::Unit::TestCase

    class Arg1
        include ArgParser::DSL

        title 'FooBar Tester'
        purpose 'To test the fubar-ness of stuff'
        positional_arg :foo, 'Foo arg'
        keyword_arg :bar, 'Bar arg', short_key: 'b'
        keyword_arg :opt, 'Optional val', value_optional: 'Used'
        keyword_arg :opt_def, 'Optional val with default', value_optional: true,
            default: false
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


    def test_on_use
        res = @a1.parse_arguments('One tow')
        assert(!res.opt)
        res = @a1.parse_arguments('One two --opt bag')
        assert_equal('bag', res.opt)
        assert_equal(false, res.opt_def)
        res = @a1.parse_arguments('One two --opt --bar fee')
        assert_equal('Used', res.opt)
        res = @a1.parse_arguments('One two --opt-def --bar fee')
        assert_equal(true, res.opt_def)
        res = @a1.parse_arguments('One two --opt-def five --bar fee')
        assert_equal('five', res.opt_def)
    end

end

