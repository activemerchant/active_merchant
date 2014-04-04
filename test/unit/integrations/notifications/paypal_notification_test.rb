require 'test_helper'

class PaypalNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @paypal = Paypal::Notification.new(http_raw_data)
    @mass_pay_paypal = Paypal::Notification.new(mass_pay_http_raw_data)
  end

  def test_accessors
    assert @paypal.complete?
    assert !@paypal.masspay?
    assert_equal "Completed", @paypal.status
    assert_equal "6G996328CK404320L", @paypal.transaction_id
    assert_equal "web_accept", @paypal.type
    assert_equal "500.00", @paypal.gross
    assert_equal "15.05", @paypal.fee
    assert_equal "CAD", @paypal.currency
    assert_equal 'tobi@leetsoft.com' , @paypal.account
    assert @paypal.test?
  end

  def test_mass_pay_accessors
    assert @mass_pay_paypal.complete?
    assert @mass_pay_paypal.masspay?
    assert_equal "Completed", @mass_pay_paypal.status
    assert_equal "masspay", @mass_pay_paypal.type
    assert_equal nil, @mass_pay_paypal.transaction_id
    assert_equal nil, @mass_pay_paypal.gross
    assert_equal nil, @mass_pay_paypal.fee
    assert_equal nil, @mass_pay_paypal.currency
    assert_equal nil , @mass_pay_paypal.account
    assert_equal 3 , @mass_pay_paypal.items.size
    assert_equal "7XW35917TG8293137", @mass_pay_paypal.items[0].transaction_id
    assert_equal "79512417EL9296629", @mass_pay_paypal.items[1].transaction_id
    assert_equal "75X24749Y32677910", @mass_pay_paypal.items[2].transaction_id
    assert_equal "10.00", @mass_pay_paypal.items[0].gross
    assert_equal "24.50", @mass_pay_paypal.items[1].gross
    assert_equal "20.00", @mass_pay_paypal.items[2].gross
    assert_equal "0.20", @mass_pay_paypal.items[0].fee
    assert_equal "0.49", @mass_pay_paypal.items[1].fee
    assert_equal "0.40", @mass_pay_paypal.items[2].fee
    assert_equal "GBP", @mass_pay_paypal.items[0].currency
    assert_equal "GBP", @mass_pay_paypal.items[1].currency
    assert_equal "GBP", @mass_pay_paypal.items[2].currency
    assert_equal "123", @mass_pay_paypal.items[0].item_id
    assert_equal "456", @mass_pay_paypal.items[1].item_id
    assert_equal "789", @mass_pay_paypal.items[2].item_id
    assert_equal "buyer_1348066306_per@example.com", @mass_pay_paypal.items[0].account
    assert_equal "buyer_1351170859_per@example.com", @mass_pay_paypal.items[1].account
    assert_equal "buyer_1351170993_per@example.com", @mass_pay_paypal.items[2].account
    assert_equal "Completed", @mass_pay_paypal.items[0].status
    assert_equal "Completed", @mass_pay_paypal.items[1].status
    assert_equal "Completed", @mass_pay_paypal.items[2].status
    assert @mass_pay_paypal.test?
  end

  def test_compositions
    assert_equal Money.new(50000, 'CAD'), @paypal.amount
  end

  def test_acknowledgement
    Paypal::Notification.any_instance.stubs(:ssl_post).returns('VERIFIED')
    assert @paypal.acknowledge

    Paypal::Notification.any_instance.stubs(:ssl_post).returns('INVALID')
    assert !@paypal.acknowledge
  end

  def test_send_acknowledgement
    Paypal::Notification.any_instance.expects(:ssl_post).with(
      "#{Paypal.service_url}?cmd=_notify-validate",
      http_raw_data,
      { 'Content-Length' => "#{http_raw_data.size}", 'User-Agent' => "Active Merchant -- http://activemerchant.org" }
    ).returns('VERIFIED')

    assert @paypal.acknowledge
  end

  def test_payment_successful_status
    notification = Paypal::Notification.new('payment_status=Completed')
    assert_equal 'Completed', notification.status
  end

  def test_payment_pending_status
    notification = Paypal::Notification.new('payment_status=Pending')
    assert_equal 'Pending', notification.status
  end

  def test_payment_failure_status
    notification = Paypal::Notification.new('payment_status=Failed')
    assert_equal 'Failed', notification.status
  end

  def test_respond_to_acknowledge
    assert @paypal.respond_to?(:acknowledge)
  end

  def test_item_id_mapping
    notification = Paypal::Notification.new('item_number=1')
    assert_equal '1', notification.item_id
  end

  def test_custom_mapped_to_item_id
    notification = Paypal::Notification.new('custom=1')
    assert_equal '1', notification.item_id
  end

  def test_nil_notification
    Paypal::Notification.any_instance.stubs(:ssl_post).returns('INVALID')
    assert !@paypal.acknowledge
  end

  def test_received_at_time_parsing
    assert_match %r{15/04/2005 22:23:54 (UTC|GMT)}, @paypal.received_at.strftime("%d/%m/%Y %H:%M:%S %Z")

    paypal = Paypal::Notification.new("payment_date=14%3A07%3A35+Apr+09%2C+2014+PDT")
    assert_match %r{09/04/2014 21:07:35 (UTC|GMT)}, paypal.received_at.strftime("%d/%m/%Y %H:%M:%S %Z")

    paypal = Paypal::Notification.new("payment_date=16%3A30%3A42+Feb+28%2C+2014+PST")
    assert_match %r{01/03/2014 00:30:42 (UTC|GMT)}, paypal.received_at.strftime("%d/%m/%Y %H:%M:%S %Z")
  end

  private

  def http_raw_data
    "mc_gross=500.00&address_status=confirmed&payer_id=EVMXCLDZJV77Q&tax=0.00&address_street=164+Waverley+Street&payment_date=15%3A23%3A54+Apr+15%2C+2005+PDT&payment_status=Completed&address_zip=K2P0V6&first_name=Tobias&mc_fee=15.05&address_country_code=CA&address_name=Tobias+Luetke&notify_version=1.7&custom=&payer_status=unverified&business=tobi%40leetsoft.com&address_country=Canada&address_city=Ottawa&quantity=1&payer_email=tobi%40snowdevil.ca&verify_sign=AEt48rmhLYtkZ9VzOGAtwL7rTGxUAoLNsuf7UewmX7UGvcyC3wfUmzJP&txn_id=6G996328CK404320L&payment_type=instant&last_name=Luetke&address_state=Ontario&receiver_email=tobi%40leetsoft.com&payment_fee=&receiver_id=UQ8PDYXJZQD9Y&txn_type=web_accept&item_name=Store+Purchase&mc_currency=CAD&item_number=&test_ipn=1&payment_gross=&shipping=0.00"
  end

  def mass_pay_http_raw_data
    "payer_id=LPV4F4HZHCE&payment_date=06%3A25%3A37+Oct+25%2C+2012+PDT&payment_gross_1=&payment_gross_2=&payment_gross_3=&payment_status=Completed&receiver_email_1=buyer_1348066306_per%40example.com&receiver_email_2=buyer_1351170859_per%40example.com&charset=windows-1252&receiver_email_3=buyer_1351170993_per%40example.com&mc_currency_1=GBP&masspay_txn_id_1=7XW35917TG8293137&mc_currency_2=GBP&masspay_txn_id_2=79512417EL9296629&mc_currency_3=GBP&masspay_txn_id_3=75X24749Y32677910&first_name=Test&unique_id_1=123&notify_version=3.7&unique_id_2=456&unique_id_3=789&payer_status=verified&verify_sign=AwtKW.5QSiJCrI10IE.2gmVei1MEAwsHLftLIB9pXgu82MLXoCS1yeE-&payer_email=massuk_1351170591_biz%40example.com&payer_business_name=Tests%27s+Test+Store&last_name=Test&status_1=Completed&status_2=Completed&status_3=Completed&txn_type=masspay&mc_gross_1=10.00&mc_gross_2=24.50&mc_gross_3=20.00&payment_fee_1=&residence_country=GB&test_ipn=1&payment_fee_2=&payment_fee_3=&mc_fee_1=0.20&mc_fee_2=0.49&mc_fee_3=0.40&ipn_track_id=89f7ff244947f"
  end
end
