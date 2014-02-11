require 'test_helper'

class PayVectorNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @pay_vector = PayVector::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @pay_vector.complete?
    assert_equal "Completed", @pay_vector.status
    assert_equal "140210163630997302333235", @pay_vector.transaction_id
    assert_equal "13", @pay_vector.item_id
    assert_equal "10.00", @pay_vector.gross
    assert_equal "GBP", @pay_vector.currency
    assert_equal "2014-02-10 16:36:20 +00:00", @pay_vector.received_at
  end

  def test_compositions
    assert_equal Money.new(1000, 'GBP'), @pay_vector.amount
  end
  
  def test_extra_accessors
    assert_equal "AuthCode: 706534", @pay_vector.message
    assert_equal "VISA", @pay_vector.card_type
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement
    live_notification = PayVector::Notification.new(http_raw_data, :credential2 => 'testPassword', :credential3 => 'testPreSharedKey')
    assert live_notification.acknowledge
  end

  def test_respond_to_acknowledge
    assert @pay_vector.respond_to?(:acknowledge)
  end
  
  def test_payment_successful_status
    notification = PayVector::Notification.new('StatusCode=0')
    assert_equal 'Completed', notification.status
  end
  
  def test_payment_duplicate_status
    notification = PayVector::Notification.new('StatusCode=20&PreviousStatusCode=0')
    assert_equal 'Duplicate transaction', notification.status
  end
  
  def test_payment_cancelled_status
    notification = PayVector::Notification.new('StatusCode=5')
    assert_equal 'Failed', notification.status
  end

  private
  def http_raw_data
    "HashDigest=acec47a0aa94c02d2eadd0be5af09925c25501f6&MerchantID=IRCDev-1517551&StatusCode=0&Message=AuthCode%3A+706534&PreviousStatusCode=&PreviousMessage=&CrossReference=140210163630997302333235&Amount=1000&CurrencyCode=826&OrderID=13&TransactionType=SALE&TransactionDateTime=2014-02-10+16%3A36%3A20+%2B00%3A00&OrderDescription=ActiveMerchant+Order+13&CustomerName=Walter+White&Address1=32&Address2=&Address3=&Address4=&City=a&State=a&PostCode=148&AddressNumericCheckResult=PASSED&PostCodeCheckResult=PASSED&CV2CheckResult=PASSED&ThreeDSecureAuthenticationCheckResult=NOT_ENROLLED&CardType=VISA&CardClass=PERSONAL&CardIssuer=Credit+Industriel+et+Commercial&CardIssuerCountryCode=250&EmailAddress=walter.white%40example.com&PhoneNumber=&CountryCode=826"  
  end
end
