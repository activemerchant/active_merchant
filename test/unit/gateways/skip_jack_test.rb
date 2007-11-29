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
  
  def test_purchase_success    
    @creditcard.number = 1

    assert response = @gateway.authorize(100, @creditcard, @options)
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_equal true, response.success?
  end

  def test_purchase_error
    @creditcard.number = 2

    assert response = @gateway.authorize(100, @creditcard, @options)
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_equal false, response.success?

  end
  
  def test_purchase_exceptions
    @creditcard.number = 3 
    
    assert_raise(Error) do
      assert response = @gateway.authorize(100, @creditcard, @options)    
    end
  end

  def test_split_line
    keys = @gateway.send(:split_line, '"AUTHCODE","szSerialNumber","szTransactionAmount","szAuthorizationDeclinedMessage","szAVSResponseCode","szAVSResponseMessage","szOrderNumber","szAuthorizationResponseCode","szIsApproved","szCVV2ResponseCode","szCVV2ResponseMessage","szReturnCode","szTransactionFileName","szCAVVResponseCode"')
  
    values = @gateway.send(:split_line, '"000067","999888777666","1900","","N","Card authorized, exact address match with 5 digit zipcode.","1","000067","1","","","1","10138083786558.009",""')
  
    assert_equal keys.size, values.size
  
    keyvals = keys.zip(values).flatten
    map = Hash[*keyvals]
  
    assert_equal '000067', map['AUTHCODE']
  end
  
  #def test_turn_authorizeapi_response_into_hash
  #  body = <<-EOS
  # "AUTHCODE","szSerialNumber","szTransactionAmount","szAuthorizationDeclinedMessage","szAVSResponseCode","szAVSResponseMessage","szOrderNumber","szAuthorizationResponseCode","szIsApproved","szCVV2ResponseCode","szCVV2ResponseMessage","szReturnCode","szTransactionFileName","szCAVVResponseCode"
  # "000067","999888777666","1900","","N","Card authorized, exact address match with 5 digit zipcode.","1","000067","1","","","1","10138083786558.009",""
