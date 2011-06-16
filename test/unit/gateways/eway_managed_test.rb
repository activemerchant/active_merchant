require 'test_helper'

class EwayManagedTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test

    @gateway = EwayManagedGateway.new(:username => 'username', :login => 'login', :password => 'password')

    @valid_card='4444333322221111'
    @valid_customer_id='9876543211000'
    
    @credit_card = credit_card(@valid_card)
    @declined_card = credit_card('4444111111111111')

    @amount = 100

    @options = { :billing_address => { 
                  :address1 => '1234 My Street',
                  :address2 => 'Apt 1',
                  :company => 'Widgets Inc',
                  :city => 'Ottawa',
                  :state => 'ON',
                  :zip => 'K1C2N6',
                  :country => 'au',
                  :title => 'Mr.',
                  :phone => '(555)555-5555'
               },
               :email => 'someguy1232@fakeemail.net',
               :order_id => '1000'
    }
  end

  def test_should_require_billing_address_on_store
    assert_raise ArgumentError do
      @gateway.store(@credit_card, { })
    end
    assert_raise ArgumentError do
      @gateway.store(@credit_card, { :billing_address => {} })
    end
    assert_raise ArgumentError do
      @gateway.store(@credit_card, { :billing_address => { :title => 'Mr.' } })
    end
    assert_raise ArgumentError do
      @gateway.store(@credit_card, { :billing_address => { :country => 'au' } })
    end
    assert_nothing_raised do
      @gateway.expects(:ssl_post).returns(successful_store_response)
      @gateway.store(@credit_card, { :billing_address => { :title => 'Mr.', :country => 'au' } })
    end
  end

  def test_should_require_billing_address_on_update
    assert_raise ArgumentError do
      @gateway.update(@valid_customer_id, @credit_card, { })
    end
    assert_raise ArgumentError do
      @gateway.update(@valid_customer_id, @credit_card, { :billing_address => {} })
    end
    assert_raise ArgumentError do
      @gateway.update(@valid_customer_id, @credit_card, { :billing_address => { :title => 'Mr.' } })
    end
    assert_raise ArgumentError do
      @gateway.update(@valid_customer_id, @credit_card, { :billing_address => { :country => 'au' } })
    end
    assert_nothing_raised do
      @gateway.expects(:ssl_post).returns(successful_update_response)
      @gateway.update(@valid_customer_id, @credit_card, { :billing_address => { :title => 'Mr.', :country => 'au' } })
    end
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @valid_customer_id, @options)
    assert_instance_of EwayManagedGateway::EwayResponse, response
    assert_equal "00,Transaction Approved(Test Gateway)", response.message
    assert_success response
    assert_equal "123456", response.authorization
    assert response.test?
  end

  def test_invalid_customer_id
    @gateway.expects(:ssl_post).returns(unsuccessful_authorization_response)

    assert response = @gateway.purchase(@amount, '1', @options)
    assert_instance_of EwayManagedGateway::EwayResponse, response
    assert_failure response
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_instance_of EwayManagedGateway::EwayResponse, response
    assert_equal "OK", response.message
    assert_success response
    assert_equal "1234567", response.token
    assert response.test?
  end

  def test_sucessful_update
    @gateway.expects(:ssl_post).returns(successful_update_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_instance_of EwayManagedGateway::EwayResponse, response
    assert_equal "OK", response.message
    assert_success response
    assert response.test?
  end

  def test_default_currency
    assert_equal 'AUD', EwayManagedGateway.default_currency
  end
  
  private
  
  def successful_purchase_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Body>
    <ProcessPaymentResponse xmlns="https://www.eway.com.au/gateway/managedpayment">
      <ewayResponse>
        <ewayTrxnError>00,Transaction Approved(Test Gateway)</ewayTrxnError>
        <ewayTrxnStatus>True</ewayTrxnStatus>
        <ewayTrxnNumber>123456</ewayTrxnNumber>
        <ewayReturnAmount>100</ewayReturnAmount>
        <ewayAuthCode>123456</ewayAuthCode>
      </ewayResponse>
    </ProcessPaymentResponse>
  </soap12:Body>
</soap12:Envelope>
    XML
  end

  def unsuccessful_authorization_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><soap:Fault><soap:Code><soap:Value>soap:Sender</soap:Value></soap:Code><soap:Reason><soap:Text xml:lang="en">Login failed</soap:Text></soap:Reason><soap:Detail /></soap:Fault></soap:Body></soap:Envelope>
    XML
  end

  def successful_store_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Body>
    <CreateCustomerResponse xmlns="https://www.eway.com.au/gateway/managedpayment">
      <CreateCustomerResult>1234567</CreateCustomerResult>
    </CreateCustomerResponse>
  </soap12:Body>
</soap12:Envelope>
    XML
  end

  def successful_update_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Body>
    <UpdateCustomerResponse xmlns="https://www.eway.com.au/gateway/managedpayment">
      <UpdateCustomerResult>true</UpdateCustomerResult>
    </UpdateCustomerResponse>
  </soap12:Body>
</soap12:Envelope>
    XML
  end

end
