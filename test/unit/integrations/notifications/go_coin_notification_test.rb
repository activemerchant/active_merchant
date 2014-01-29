require 'test_helper'

class GoCoinNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @go_coin = GoCoin::Notification.new(http_raw_notify_data)
  end

  def test_accessors
    assert @go_coin.complete?
    assert_equal "ready_to_ship", @go_coin.status
    assert_equal "b9879d2b-052f-4a0a-8a3f-3e72049e4d19", @go_coin.transaction_id
    assert_equal "050b550a-1f4d-4c1e-a0b7-7d9a27e44c4a", @go_coin.item_id
    assert_equal "31.66", @go_coin.gross.to_s
    assert_equal "USD", @go_coin.currency
    assert_equal "2014-01-24 00:26:39 UTC", @go_coin.received_at.to_s
    assert_equal BigDecimal.new("0.00012350", 8), @go_coin.crypto_gross
    assert_equal "BTC", @go_coin.crypto_currency
  end

  def test_compositions
    assert_equal Money.new(3166, 'USD'), @go_coin.amount
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement
    Net::HTTP.any_instance.expects(:request).returns(stub(:body => invoice_data.to_json))
    assert @go_coin.acknowledge
  end

  def test_send_acknowledgement
    Net::HTTP.any_instance.expects(:request).returns(stub(:body => '{"no" : "match"'))
    assert !@go_coin.acknowledge
  end

  def test_respond_to_acknowledge
    Net::HTTP.any_instance.expects(:request).returns(stub(:body => '{invalid json'))
    assert !@go_coin.acknowledge
  end

  private

  # This is the data actually provided to the callback (a superset of the Invoice data in the payload)
  def http_raw_notify_data
    {
      "id"=>"b9879d2b-052f-4a0a-8a3f-3e72049e4d19", 
      "event"=>"invoice_paid", 
      "payload"=> invoice_data
    }.to_json
  end

  # This hash (converted to JSON) is what the acknowledge HTTP read invoice returns
  def invoice_data
    {
      "id"=>"050b550a-1f4d-4c1e-a0b7-7d9a27e44c4a", 
      "status"=>"ready_to_ship", 
      "payment_address"=>"bitcoin_public_address", 
      "price"=>"0.00012350", 
      "price_currency"=>"BTC", 
      "base_price"=>"31.66", 
      "base_price_currency"=>"USD", 
      "spot_rate"=>"0.00123504", 
      "usd_spot_rate"=>"1.0", 
      "crypto_payout_split"=>80, 
      "confirmations_required"=>6, 
      "notification_level"=>nil, 
      "redirect_url"=>"http://test_redirect_url.com", 
      "order_id"=>"237", 
      "item_name"=>nil, 
      "item_sku"=>nil, 
      "item_description"=>nil, 
      "physical"=>nil, 
      "customer_name"=>"Customer Name", 
      "customer_address_1"=>nil, 
      "customer_address_2"=>nil, 
      "customer_city"=>nil, 
      "customer_region"=>nil, 
      "customer_country"=>nil, 
      "customer_postal_code"=>nil, 
      "customer_email"=>nil, 
      "customer_phone"=>nil, 
      "user_defined_1"=>nil, 
      "user_defined_2"=>nil, 
      "user_defined_3"=>nil, 
      "user_defined_4"=>nil, 
      "user_defined_5"=>nil, 
      "user_defined_6"=>nil, 
      "user_defined_7"=>nil, 
      "user_defined_8"=>nil, 
      "data"=>nil, 
      "expires_at"=>"2014-01-24T00:01:03.602Z", 
      "created_at"=>"2014-01-23T23:46:03.997Z", 
      "updated_at"=>"2014-01-23T23:49:40.777Z", 
      "server_time"=>"2014-01-24T00:26:39Z", 
      "callback_url"=>"test_redirect_url.com/notify/237", 
      "merchant_id"=>"d91c8756-5174-4388-b4e0-8c3593529a32"
    }
  end

end
