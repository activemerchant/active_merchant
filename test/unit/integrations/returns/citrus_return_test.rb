require 'test_helper'

class CitrusReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @citrus = Citrus::Return.new(http_raw_data_success, :credential2 => '2c71a4ea7d2b88e151e60d9da38b2d4552568ba9')
  end

  def setup_failed_return
    @citrus = Citrus::Return.new(http_raw_data_canceled, :credential2 => '2c71a4ea7d2b88e151e60d9da38b2d4552568ba9')
  end

  def setup_tampered_return
    @citrus = Citrus::Return.new(http_raw_data_tampered, :credential2 => '2c71a4ea7d2b88e151e60d9da38b2d4552568ba9')
  end

  def test_success
    assert @citrus.success?
    assert_equal 'Completed', @citrus.status('ORD427','10.00')
  end

  def test_failure_is_successful
    setup_failed_return
    assert_equal 'Cancelled', @citrus.status('ORD483', '10.00')
  end

  def test_tampered_is_successful
    setup_tampered_return
    assert_equal 'Tampered', @citrus.status('ORD427', '100.00')
  end

  def test_treat_initial_failures_as_pending
    setup_failed_return
    assert_equal 'Cancelled', @citrus.notification.status
    assert @citrus.cancelled?
  end

  def test_return_has_notification
    notification = @citrus.notification

    assert notification.complete?

    assert_equal "Completed", notification.status
    assert_equal "CTX1309180549472058821", notification.transaction_id
    assert_equal "SUCCESS", notification.transaction_status
    assert_equal "10.00", notification.amount
    assert_equal "INR", notification.currency
    assert_equal true, notification.invoice_ok?('ORD427')
    assert_equal true, notification.amount_ok?(BigDecimal.new('10.00'))
    assert_equal "CASH_ON_DELIVERY", notification.paymentmode
    assert_equal "ORD427", notification.invoice
    assert_equal "807bb30a30a02b904f1434539f2eb07942ecb6f1", notification.checksum
    assert_equal "Cash on delivery requested", notification.message
    assert_equal true, notification.checksum_ok?
  end

  private

  def http_raw_data_success
	  "TxGateway=&TxId=ORD427&TxMsg=Cash+on+delivery+requested&TxRefNo=CTX1309180549472058821&TxStatus=SUCCESS&action=callback&addressCity=Kolkata&addressCountry=India&addressState=West+Bengal&addressStreet1=122+sksdlk+sdjf&addressStreet2=&addressZip=9292929292&amount=10.00&authIdCode=&controller=test&currency=INR&email=sujoy.goswami%40gmail.com&firstName=Amit&isCOD=true&issuerRefNo=&lastName=Pandey&mobileNo=929292929&paymentMode=CASH_ON_DELIVERY&pgRespCode=0&pgTxnNo=CTX1309180549472058821&signature=807bb30a30a02b904f1434539f2eb07942ecb6f1&transactionId=40689"
  end

  def http_raw_data_canceled
  	"TxGateway=&TxId=ORD483&TxMsg=Canceled+by+user&TxRefNo=CTX1309180556554473079&TxStatus=CANCELED&action=callback&addressCity=Kolkata&addressCountry=India&addressState=West+Bengal&addressStreet1=22+sks+ksks&addressStreet2=&addressZip=782828282&amount=10.00&authIdCode=&controller=test&currency=INR&email=sujoy.goswami%40gmail.com&firstName=Amit&isCOD=&issuerRefNo=&lastName=Pandey&mobileNo=928282828&paymentMode=&pgRespCode=3&pgTxnNo=CTX1309180556554473079&signature=ea298e6cd6a92fba4b6f62f754fb98905ae7a3a3&transactionId=40693"
  end

  def http_raw_data_tampered
   "TxGateway=&TxId=ORD427&TxMsg=Cash+on+delivery+requested&TxRefNo=CTX1309180549472058821&TxStatus=SUCCESS&action=callback&addressCity=Kolkata&addressCountry=India&addressState=West+Bengal&addressStreet1=122+sksdlk+sdjf&addressStreet2=&addressZip=9292929292&amount=100.00&authIdCode=&controller=test&currency=USD&email=sujoy.goswami%40gmail.com&firstName=Amit&isCOD=true&issuerRefNo=&lastName=Pandey&mobileNo=929292929&paymentMode=CASH_ON_DELIVERY&pgRespCode=0&pgTxnNo=CTX1309180549472058821&signature=807bb30a30a02b904f1434539f2eb07942ecb6f1&transactionId=40689"
  end

end
