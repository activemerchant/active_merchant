require 'test_helper'

class PayuInNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @payu = PayuIn::Notification.new(http_raw_data, :credential1 => 'C0Dr8m', :credential2 => '3sf0jURk')
  end

  def test_accessors
    assert @payu.complete?
    assert_equal "Completed", @payu.status
    assert_equal "403993715508030204", @payu.transaction_id
    assert_equal "success", @payu.transaction_status
    assert_equal "10.00", @payu.gross
    assert_equal "Product Info", @payu.product_info
    assert_equal "INR", @payu.currency
    assert_equal true, @payu.invoice_ok?('4ba4afe87f7e73468f2a')
    assert_equal true, @payu.amount_ok?(BigDecimal.new('10.00'),BigDecimal.new('0.00'))
    assert_equal "CC", @payu.type
    assert_equal "4ba4afe87f7e73468f2a", @payu.invoice
    assert_equal "C0Dr8m", @payu.account
    assert_equal "0.00", @payu.discount
    assert_equal "test@example.com", @payu.customer_email
    assert_equal "1234567890", @payu.customer_phone
    assert_equal "Payu-Admin", @payu.customer_first_name
    assert_equal "", @payu.customer_last_name
    assert_equal "ef0c1b509a42b802a4938c25dc9bb9efe40b75a7dfb8bde1a6f126fa1f86cee264c5e5a17e87db85150d6d8912eafda838416e669712f1989dcb9cbdb8c24219", @payu.checksum
    assert_equal "E000", @payu.message
    assert_equal true, @payu.checksum_ok?
  end

  def test_compositions
    assert_equal '10.00', @payu.gross
  end

  def test_acknowledgement
    assert @payu.acknowledge
  end

  def test_respond_to_acknowledge
    assert @payu.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
   "mihpayid=403993715508030204&mode=CC&status=success&unmappedstatus=captured&key=C0Dr8m&txnid=4ba4afe87f7e73468f2a&amount=10.00&discount=0.00&addedon=2013-05-10 18 32 30&productinfo=Product Info&firstname=Payu-Admin&lastname=&address1=&address2=&city=&state=&country=&zipcode=&email=test@example.com&phone=1234567890&udf1=&udf2=&udf3=&udf4=&udf5=&udf6=&udf7=&udf8=&udf9=&udf10=&hash=ef0c1b509a42b802a4938c25dc9bb9efe40b75a7dfb8bde1a6f126fa1f86cee264c5e5a17e87db85150d6d8912eafda838416e669712f1989dcb9cbdb8c24219&field1=313069903923&field2=999999&field3=59117331831301&field4=-1&field5=&field6=&field7=&field8=&PG_TYPE=HDFC&bank_ref_num=59117331831301&bankcode=CC&error=E000&cardnum=512345XXXXXX2346&cardhash=766f0227cc4b4c5f773a04cb31d8d1c5be071dd8d08fe365ecf5e2e5c947546d"
  end
end
