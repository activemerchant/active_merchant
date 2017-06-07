require 'test_helper'

class PayzaNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @payza = Payza::Notification.new(http_raw_data)
  end

  def test_acknowledgement
    Payza::Notification.any_instance.stubs(:ssl_post).returns('some')
    assert @payza.acknowledge

    Payza::Notification.any_instance.stubs(:ssl_post).returns('INVALID TOKEN')
    assert !@payza.acknowledge
  end

  def test_send_acknowledgement
    Payza::Notification.any_instance.expects(:ssl_post).with(
      Payza.notification_confirmation_url,
      http_raw_data,
      {'Content-Length' => "#{http_raw_data.size}", 'User-Agent' => "Active Merchant -- http://activemerchant.org"}
    ).returns('some')

    assert @payza.acknowledge
  end

  def test_acknowledgement_populate_params_with_result
    Payza::Notification.any_instance.stubs(:ssl_post).returns(ipn_response)

    @payza.acknowledge

    assert @payza.complete?
    assert_equal "Success", @payza.status
    assert_equal "13AD5-2WD40-5UE7B", @payza.transaction_id
    assert_equal "SU1", @payza.item_id
    assert_equal "42.40", @payza.gross
    assert_equal "USD", @payza.currency
    assert_equal "2013-11-12 08:51:31", @payza.received_at
    assert @payza.test?
  end

  #  You must do an URL-encoding with the token string before sending us the string back.

  private

  def http_raw_data
    "token=abcde"
  end

  def ipn_response
    "ap_merchant%3Downer%40mystore.com%26ap_custfirstname%3DJohn%26ap_custlastname%3DSmith%26ap_custaddress%3D5200+De+La+Savane%26ap_custcity%3DMontreal%26ap_custstate%3DQC%26ap_custcountry%3DCAN%26ap_custzip%3DH0H0H0%26ap_custemailaddress%3Djohnsmith%40email.com%26apc_1%3Dred%26apc_2%3D%26apc_3%3D%26apc_4%3D%26apc_5%3D%26apc_6%3D%26ap_test%3D1%26ap_purchasetype%3Ditem-goods%26ap_referencenumber%3D13AD5-2WD40-5UE7B%26ap_amount%3D40.00%26ap_quantity%3D1%26ap_currency%3DUSD%26ap_description%3DLorem+Ipsum%26ap_itemcode%3DSU1%26ap_itemname%3DShoes%26ap_shippingcharges%3D2.40%26ap_additionalcharges%3D0.00%26ap_taxamount%3D0.00%26ap_discountamount%3D0.00%26ap_totalamount%3D42.40%26ap_feeamount%3D1.25%26ap_netamount%3D41.15%26ap_status%3DSuccess%26ap_transactiondate%3D2013-11-12%2008:51:31"
  end
end
