require 'test_helper'

class VersionableTest < Test::Unit::TestCase
  class DummyClass
    include ActiveMerchant::Versionable
    self.versions = {}
  end

  def setup
    @instance = DummyClass.new
  end

  def test_class_can_set_and_fetch_default_version
    DummyClass.version('1.0')
    assert_equal '1.0', DummyClass.fetch_version, 'Class should return the correct version'
  end

  def test_class_can_set_and_fetch_custom_feature_version
    DummyClass.version('2.0', :custom_api)
    DummyClass.version('v2', :some_feature)
    assert_equal '2.0', DummyClass.fetch_version(:custom_api), 'Class should return the correct version'
    assert_equal 'v2', DummyClass.fetch_version(:some_feature), 'Class should return the correct version'
  end

  def test_instance_can_fetch_default_version
    DummyClass.version('v3')
    assert_equal 'v3', @instance.fetch_version, 'Instance should return the correct version'
  end

  def test_instance_can_fetch_custom_feature_version
    DummyClass.version('v4', :custom_api)
    DummyClass.version('4.0', :some_feature)
    assert_equal 'v4', @instance.fetch_version(:custom_api), 'Instance should return the correct version'
    assert_equal '4.0', @instance.fetch_version(:some_feature), 'Instance should return the correct version'
  end

  def test_fetch_version_returns_nil_for_unset_feature
    assert_nil DummyClass.fetch_version(:nonexistent_feature), 'Class should return nil for an unset feature'
    assert_nil @instance.fetch_version(:nonexistent_feature), 'Instance should return nil for an unset feature'
  end
end
