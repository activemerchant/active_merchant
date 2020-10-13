require File.expand_path('../../test_helper', __FILE__)

require 'mocha/central'
require 'mocha/mock'

class CentralTest < Mocha::TestCase
  include Mocha

  def test_should_start_with_empty_stubba_methods
    stubba = Central.new

    assert_equal [], stubba.stubba_methods
  end

  def test_should_stub_method_if_not_already_stubbed
    method = build_mock
    method.expects(:stub)
    stubba = Central.new

    stubba.stub(method)

    assert method.__verified__?
  end

  def test_should_not_stub_method_if_already_stubbed
    method = build_mock
    method.stubs(:matches?).returns(true)
    method.expects(:stub).times(0)
    stubba = Central.new
    stubba.stubba_methods = [method]

    stubba.stub(method)

    assert method.__verified__?
  end

  def test_should_record_method
    method = build_mock
    method.expects(:stub)
    stubba = Central.new

    stubba.stub(method)

    assert_equal [method], stubba.stubba_methods
  end

  def test_should_unstub_specified_method
    stubba = Central.new
    method1 = build_mock
    method1.stubs(:matches?).returns(false)
    method2 = build_mock
    method2.stubs(:matches?).returns(true)
    method2.expects(:unstub)
    stubba.stubba_methods = [method1, method2]

    stubba.unstub(method2)

    assert_equal [method1], stubba.stubba_methods
    assert method2.__verified__?
  end

  def test_should_not_unstub_specified_method_if_not_already_stubbed
    stubba = Central.new
    method1 = build_mock
    method1.stubs(:matches?).returns(false)
    method2 = build_mock
    method2.expects(:unstub).never
    stubba.stubba_methods = [method1]

    stubba.unstub(method2)

    assert_equal [method1], stubba.stubba_methods
    assert method2.__verified__?
  end

  def test_should_unstub_all_methods
    stubba = Central.new
    method1 = build_mock
    method1.stubs(:matches?).returns(true)
    method1.expects(:unstub)
    method2 = build_mock
    method2.stubs(:matches?).returns(true)
    method2.expects(:unstub)
    stubba.stubba_methods = [method1, method2]

    stubba.unstub_all

    assert_equal [], stubba.stubba_methods
    assert method1.__verified__?
    assert method2.__verified__?
  end

  private

  def build_mock
    Mock.new(nil)
  end
end
