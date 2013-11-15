require 'test_helper'

class PayuInReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @payu = PayuIn::Return.new(http_raw_data_success, :credential1 => 'merchant_id', :credential2 => 'secret')
  end

  def setup_failed_return
    @payu = PayuIn::Return.new(http_raw_data_failure, :credential1 => 'merchant_id', :credential2 => 'secret')
  end

  def test_success
    assert @payu.success?
    assert_equal 'Completed', @payu.status('4ba4afe87f7e73468f2a','10.00')
  end

  def test_failure_is_successful
    setup_failed_return
    assert_equal 'Failed', @payu.status('8ae1034d1abf47fde1cf', '10.00')
  end

  def test_treat_initial_failures_as_pending
    setup_failed_return
    assert_equal 'Failed', @payu.notification.status
  end

  def test_return_has_notification
    notification = @payu.notification

    assert notification.complete?
    assert_equal 'Completed', notification.status
    assert notification.invoice_ok?('4ba4afe87f7e73468f2a')
    assert notification.amount_ok?(BigDecimal.new('10.00'),BigDecimal.new('0.00'))
    assert_equal "success", notification.transaction_status
    assert_equal '403993715508030204', @payu.notification.transaction_id
    assert_equal 'CC', @payu.notification.type
    assert_equal 'INR', notification.currency
    assert_equal '4ba4afe87f7e73468f2a', notification.invoice
    assert_equal 'merchant_id', notification.account
    assert_equal '10.00', notification.gross
    assert_equal '0.00', notification.discount
    assert_equal nil, notification.offer_description
    assert_equal 'Product Info', notification.product_info
    assert_equal 'test@example.com', notification.customer_email
    assert_equal '1234567890', notification.customer_phone
    assert_equal 'Payu-Admin', notification.customer_first_name
    assert_equal '', notification.customer_last_name
    assert_equal ["", "", "", "", "", "", "", "", "", ""], notification.user_defined
    assert_equal checksum, notification.checksum
    assert_equal 'E000', notification.message
    assert notification.checksum_ok?
  end

  private

  def http_raw_data_success
    "mihpayid=403993715508030204&mode=CC&status=success&unmappedstatus=captured&key=merchant_id&txnid=4ba4afe87f7e73468f2a&amount=10.00&discount=0.00&addedon=2013-05-10 18 32 30&productinfo=Product Info&firstname=Payu-Admin&lastname=&address1=&address2=&city=&state=&country=&zipcode=&email=test@example.com&phone=1234567890&udf1=&udf2=&udf3=&udf4=&udf5=&udf6=&udf7=&udf8=&udf9=&udf10=&hash=#{checksum}&field1=313069903923&field2=999999&field3=59117331831301&field4=-1&field5=&field6=&field7=&field8=&PG_TYPE=HDFC&bank_ref_num=59117331831301&bankcode=CC&error=E000&cardnum=512345XXXXXX2346&cardhash=766f0227cc4b4c5f773a04cb31d8d1c5be071dd8d08fe365ecf5e2e5c947546d"
  end

  def http_raw_data_failure
    "mihpayid=403993715508030204&mode=CC&status=failure&unmappedstatus=failed&key=merchant_id&txnid=8ae1034d1abf47fde1cf&amount=10.00&discount=0.00&addedon=2013-05-13 11:09:20&productinfo=Product Info&firstname=Payu-Admin&lastname=&address1=&address2=&city=&state=&country=&zipcode=&email=test@example.com&phone=1234567890&udf1=&udf2=&udf3=&udf4=&udf5=&udf6=&udf7=&udf8=&udf9=&udf10=&hash=65774f82abe64cec54be31107529b2a3eef8f6a3f97a8cb81e9769f4394b890b0e7171f8988c4df3684e7f9f337035d0fe09a844da4b76e68dd643e8ac5e5c63&field1=&field2=&field3=&field4=&field5=!ERROR!-GV00103-Invalid BrandError Code: GV00103&field6=&field7=&field8=failed in enrollment&PG_TYPE=HDFC&bank_ref_num=&bankcode=CC&error=E201&cardnum=411111XXXXXX1111&cardhash=49c73d6c44f27f7ac71b439de842f91e27fcbc3b9ce9dfbcbf1ce9a8fe790c17"
  end

  def checksum
    Digest::SHA512.hexdigest("secret|success|||||||||||test@example.com|Payu-Admin|Product Info|10.00|4ba4afe87f7e73468f2a|merchant_id")
  end

end
