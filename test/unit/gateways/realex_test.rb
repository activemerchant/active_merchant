require File.dirname(__FILE__) + '/../../test_helper'
require 'digest/sha1'

class RealexTest < Test::Unit::TestCase
  AMOUNT = 100

  def setup
    @login = 'your_merchant_id'
    @password = 'your_secret'
  
    @gateway = RealexGateway.new(
      :login => @merchant_id,
      :password => @secret,
      :account => ''
    )

    @gateway_with_account = RealexGateway.new(
      :login => @merchant_id,
      :password => @secret,
      :account => 'bill_web_cengal'
    )
    
    @creditcard = CreditCard.new(
      :number => '4263971921001307',
      :month => 8,
      :year => 2008,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :type => 'visa'
    )
  end
  
  
  def test_in_test
    assert_equal :test, ActiveMerchant::Billing::Base.gateway_mode
  end  
  
  def test_hash
    result =  Digest::SHA1.hexdigest("20061213105925.your_merchant_id.1.400.EUR.4263971921001307")
    assert_equal "6bbce4d13f8e830401db4ee530eecb060bc50f64", result
    
    #add the secret to the end
    result = Digest::SHA1.hexdigest(result + "." + @password)
    assert_equal "06a8b619cbd76024676401e5a83e7e5453521af3", result
  end
  
  
  def test_successful_request
    @creditcard.number = 1
    assert response = @gateway.purchase(AMOUNT, @creditcard, :order_id => 1)
    assert response.success?
    assert_equal '5555', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @creditcard.number = 2
    assert response = @gateway.purchase(AMOUNT, @creditcard, :order_id => 1)
    assert !response.success?
    assert response.test?
  end

  def test_request_error
    @creditcard.number = 3
    assert_raise(Error){ @gateway.purchase(AMOUNT, @creditcard, :order_id => 1) }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_response)
    
    response = @gateway.purchase(AMOUNT, @creditcard, :order_id => 1)
    assert response.success?
  end
  
  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(unsuccessful_response)
    
    response = @gateway.purchase(AMOUNT, @creditcard, :order_id => 1)
    assert !response.success?
  end
  
  def test_supported_countries
    assert_equal ['IE', 'GB'], RealexGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [ :visa, :master, :american_express, :diners_club, :switch, :solo, :laser ], RealexGateway.supported_cardtypes
  end
  
  
  private
  
  def successful_response
    <<-RESPONSE
<response timestamp='20010427043422'>
  <merchantid>your merchant id</merchantid>
  <account>account to use</account>
  <orderid>order id from request</orderid>
  <authcode>authcode received</authcode>
  <result>00</result>
  <message>[ test system ] message returned from system</message>
  <pasref> realex payments reference</pasref>
  <cvnresult>M</cvnresult>
  <batchid>batch id for this transaction (if any)</batchid>
  <cardissuer>
    <bank>Issuing Bank Name</bank>
    <country>Issuing Bank Country</country>
    <countrycode>Issuing Bank Country Code</countrycode>
    <region>Issuing Bank Region</region>
  </cardissuer>
  <tss>
    <result>89</result>
    <check id="1000">9</check>
    <check id="1001">9</check>
  </tss>
  <sha1hash>7384ae67....ac7d7d</sha1hash>
  <md5hash>34e7....a77d</md5hash>
</response>"
    RESPONSE
  end
  
  def unsuccessful_response
    <<-RESPONSE
<response timestamp='20010427043422'>
  <merchantid>your merchant id</merchantid>
  <account>account to use</account>
  <orderid>order id from request</orderid>
  <authcode>authcode received</authcode>
  <result>01</result>
  <message>message returned from system</message>
  <pasref> realex payments reference</pasref>
  <cvnresult>M</cvnresult>
  <batchid>batch id for this transaction (if any)</batchid>
  <cardissuer>
    <bank>Issuing Bank Name</bank>
    <country>Issuing Bank Country</country>
    <countrycode>Issuing Bank Country Code</countrycode>
    <region>Issuing Bank Region</region>
  </cardissuer>
  <tss>
    <result>89</result>
    <check id="1000">9</check>
    <check id="1001">9</check>
  </tss>
  <sha1hash>7384ae67....ac7d7d</sha1hash>
  <md5hash>34e7....a77d</md5hash>
</response>"
    RESPONSE
  end
end