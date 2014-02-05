require 'test_helper'
require 'mocha/setup'
class VeritransNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @veritrans = Veritrans::Notification.new(http_raw_data, :merchant_id => 'T1000000000000000000', :merchant_has_key=> 'asdhjada-dasdahsvd-adasds')
    @veritrans.stubs(:acknowledge_response).returns(acknowledge_response)
  end

  def test_accessors

    assert_equal "success", @veritrans.status
    assert_equal "dummysMhZmkVgspGMxmpj2Lkc4OJJT", @veritrans.transaction_id
    assert_equal "xR1qtkbg65xJAfY2Le3dbuc4ThsX4mw", @veritrans.item_id
    assert_equal "200000.00", @veritrans.gross
    assert_equal "IDR", @veritrans.currency
    assert_equal "2013-03-22T12:59:38+07:00", @veritrans.received_at
    assert_equal true, @veritrans.test?
  end

  def test_compositions
    back = Money.default_currency
    assert_equal Money.new(20000000, 'IDR'), @veritrans.amount
  end

  def test_send_acknowledgement
    auth_header = {'Authorization' => 'Basic ' + ["T1000000000000000000:asdhjada-dasdahsvd-adasds"].pack('m').delete("\r\n")}
    json_post = "{\"mStatus\":\"Success\",\"orderId\":\"#{acknowledge_response["order_id"]}\"}"
    Veritrans::Notification.any_instance.expects(:ssl_post).with(
      "#{Veritrans.acknowledge_url}",
      {:notification => JSON.parse(json_post)}.to_query, auth_header).returns(acknowledge_response.to_json
    )
    notification =Veritrans::Notification.new(json_post, :merchant_id => 'T1000000000000000000', :merchant_hash_key =>"asdhjada-dasdahsvd-adasds")
    notification.stubs(:acknowledge_response).returns(acknowledge_response)
    assert notification.acknowledge
  end

  def test_payment_successful_status
    notification =Veritrans::Notification.new('{"mStatus":"Success"}')
    assert_equal 'success', notification.status
  end

  def test_payment_pending_status
    notification = Veritrans::Notification.new('{"mStatus":"Pending"}')
    assert_equal 'pending', notification.status
  end

  def test_payment_failure_status
    notification = Veritrans::Notification.new('{"mStatus":"Failure"}')
    assert_equal 'failure', notification.status
  end

  def test_item_id_mapping
    notification = Veritrans::Notification.new('{"TOKEN_MERCHANT":"1"}')
    assert_equal '1', notification.item_id
  end

  def test_respond_to_acknowledge
    assert @veritrans.respond_to?(:acknowledge)
  end

  private
  def acknowledge_response
    {"merchant_id"            => "T1000000000000000000",
    "order_id"                => "dummysMhZmkVgspGMxmpj2Lkc4OJJT",
    "total_amount"            => "200000",
    "latest_status"           => "Authorize",
    "customer_email"          => "test@veritrans.co.id",
    "customer_name"           => "John Doe",
    "customer_phone"          => "088888888888888",
    "payment_type"            => "card",
    "credit_card_no"          => "444441*41",
    "security_recommendation" => "ACCEPT",
    "payment_status"          => "sucess",
    "approval_code"           => "xxxxxxxx",
    "v_result_code"           => "xxxxxxxx",
    "received_at"             => "2013-03-22T12:59:38+07:00",
    "acknowledge"             => "verified"
  }
  end
  def http_raw_data
    # Postalcode = 12345
    # mStatus = Succes
    # emai = test@veritrans.co.id
    # address = 52 The Street,Village Town,London,United Kingdom
    # name = Doe John
    # vResultCode = C001000000000000
    # shippingAddress = Roppongi1-6-1,Minatoku,Tokyo,Japan
    # orderId = dummysMhZmkVgspGMxmpj2Lkc4OJJT
    # shippingPostalCode = 1606028
    # ShippingName = TARO YAMADA
    # TOKEN_MERCHANT = xR1qtkbg65xJAfY2Le3dbuc4ThsX4mw
    {
      "Postalcode" => "12345",
      "ShippingName" => "TARO YAMADA",
      "TOKEN_MERCHANT"=> "xR1qtkbg65xJAfY2Le3dbuc4ThsX4mw",
      "address"=> "52 The Street,Village Town,London,United Kingdom",
      "email"=> "test@veritrans.co.id",
      "mStatus"=> "Success",
      "name"=> "Doe John",
      "orderId"=> "dummysMhZmkVgspGMxmpj2Lkc4OJJT",
      "shippingAddress"=> "Roppongi1-6-1,Minatoku,Tokyo,Japan",
      "shippingPostalCode"=> "1606028",
      "vResultCode"=> "C001000000000000"
    }.to_json
  end
end
