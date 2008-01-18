require File.dirname(__FILE__) + '/../../test_helper'

class SkipJackTest < Test::Unit::TestCase

  def setup
    Base.mode = :test

    @gateway = SkipJackGateway.new(:login => 'X', :password => 'Y')

    @creditcard = credit_card('4242424242424242')

    @billing_address = { 
      :address1 => '123 Any St.',
      :address2 => 'Apt. B',
      :city => 'Anytown',
      :state => 'ST',
      :country => 'US',
      :zip => '51511-1234',
      :phone => '616-555-1212',
      :fax => '616-555-2121'
    }

    @shipping_address = { 
      :name => 'Stew Packman',
      :address1 => 'Company',
      :address2 => '321 No RD',
      :city => 'Nowhereton',
      :state => 'ZC',
      :country => 'MX',
      :phone => '0123231212'
    }
    
    @options = {
      :order_id => 1,
      :email => 'cody@example.com'
    }
  end

  def teardown
    Base.gateway_mode = :test
  end
  
  def test_authorization_success    
    @creditcard.number = 1

    assert response = @gateway.authorize(100, @creditcard, @options)
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_equal true, response.success?
  end

  def test_authorization_error
    @creditcard.number = 2

    assert response = @gateway.authorize(100, @creditcard, @options)
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_equal false, response.success?

  end
  
  def test_purchase_success
    @gateway.expects(:ssl_post).times(2).returns(successful_authorization_response, successful_capture_response)

    assert response = @gateway.purchase(100, @creditcard, @options)
    assert_success response
    assert_equal "9802853155172.022", response.authorization
  end

  def test_split_line
    keys = @gateway.send(:split_line, '"AUTHCODE","szSerialNumber","szTransactionAmount","szAuthorizationDeclinedMessage","szAVSResponseCode","szAVSResponseMessage","szOrderNumber","szAuthorizationResponseCode","szIsApproved","szCVV2ResponseCode","szCVV2ResponseMessage","szReturnCode","szTransactionFileName","szCAVVResponseCode"')
  
    values = @gateway.send(:split_line, '"000067","999888777666","1900","","N","Card authorized, exact address match with 5 digit zipcode.","1","000067","1","","","1","10138083786558.009",""')
  
    assert_equal keys.size, values.size
  
    keyvals = keys.zip(values).flatten
    map = Hash[*keyvals]
  
    assert_equal '000067', map['AUTHCODE']
  end
  
  def test_turn_authorizeapi_response_into_hash
    body = <<-EOS
"AUTHCODE","szSerialNumber","szTransactionAmount","szAuthorizationDeclinedMessage","szAVSResponseCode","szAVSResponseMessage","szOrderNumber","szAuthorizationResponseCode","szIsApproved","szCVV2ResponseCode","szCVV2ResponseMessage","szReturnCode","szTransactionFileName","szCAVVResponseCode"
"000067","999888777666","1900","","N","Card authorized, exact address match with 5 digit zipcode.","1","000067","1","","","1","10138083786558.009",""
    EOS
  
    map = @gateway.send(:authorize_response_map, body)
  
    assert_equal 14, map.keys.size
    assert_equal '10138083786558.009', map[:szTransactionFileName]
  end
  
  private
  def successful_authorization_response
    <<-CSV
"AUTHCODE","szSerialNumber","szTransactionAmount","szAuthorizationDeclinedMessage","szAVSResponseCode","szAVSResponseMessage","szOrderNumber","szAuthorizationResponseCode","szIsApproved","szCVV2ResponseCode","szCVV2ResponseMessage","szReturnCode","szTransactionFileName","szCAVVResponseCode"
"TAS204","000386891209","100","","Y","Card authorized, exact address match with 5 digit zip code.","107a0fdb21ba42cf04f60274908085ea","TAS204","1","M","Match","1","9802853155172.022",""
    CSV
  end
  
  def successful_capture_response
    <<-CSV
"000386891209","0","1","","","","","","","","","" 
"000386891209","1.0000","SETTLE","SUCCESSFUL","Valid","618844630c5fad658e95abfd5e1d4e22","9802853156029.022"
    CSV
  end
end