#EOS
  #
  #  map = @gateway.authorize_response_map body
  #
  #  assert_equal 14, map.keys.size
  #  assert_equal '10138083786558.009', map[:szTransactionFileName]
  #end
  #
  #def test_be_able_to_authorize_payment_successfully
  #  @creditcard.number = '1'
  #
  #  assert response = @gateway.authorize(2400, @creditcard,
  #                                       :order_id => 1,
  #                                       :description => 'design',
  #                                       :email => 'bob@foo.com',
  #                                       :billing_address => @billing_address,
  #                                       :shipping_address => @shipping_address,
  #                                       :order_items => [
  #                                                        { :ItemNumber => '123',
  #                                                          :ItemDescription => 'foo bar~item description',
  #                                                          :ItemCost => '21.00',
  #                                                          :Quantity => '10',
  #                                                          :Taxable => 'Y',
  #                                                          :TaxRate => '0.06'
  #                                                        },
  #                                                        { :ItemNumber => '321',
  #                                                          :ItemDescription => 'item 2',
  #                                                          :ItemCost => '11.00',
  #                                                          :Quantity => '1',
  #                                                          :Taxable => 'N'
  #                                                        }
  #                                                       ]
  #                                       )
  #  assert_equal Response, response.class
  #  assert_equal true, response.success?
  #
  #  params = response.params
  #
  #  assert_equal 'X', params['SerialNumber']
  #  assert_equal 'Y', params['DeveloperSerialNumber']
  #  assert_equal '1', params['OrderNumber']
  #  assert_equal '24.00', params['TransactionAmount']
  #  assert_equal 'design', params['OrderDescription']
  #  assert_equal @creditcard.number.to_s, params['AccountNumber']
  #  assert_equal @creditcard.month.to_s, params['Month']
  #  assert_equal @creditcard.year.to_s, params['Year']
  #  assert_equal @creditcard.verification_value.to_s, params['CVV2']
  #  assert_equal 'Longbob Longsen', params['SJName']
  #  assert_equal 'bob@foo.com', params['Email']
  #  assert_equal @billing_address[:address1], params['StreetAddress']
  #  assert_equal @billing_address[:address2], params['StreetAddress2']
  #  assert_equal @billing_address[:city], params['City']
  #  assert_equal @billing_address[:state], params['State']
  #  assert_equal @billing_address[:zip], params['ZipCode']
  #  assert_equal @billing_address[:country], params['Country']
  #  assert_equal @billing_address[:phone], params['Phone']
  #  assert_equal @billing_address[:fax], params['Fax']
  #  assert_equal 'Stew Packman', params['ShipToName']
  #  assert_equal @shipping_address[:address1], params['ShipToStreetAddress']
  #  assert_equal @shipping_address[:address2], params['ShipToStreetAddress2']
  #  assert_equal @shipping_address[:city], params['ShipToCity']
  #  assert_equal @shipping_address[:state], params['ShipToState']
  #  assert_equal '', params['ShipToZipCode']
  #  assert_equal @shipping_address[:country], params['ShipToCountry']
  #  assert_equal @shipping_address[:phone], params['ShipToPhone']
  #  assert_equal '', params['ShipToFax']
  #  assert_equal '123~foo bar-item description~21.00~10~Y~~~~~~~~0.06~||321~item 2~11.00~1~N~~~~~~~~~||', params['OrderString']
  #end
  #
  #def test_be_able_to_get_status_of_previous_transaction
  #  assert response = @gateway.status(:order_id => 12)
  #
  #  assert_equal Response, response.class
  #  assert_equal true, response.success?, 'did not get success'
  #
  #  params = response.params
  #
  #  assert_equal 'X', params['szSerialNumber']
  #  assert_equal 'Y', params['szDeveloperSerialNumber']
  #  assert_equal '12', params['szOrderNumber']
  #end
  #
  #def test_be_able_to_capture_money_from_a_previous_authorization
  #  assert response = @gateway.capture(2400, '123.321',
  #                                     :order_id => 12)
  #
  #  assert_equal Response, response.class
  #  assert_equal true, response.success?, 'did not get success'
  #
  #  params = response.params
  #
  #  assert_equal 'X', params['szSerialNumber']
  #  assert_equal 'Y', params['szDeveloperSerialNumber']
  #  assert_equal 'SETTLE', params['szDesiredStatus']
  #  assert_equal nil, params['szAmount']
  #  assert_equal '123.321', params['szTransactionId']
  #  assert_equal '12', params['szOrderNumber']
  #end
  #
  #def test_be_able_to_void_a_transaction
  #  assert response = @gateway.void('123.321', :order_id => 12)
  #
  #  assert_equal Response, response.class
  #  assert_equal true, response.success?, 'did not get success'
  #
  #  params = response.params
  #
  #  assert_equal 'X', params['szSerialNumber']
  #  assert_equal 'Y', params['szDeveloperSerialNumber']
  #  assert_equal 'DELETE', params['szDesiredStatus']
  #  assert_equal '123.321', params['szTransactionId']
  #  assert_equal '12', params['szOrderNumber']
  #end
  #
  #def test_be_able_to_credit_a_card
  #  assert response = @gateway.credit(2400, '123.321',
  #                                    :order_id => 12)
  #
  #  assert_equal Response, response.class
  #  assert_equal true, response.success?, 'did not get success'
  #
  #  params = response.params
  #
  #  assert_equal 'X', params['szSerialNumber']
  #  assert_equal 'Y', params['szDeveloperSerialNumber']
  #  assert_equal 'CREDIT', params['szDesiredStatus']
  #  assert_equal '24.00', params['szAmount']
  #  assert_equal '123.321', params['szTransactionId']
  #  assert_equal '12', params['szOrderNumber']
  #end
  
  private
  def successful_authorization_response
    <<-CSV
"AUTHCODE","szSerialNumber","szTransactionAmount","szAuthorizationDeclinedMessage","szAVSResponseCode","szAVSResponseMessage","szOrderNumber","szAuthorizationResponseCode","szIsApproved","szCVV2ResponseCode","szCVV2ResponseMessage","szReturnCode","szTransactionFileName","szCAVVResponseCode"
"TAS204","000386891209","100","","Y","Card authorized, exact address match with 5 digit zip code.","107a0fdb21ba42cf04f60274908085ea","TAS204","1","M","Match","1","9802853155172.022",""
    CSV
  end
end
