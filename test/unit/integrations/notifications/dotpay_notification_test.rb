require 'test_helper'

class DotpayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @dotpay = Dotpay::Notification.new(http_raw_data, :pin => 'my3secret1pinCod')
    @dotpay_error = Dotpay::Notification.new(http_raw_data_error, :pin => 'my3secret1pinCod')
    @dotpay_test = Dotpay::Notification.new(http_raw_test_data, :pin => 'my3secret1pinCod')
  end

  def test_accessors
    assert @dotpay.complete?
    assert_equal "OK", @dotpay.status
    assert_equal "2", @dotpay.t_status
    assert_equal "42655trans", @dotpay.t_id
    assert_equal "150.00", @dotpay.gross
    assert_equal "1234567890", @dotpay.control
    assert_equal "150.00 PLN", @dotpay.orginal_amount
    assert_equal "example@email.com", @dotpay.email
    assert_equal "Description", @dotpay.description
    assert_equal "PLN", @dotpay.currency
    assert_equal "8f63de71b987e61cb8fa98bcb88100a2", @dotpay.md5
  end

  def test_accessors_error
    assert !@dotpay_error.complete?
    assert_equal "3", @dotpay_error.t_status
    assert_equal "1e0a636401a3a0604890a957b0d014f7", @dotpay_error.md5
  end

  def test_compositions
    assert_equal Money.new(15000, 'PLN'), @dotpay.amount
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement    
    assert @dotpay.acknowledge
  end

  def test_pin_setter
    @dotpay.pin = 'wrongpin'
    assert !@dotpay.acknowledge
  end

  def test_respond_to_acknowledge
    assert @dotpay.respond_to?(:acknowledge)
  end

  def test_acknowledgement_with_wrong_pin
    @dotpay = Dotpay::Notification.new(http_raw_data, :pin => "XXXX")
    assert !@dotpay.acknowledge
  end

  def test_generate_signature_string
    assert_equal "my3secret1pinCod:42655:1234567890:42655trans:150.00:example@email.com:::::2",
                 @dotpay.generate_signature_string
  end

  def test_generate_md5check
    assert_equal "8f63de71b987e61cb8fa98bcb88100a2", @dotpay.generate_signature
  end

  def test_generate_md5check_when_error
      assert_equal "1e0a636401a3a0604890a957b0d014f7", @dotpay_error.generate_signature
  end

  def test_test_notification
    assert !@dotpay.test?
    assert @dotpay_test.test?
  end

  private
  def http_raw_data
    "status=OK&id=42655&t_id=42655trans&transaction_id=42655trans&control=1234567890&amount=150.00" +
    "&orginal_amount=150.00 PLN&email=example@email.com&description=Description&t_status=2&t_date=" +
    "&version=1.4&channel=&code=&service=&md5=8f63de71b987e61cb8fa98bcb88100a2"
  end

  def http_raw_data_error
    "status=OK&id=42655&t_id=42655trans&transaction_id=42655trans&control=1234567890&amount=150.00" +
    "&orginal_amount=150.00 PLN&email=example@email.com&description=Description&t_status=3&t_date=" +
    "&version=1.4&channel=&code=&service=&md5=1e0a636401a3a0604890a957b0d014f7"
  end

  def http_raw_test_data
    "status=OK&id=42655&t_id=42655-TST11&transaction_id=42655-TST11&control=1234567890&amount=150.00" +
    "&orginal_amount=150.00 PLN&email=example@email.com&description=Description&t_status=2&t_date=" +
    "&version=1.4&channel=&code=&service=&md5=455acc67fa94b1d6e5c0f7ebd7b032c9"
  end
end
