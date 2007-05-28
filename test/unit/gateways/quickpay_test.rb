require File.dirname(__FILE__) + '/../../test_helper'

class QuickpayTest < Test::Unit::TestCase
  # 100 Cents
  AMOUNT = 100

  def setup
    @gateway = QuickpayGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @creditcard = CreditCard.new(
      :number => '4242424242424242',
      :month => 8,
      :year => 2008,
      :first_name => 'Longbob',
      :last_name => 'Longsen'
    )
  end
  
  def test_successful_purchase
    @creditcard.number = 1
    assert response = @gateway.purchase(AMOUNT, @creditcard, {})
    assert response.success?
    assert_equal '5555', response.authorization
    assert response.test?
  end
  
  def test_successful_authorization
    @creditcard.number = 1
    assert response = @gateway.authorize(AMOUNT, @creditcard, {})
    assert response.success?
    assert_equal '5555', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @creditcard.number = 2
    assert response = @gateway.purchase(AMOUNT, @creditcard, {})
    assert !response.success?
    assert response.test?
  end

  def test_request_error
    @creditcard.number = 3
    assert_raise(Error){ @gateway.purchase(AMOUNT, @creditcard, {}) }
  end
  
  def test_parsing_response_with_errors
    @gateway.expects(:ssl_post).returns(error_response)
    
    response = @gateway.purchase(AMOUNT, @creditcard, :order_id => '1000')
    assert !response.success?
    assert_equal '008', response.params['qpstat']
    assert_equal 'Missing/error in cardnumberMissing/error in expirationdateMissing/error in card verification dataMissing/error in amountMissing/error in ordernumMissing/error in currency', response.params['qpstatmsg']
    assert_equal 'Missing/error in cardnumber, Missing/error in expirationdate, Missing/error in card verification data, Missing/error in amount, Missing/error in ordernum, and Missing/error in currency', response.message
  end
  
  def test_merchant_error
    @gateway.expects(:ssl_post).returns(merchant_error)
    
    response = @gateway.purchase(AMOUNT, @creditcard, :order_id => '1000')
    assert !response.success?
    assert_equal response.message, 'Missing/error in merchant'
  end
  
  def test_parsing_successful_response
    @gateway.expects(:ssl_post).returns(successful_response)
    
    response = @gateway.authorize(AMOUNT, @creditcard, :order_id => '1000')

    assert response.success?
    assert_equal 'OK', response.message
    
    assert_equal '2865261', response.authorization
    assert_equal '000', response.params['qpstat']
    assert_equal '000', response.params['pbsstat']
    assert_equal '2865261', response.params['transaction']
    assert_equal '070425223705', response.params['time']
    assert_equal '104680', response.params['ordernum']
    assert_equal 'cody@example.com', response.params['merchantemail']
    assert_equal 'Visa', response.params['cardtype']
    assert_equal AMOUNT.to_s, response.params['amount']
    assert_equal 'OK', response.params['qpstatmsg']
    assert_equal 'Shopify', response.params['merchant']
    assert_equal '1110', response.params['msgtype']
    assert_equal 'USD', response.params['currency']
  end
  
  def test_supported_countries
    assert_equal ['DK'], QuickpayGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal  [ :dankort, :forbrugsforeningen, :visa, :master, :american_express, :diners_club, :jcb, :maestro ], QuickpayGateway.supported_cardtypes
  end
  
  
  private
  
  def error_response
    <<-XML
<?xml version='1.0' encoding='ISO-8859-1'?>

<values qpstat='008' qpstatmsg='Missing/error in cardnumberMissing/error in expirationdateMissing/error in card verification dataMissing/error in amountMissing/error in ordernumMissing/error in currency'/>
    XML
  end
  
  def merchant_error
    <<-XML
<?xml version='1.0' encoding='ISO-8859-1'?>

<values qpstat='008' qpstatmsg='Missing/error in merchant'/>
    XML
  end
  
  def successful_response
    <<-XML
<?xml version='1.0' encoding='ISO-8859-1'?>

<values qpstat='000' transaction='2865261' time='070425223705' ordernum='104680' merchantemail='cody@example.com' pbsstat='000' cardtype='Visa' amount='100' qpstatmsg='OK' merchant='Shopify' msgtype='1110' currency='USD'/>
    XML
  end
end
