require File.expand_path('../acceptance_test_helper', __FILE__)

class Issue272Test < Mocha::TestCase
  include AcceptanceTest

  def setup
    setup_acceptance_test
  end

  def teardown
    teardown_acceptance_test
  end

  module Mod
    private

    def foo
      'original-foo'
    end

    def bar
      'original-bar'
    end
  end

  class Klass
    extend Mod

    class << self
      public :foo
      public :bar
    end
  end

  def test_private_methods_in_module_used_to_extend_class_and_made_public
    test_result = run_as_test do
      Klass.stubs(:foo).returns('stubbed-foo')
      # hangs in next line executing:
      # `@original_method = stubbee._method(method)`
      # in Mocha::StubbedMethod#hide_original_method
      # but only in Ruby v2.3, not v2.2
      Klass.stubs(:bar).returns('stubbed-bar')
      assert_equal 'stubbed-foo', Klass.foo
      assert_equal 'stubbed-bar', Klass.bar
    end
    assert_passed(test_result)
    assert_equal 'original-foo', Klass.foo
    assert_equal 'original-bar', Klass.bar
  end
end
