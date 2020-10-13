require File.expand_path('../acceptance_test_helper', __FILE__)

class DisplayMatchingInvocationsAlongsideExpectationsTest < Mocha::TestCase
  include AcceptanceTest

  def setup
    setup_acceptance_test
    Mocha.configuration.display_matching_invocations_on_failure = true
  end

  def test_should_display_results
    test_result = run_as_test do
      foo = mock('foo')
      foo.expects(:bar).with(1).returns('a')
      foo.stubs(:bar).with(any_parameters).returns('f').raises(StandardError).throws(:tag, 'value')

      foo.bar(1, 2)
      assert_raises(StandardError) { foo.bar(3, 4) }
      assert_throws(:tag) { foo.bar(5, 6) }
    end
    assert_invocations(
      test_result,
      '- allowed any number of times, invoked 3 times: #<Mock:foo>.bar(any_parameters)',
      '  - #<Mock:foo>.bar(1, 2) # => "f"',
      '  - #<Mock:foo>.bar(3, 4) # => raised StandardError',
      '  - #<Mock:foo>.bar(5, 6) # => threw (:tag, "value")'
    )
  end

  def test_should_display_yields
    test_result = run_as_test do
      foo = mock('foo')
      foo.expects(:bar).with(1).returns('a')
      foo.stubs(:bar).with(any_parameters).multiple_yields('bc', %w[d e]).returns('f').raises(StandardError).throws(:tag, 'value')

      foo.bar(1, 2) { |_ignored| }
      assert_raises(StandardError) { foo.bar(3, 4) { |_ignored| } }
      assert_throws(:tag) { foo.bar(5, 6) { |_ignored| } }
    end
    assert_invocations(
      test_result,
      '- allowed any number of times, invoked 3 times: #<Mock:foo>.bar(any_parameters)',
      '  - #<Mock:foo>.bar(1, 2) { ... } # => "f" after yielding ("bc"), then ("d", "e")',
      '  - #<Mock:foo>.bar(3, 4) { ... } # => raised StandardError after yielding ("bc"), then ("d", "e")',
      '  - #<Mock:foo>.bar(5, 6) { ... } # => threw (:tag, "value") after yielding ("bc"), then ("d", "e")'
    )
  end

  def test_should_display_empty_yield_and_return
    test_result = run_as_test do
      foo = mock('foo')
      foo.expects(:bar).with(1).returns('a')
      foo.stubs(:bar).with(any_parameters).yields

      foo.bar(1, 2) { |_ignored| }
    end
    assert_invocations(
      test_result,
      '- allowed any number of times, invoked once: #<Mock:foo>.bar(any_parameters)',
      '  - #<Mock:foo>.bar(1, 2) { ... } # => nil after yielding ()'
    )
  end

  def assert_invocations(test_result, *invocations)
    assert_failed(test_result)
    assert_equal invocations.unshift('satisfied expectations:'),
                 test_result.failure_message_lines[-invocations.size..-1]
  end
end
