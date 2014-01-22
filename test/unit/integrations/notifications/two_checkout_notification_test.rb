require 'test_helper'

class TwoCheckoutNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @live_notification = TwoCheckout::Notification.new(live_http_raw_data)
  end

  def test_accessors
    assert @live_notification.complete?
    assert_equal 'FRAUD_STATUS_CHANGED', @live_notification.type
    assert_equal "Completed", @live_notification.status
    assert_equal "4742525399", @live_notification.transaction_id
    assert_equal "4759791636", @live_notification.invoice_id
    assert_equal "test123", @live_notification.item_id
    assert_equal "0.20", @live_notification.gross
    assert_equal "USD", @live_notification.currency
    assert_equal "2013-07-19 17:01:19", @live_notification.received_at
    assert_equal 'noreply@2co.com', @live_notification.payer_email
  end

  def test_compositions
    assert_equal Money.new(20, 'USD'), @live_notification.amount
  end

  def test_acknowledgement
    live_notification = TwoCheckout::Notification.new(live_http_raw_data, :credential2 => 'tango')
    assert live_notification.acknowledge
  end


  private
  def live_http_raw_data
    "auth_exp=2012-07-26&bill_city=Columbus&bill_country=USA&bill_postal_code=43123&bill_state=OH&bill_street_address=123+Test+St&bill_street_address2=dddsdsc&cust_currency=USD&customer_email=noreply@2co.com&customer_first_name=Craig&customer_ip=76.181.175.91&customer_ip_country=United+States&customer_last_name=Christenson&customer_name=Craig+P+Christenson&customer_phone=5555555555&fraud_status=pass&invoice_cust_amount=0.20&invoice_id=4759791636&invoice_list_amount=0.20&invoice_status=deposited&invoice_usd_amount=0.20&item_count=2&item_cust_amount_1=0.10&item_cust_amount_2=0.10&item_duration_1=&item_duration_2=&item_id_1=ebook1&item_id_2=ebook1&item_list_amount_1=0.10&item_list_amount_2=0.10&item_name_1=Download&item_name_2=Download&item_rec_date_next_1=2012-07-26&item_rec_date_next_2=2012-07-26&item_rec_install_billed_1=4&item_rec_install_billed_2=4&item_rec_list_amount_1=0.10&item_rec_list_amount_2=0.10&item_rec_status_1=live&item_rec_status_2=live&item_recurrence_1=1+Week&item_recurrence_2=1+Week&item_type_1=bill&item_type_2=bill&item_usd_amount_1=0.10&item_usd_amount_2=0.10&key_count=68&list_currency=USD&md5_hash=2DAE8544FA29CE313DB20582D540F133&message_description=Fraud+status+changed&message_id=3786&message_type=FRAUD_STATUS_CHANGED&payment_type=paypal+ec&recurring=1&sale_date_placed=2012-06-28+22:14:23&sale_id=4742525399&ship_city=Columbus&ship_country=USA&ship_name=Craig+Christenson&ship_postal_code=43228&ship_state=OH&ship_status=&ship_street_address=123+Test+st&ship_street_address2=&ship_tracking_number=&timestamp=2013-07-19+17:01:19&vendor_id=532001&vendor_order_id=test123"
  end
end
