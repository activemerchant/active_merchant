require 'test_helper'

class SoEasyPayTest < Test::Unit::TestCase
  def setup
    @gateway = SoEasyPayGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '1708978', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '1708979', response.authorization
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal('1708980', response.authorization)
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert response = @gateway.capture(1111, "1708980")
    assert_instance_of Response, response
    assert_success response

    assert_equal('1708981', response.authorization)
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_credit_response)
    assert response = @gateway.refund(@amount, '1708978')
    assert_instance_of Response, response
    assert_success response
    assert_equal 'Transaction successful', response.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_credit_response)

    assert response = @gateway.refund(@amount, '1708978')
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Card declined', response.message
  end

  def test_do_not_depend_on_expiry_date_class
    @gateway.stubs(:ssl_post).returns(successful_purchase_response)
    @credit_card.expects(:expiry_date).never

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_use_ducktyping_for_credit_card
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    credit_card = stub(:number => '4242424242424242', :verification_value => '123', :name => "Hans Tester", :year => 2012, :month => 1)

    assert_nothing_raised do
      assert_success @gateway.purchase(@amount, credit_card, @options)
    end
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    %(<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:tns="urn:Interface" xmlns:types="urn:Interface/encodedTypes" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <tns:SaleTransactionResponse>
            <return href="#id1" />
          </tns:SaleTransactionResponse>
          <tns:SaleTransactionResponse id="id1" xsi:type="tns:SaleTransactionResponse">
            <transactionID xsi:type="xsd:string">1708978</transactionID>
            <orderID xsi:type="xsd:string">12</orderID>
            <status xsi:type="xsd:string">Authorized</status>
            <errorcode xsi:type="xsd:string">000</errorcode>
            <errormessage xsi:type="xsd:string">Transaction successful</errormessage>
            <AVSResult xsi:type="xsd:string">K</AVSResult>
            <FSResult xsi:type="xsd:string">NOSCORE</FSResult>
            <FSStatus xsi:type="xsd:string">0000</FSStatus>
            <cardNumberSuffix xsi:type="xsd:string">**21</cardNumberSuffix>
            <cardExpiryDate xsi:type="xsd:string">02/16</cardExpiryDate>
            <cardType xsi:type="xsd:string">VISA</cardType>
          </tns:SaleTransactionResponse>
        </soap:Body>
      </soap:Envelope>)
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    %(<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:tns="urn:Interface" xmlns:types="urn:Interface/encodedTypes" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <tns:SaleTransactionResponse>
            <return href="#id1" />
          </tns:SaleTransactionResponse>
          <tns:SaleTransactionResponse id="id1" xsi:type="tns:SaleTransactionResponse">
            <transactionID xsi:type="xsd:string">1708979</transactionID>
            <orderID xsi:type="xsd:string">12</orderID>
            <status xsi:type="xsd:string">Not Authorized</status>
            <errorcode xsi:type="xsd:string">002</errorcode>
            <errormessage xsi:type="xsd:string">Card declined</errormessage>
            <AVSResult xsi:type="xsd:string">K</AVSResult>
            <FSResult xsi:type="xsd:string">NOSCORE</FSResult>
            <FSStatus xsi:type="xsd:string">0000</FSStatus>
            <cardNumberSuffix xsi:type="xsd:string">**21</cardNumberSuffix>
            <cardExpiryDate xsi:type="xsd:string">02/16</cardExpiryDate>
            <cardType xsi:type="xsd:string">VISA</cardType>
          </tns:SaleTransactionResponse>
        </soap:Body>
      </soap:Envelope>)
  end

  def successful_authorize_response
    %(<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:tns="urn:Interface" xmlns:types="urn:Interface/encodedTypes" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <tns:AuthorizeTransactionResponse>
            <return href="#id1" />
          </tns:AuthorizeTransactionResponse>
          <tns:AuthorizeTransactionResponse id="id1" xsi:type="tns:AuthorizeTransactionResponse">
            <transactionID xsi:type="xsd:string">1708980</transactionID>
            <orderID xsi:type="xsd:string">12</orderID>
            <status xsi:type="xsd:string">Authorized</status>
            <errorcode xsi:type="xsd:string">000</errorcode>
            <errormessage xsi:type="xsd:string">Transaction successful</errormessage>
            <AVSResult xsi:type="xsd:string">K</AVSResult>
            <FSResult xsi:type="xsd:string">NOSCORE</FSResult>
            <FSStatus xsi:type="xsd:string">0000</FSStatus>
            <cardNumberSuffix xsi:type="xsd:string">**21</cardNumberSuffix>
            <cardExpiryDate xsi:type="xsd:string">02/16</cardExpiryDate>
            <cardType xsi:type="xsd:string">VISA</cardType>
          </tns:AuthorizeTransactionResponse>
        </soap:Body>
      </soap:Envelope>)
  end

  def successful_capture_response
    %(<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:tns="urn:Interface" xmlns:types="urn:Interface/encodedTypes" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <tns:CaptureTransactionResponse>
            <return href="#id1" />
          </tns:CaptureTransactionResponse>
          <tns:CaptureTransactionResponse id="id1" xsi:type="tns:CaptureTransactionResponse">
            <transactionID xsi:type="xsd:string">1708981</transactionID>
            <status xsi:type="xsd:string">Authorized</status>
            <errorcode xsi:type="xsd:string">000</errorcode>
            <errormessage xsi:type="xsd:string">Transaction successful</errormessage>
          </tns:CaptureTransactionResponse>
        </soap:Body>
      </soap:Envelope>)
  end

  def successful_credit_response
    %(<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:tns="urn:Interface" xmlns:types="urn:Interface/encodedTypes" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <tns:RefundTransactionResponse>
            <return href="#id1" />
          </tns:RefundTransactionResponse>
          <tns:RefundTransactionResponse id="id1" xsi:type="tns:RefundTransactionResponse">
            <transactionID xsi:type="xsd:string">1708982</transactionID>
            <status xsi:type="xsd:string">Authorized</status>
            <errorcode xsi:type="xsd:string">000</errorcode>
            <errormessage xsi:type="xsd:string">Transaction successful</errormessage>
          </tns:RefundTransactionResponse>
        </soap:Body>
      </soap:Envelope>)
  end

  def failed_credit_response
    %(<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:tns="urn:Interface" xmlns:types="urn:Interface/encodedTypes" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <tns:RefundTransactionResponse>
            <return href="#id1" />
          </tns:RefundTransactionResponse>
          <tns:RefundTransactionResponse id="id1" xsi:type="tns:RefundTransactionResponse">
            <transactionID xsi:type="xsd:string">1708983</transactionID>
            <status xsi:type="xsd:string">Not Authorized</status>
            <errorcode xsi:type="xsd:string">002</errorcode>
            <errormessage xsi:type="xsd:string">Card declined</errormessage>
          </tns:RefundTransactionResponse>
        </soap:Body>
      </soap:Envelope>)
  end

end

