require 'test_helper'

class WorldPayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @world_pay = WorldPay::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @world_pay.complete?
    assert_equal "Completed", @world_pay.status
    assert_equal "1234123412341234", @world_pay.transaction_id
    assert_equal "1", @world_pay.item_id
    assert_equal "5.00", @world_pay.gross
    assert_equal "GBP", @world_pay.currency
    assert_equal Time.utc('2007-01-01 00:00:00').utc, @world_pay.received_at
    assert @world_pay.test?
  end

  def test_compositions
    assert_equal Money.new(500, 'GBP'), @world_pay.amount
  end
  
  def test_extra_accessors
    assert_equal "Andrew White", @world_pay.name
    assert_equal "1 Nowhere Close", @world_pay.address
    assert_equal "CV1 1AA", @world_pay.postcode
    assert_equal "GB", @world_pay.country
    assert_equal "024 7699 9999", @world_pay.phone_number
    assert_equal "024 7699 9999", @world_pay.fax_number
    assert_equal "andyw@example.com", @world_pay.email_address
    assert_equal "Mastercard", @world_pay.card_type
  end

  def test_respond_to_acknowledge
    assert @world_pay.respond_to?(:acknowledge)
  end

  def test_payment_successful_status
    notification = WorldPay::Notification.new('transStatus=Y')
    assert_equal 'Completed', notification.status
  end
  
  def test_payment_cancelled_status
    notification = WorldPay::Notification.new('transStatus=C')
    assert_equal 'Cancelled', notification.status
  end
  
  def test_callback_password
    assert_equal 'password', @world_pay.security_key
  end
  
  def test_fraud_prevention_checks
    assert_equal :matched, @world_pay.cvv_status
    assert_equal :matched, @world_pay.postcode_status
    assert_equal :matched, @world_pay.address_status
    assert_equal :matched, @world_pay.country_status
  end
  
  def test_custom_parameters
    notification = WorldPay::Notification.new("M_custom_1=Custom Value 1&MC_custom_2=Custom Value 2&CM_custom_3=Custom Value 3")
    assert_equal 'Custom Value 1', notification.custom_params[:custom_1]
    assert_equal 'Custom Value 2', notification.custom_params[:custom_2]
    assert_equal 'Custom Value 3', notification.custom_params[:custom_3]
  end
  
  
  private

  def http_raw_data
    "transId=1234123412341234&transStatus=Y&currency=GBP&transTime=1167609600000&testMode=100&authAmount=5.00&cartId=1&authCurrency=GBP&callbackPW=password&countryMatch=Y&AVS=2222&cardType=Mastercard&name=Andrew White&address=1 Nowhere Close&postcode=CV1 1AA&country=GB&tel=024 7699 9999&fax=024 7699 9999&email=andyw@example.com"
  end

end