require 'test_helper'

class DeferredTest < Test::Unit::TestCase
  def setup
    @deferred = deferred
  end

  def teardown
  end

  def test_constructor_should_properly_assign_values
    d = @deferred

    assert_equal 1.week.from_now.to_date, d.expiration_date
    assert_equal 'Longbob Longsen', d.name
    assert_equal 'RAPIPAGO', d.brand
    assert_valid d
  end

  def test_new_deferred_should_not_be_valid
    d = Deferred.new
    assert_not_valid d
  end

  def test_should_validate_presence
    errors = assert_not_valid Deferred.new

    %i[first_name last_name brand expiration_date].each do |attr|
      assert_equal ['is required'], errors[attr], attr
    end
  end

  def test_should_validate_expired_date
    @deferred.expiration_date = Date.today

    errors = assert_not_valid @deferred
    assert_equal ['expired'], errors[:expiration_date]
  end
end
