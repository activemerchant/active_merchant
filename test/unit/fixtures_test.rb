require 'test_helper'

class FixturesTest < Test::Unit::TestCase
  def test_sort
    keys = YAML.safe_load(File.read(ActiveMerchant::Fixtures::DEFAULT_CREDENTIALS), [], [], true).keys
    assert_equal(
      keys,
      keys.sort
    )
  end
end
