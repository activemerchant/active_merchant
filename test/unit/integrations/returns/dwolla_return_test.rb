require 'test_helper'

class DwollaReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @error_dwolla = Dwolla::Return.new(http_raw_data_failure)
    @failed_callback_dwolla = Dwolla::Return.new(http_raw_data_failed_callback)
    @dwolla = Dwolla::Return.new(http_raw_data_success)
  end

  def test_error_return
    assert_false @error_dwolla.success?
  end

  def test_error_accessors
    assert_equal "failure", @error_dwolla.error
    assert_equal "Invalid application credentials.", @error_dwolla.error_description
  end

  def test_failed_callback_return
    assert_false @failed_callback_dwolla.success?
  end

  def test_failed_callback_accessors
    assert_equal "4ac56e71-8a45-4be2-be5e-03a2db87f418", @failed_callback_dwolla.checkout_id
    assert_equal "1", @failed_callback_dwolla.transaction
    assert @failed_callback_dwolla.test?
  end

  def test_success_return
    assert @dwolla.success?
  end

  def test_success_accessors
    assert_equal "4ac56e71-8a45-4be2-be5e-03a2db87f418", @dwolla.checkout_id
    assert_equal "1", @dwolla.transaction
    assert @dwolla.test?
  end
  
  private
  def http_raw_data_success
    "checkoutid=4ac56e71-8a45-4be2-be5e-03a2db87f418&transaction=1&postback=success&test=true"
  end

  def http_raw_data_failed_callback
    "checkoutid=4ac56e71-8a45-4be2-be5e-03a2db87f418&transaction=1&postback=failure&test=true"
  end
  
  def http_raw_data_failure
    "error=failure&error_description=Invalid+application+credentials."
  end
end


