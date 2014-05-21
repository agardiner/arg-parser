require 'arg-parser'
require 'test/unit'

class TestDefinition < Test::Unit::TestCase

    include ArgParser::DSL

    positional_arg :foo, 'Foo'
    keyword_arg :bar, 'Bar', short_key: '-b'
    flag_arg :baz, 'Baz', short_key: 'B'

    require_one_of :bar, :baz


    def test_key
        assert(args_def.has_key?(:foo))
        assert(args_def.has_key?('foo'))
        assert(args_def.has_key?('b'))
        assert(args_def.has_key?(:B))
    end

end
