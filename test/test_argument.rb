require 'arg-parser'
require 'test/unit'

class TestPositionalArg < Test::Unit::TestCase

    def positional_arg(key, desc, opts = {}, &block)
        ArgParser::PositionalArgument.new(key, desc, opts, &block)
    end

    def test_minimal_arg
        pa = positional_arg(:foo, 'A foo argument')
        assert_equal(:foo, pa.key)
        assert_equal('A foo argument', pa.description)
        assert(pa.required)
        assert(pa.required?)
        assert_nil(pa.short_key)
        assert_nil(pa.default)
    end

    def test_key
        pa = positional_arg('foo', 'Some foo')
        assert_equal(:foo, pa.key)
        pa = positional_arg('--foo', 'Some foo')
        assert_equal(:foo, pa.key)
        pa = positional_arg('foo-bar', 'Some foo')
        assert_equal(:foo_bar, pa.key)
    end

    def test_short_key
        pa = positional_arg('foo', 'Some foo', short_key: 'f')
        assert_equal(:f, pa.short_key)
        pa = positional_arg('foo', 'Some foo', short_key: '-F')
        assert_equal(:F, pa.short_key)
        pa = positional_arg('foo', 'Some foo', short_key: '3')
        assert_equal(3.to_s.intern, pa.short_key)
        assert_raise(ArgumentError) { positional_arg('foo', 'Some foo', short_key: 'bar') }
    end

    def test_required
        pa = positional_arg('foo', 'Some foo', required: false)
        assert(!pa.required?)
    end

    def test_default
        pa = positional_arg('foo', 'Some foo', default: 'bar')
        assert_equal('bar', pa.default)
        assert(!pa.required?)
    end

end
