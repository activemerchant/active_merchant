require 'test_helper'

class PaystationTest < Test::Unit::TestCase
  def setup
    
    @gateway = PaystationGateway.new(
                 :paystation_id => 'some_id_number',
                 :gateway_id    => 'another_id_number'
               )

    @credit_card = credit_card
    @amount = 100
    
    @options = { 
      :order_id => '1',
      :customer => 'Joe Bloggs, Customer ID #56',
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    
    assert_equal '0008813023-01', response.authorization
    
    assert_equal 'Store Purchase', response.params["merchant_reference"]
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)
    
    assert response = @gateway.store(@credit_card, @options.merge(:token => "justatest1310263135"))
    assert_success response
    assert response.test?
    
    assert_equal "justatest1310263135", response.token
  end
  
  def test_successful_purchase_from_token
    @gateway.expects(:ssl_post).returns(successful_stored_purchase_response)
  
    token = "u09fxli14afpnd6022x0z82317beqe9e2w048l9it8286k6lpvz9x27hdal9bl95"
  
    assert response = @gateway.purchase(@amount, token, @options)
    assert_success response
    
    assert_equal '0009062149-01', response.authorization
    
    assert_equal 'Store Purchase', response.params["merchant_reference"]
    assert response.test?
  end
  
  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    assert response = @gateway.authorize(@successful_amount, @credit_card, @options)
    assert_success response
    
    assert response.authorization
  end
  
  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    
    assert response = @gateway.capture(@successful_amount, "0009062250-01", @options.merge(:credit_card_verification => 123))
    assert_success response
  end

  private
  
    def successful_purchase_response
      %(<?xml version="1.0" standalone="yes"?>
      <response>
      <ec>0</ec>
      <em>Transaction successful</em>
      <ti>0006713018-01</ti>
      <ct>mastercard</ct>
      <merchant_ref>Store Purchase</merchant_ref>
      <tm>T</tm>
      <MerchantSession>1</MerchantSession>
      <UsedAcquirerMerchantID>123456</UsedAcquirerMerchantID>
      <TransactionID>0008813023-01</TransactionID>
      <PurchaseAmount>10000</PurchaseAmount>
      <Locale/>
      <ReturnReceiptNumber>8813023</ReturnReceiptNumber>
      <ShoppingTransactionNumber/>
      <AcqResponseCode>00</AcqResponseCode>
      <QSIResponseCode>0</QSIResponseCode>
      <CSCResultCode/>
      <AVSResultCode/>
      <TransactionTime>2011-06-22 00:05:52</TransactionTime>
      <PaystationErrorCode>0</PaystationErrorCode>
      <PaystationErrorMessage>Transaction successful</PaystationErrorMessage>
      <MerchantReference>Store Purchase</MerchantReference>
      <TransactionMode>T</TransactionMode>
      <BatchNumber>0622</BatchNumber>
      <AuthorizeID/>
      <Cardtype>MC</Cardtype>
      <Username>12345</Username>
      <RequestIP>192.168.0.1</RequestIP>
      <RequestUserAgent/>
      <RequestHttpReferrer/>
      <PaymentRequestTime>2011-06-22 00:05:52</PaymentRequestTime>
      <DigitalOrderTime/>
      <DigitalReceiptTime>2011-06-22 00:05:52</DigitalReceiptTime>
      <PaystationTransactionID>0008813023-01</PaystationTransactionID>
      <IssuerName>unknown</IssuerName>
      <IssuerCountry>unknown</IssuerCountry>
      </response>)
    end
  
    def failed_purchase_response
      %(<?xml version="1.0" standalone="yes"?>
      <response>
      <ec>5</ec>
      <em>Insufficient Funds</em>
      <ti>0006713018-01</ti>
      <ct>mastercard</ct>
      <merchant_ref>Store Purchase</merchant_ref>
      <tm>T</tm>
      <MerchantSession>1</MerchantSession>
      <UsedAcquirerMerchantID>123456</UsedAcquirerMerchantID>
      <TransactionID>0008813018-01</TransactionID>
      <PurchaseAmount>10051</PurchaseAmount>
      <Locale/>
      <ReturnReceiptNumber>8813018</ReturnReceiptNumber>
      <ShoppingTransactionNumber/>
      <AcqResponseCode>51</AcqResponseCode>
      <QSIResponseCode>5</QSIResponseCode>
      <CSCResultCode/>
      <AVSResultCode/>
      <TransactionTime>2011-06-22 00:05:46</TransactionTime>
      <PaystationErrorCode>5</PaystationErrorCode>
      <PaystationErrorMessage>Insufficient Funds</PaystationErrorMessage>
      <MerchantReference>Store Purchase</MerchantReference>
      <TransactionMode>T</TransactionMode>
      <BatchNumber>0622</BatchNumber>
      <AuthorizeID/>
      <Cardtype>MC</Cardtype>
      <Username>123456</Username>
      <RequestIP>192.168.0.1</RequestIP>
      <RequestUserAgent/>
      <RequestHttpReferrer/>
      <PaymentRequestTime>2011-06-22 00:05:46</PaymentRequestTime>
      <DigitalOrderTime/>
      <DigitalReceiptTime>2011-06-22 00:05:46</DigitalReceiptTime>
      <PaystationTransactionID>0008813018-01</PaystationTransactionID>
      <IssuerName>unknown</IssuerName>
      <IssuerCountry>unknown</IssuerCountry>
      </response>)
    end
    
    def successful_store_response
      %(<?xml version="1.0" standalone="yes"?>
      <PaystationFuturePaymentResponse>
      <ec>34</ec>
      <em>Future Payment Saved Ok</em>
      <ti/>
      <ct/>
      <merchant_ref>Store Purchase</merchant_ref>
      <tm>T</tm>
      <MerchantSession>3e48fa9a6b0fe36177adf7269db7a3c4</MerchantSession>
      <UsedAcquirerMerchantID/>
      <TransactionID/>
      <PurchaseAmount>0</PurchaseAmount>
      <Locale/>
      <ReturnReceiptNumber/>
      <ShoppingTransactionNumber/>
      <AcqResponseCode/>
      <QSIResponseCode/>
      <CSCResultCode/>
      <AVSResultCode/>
      <TransactionTime>2011-07-10 13:58:55</TransactionTime>
      <PaystationErrorCode>34</PaystationErrorCode>
      <PaystationErrorMessage>Future Payment Saved Ok</PaystationErrorMessage>
      <MerchantReference>Store Purchase</MerchantReference>
      <TransactionMode>T</TransactionMode>
      <BatchNumber/>
      <AuthorizeID/>
      <Cardtype/>
      <Username>123456</Username>
      <RequestIP>192.168.0.1</RequestIP>
      <RequestUserAgent/>
      <RequestHttpReferrer/>
      <PaymentRequestTime>2011-07-10 13:58:55</PaymentRequestTime>
      <DigitalOrderTime/>
      <DigitalReceiptTime>2011-07-10 13:58:55</DigitalReceiptTime>
      <PaystationTransactionID>0009062177-01</PaystationTransactionID>
      <FuturePaymentToken>justatest1310263135</FuturePaymentToken>
      <IssuerName>unknown</IssuerName>
      <IssuerCountry>unknown</IssuerCountry>
      </PaystationFuturePaymentResponse>)
    end
    
    def successful_stored_purchase_response
      %(<?xml version="1.0" standalone="yes"?>
      <PaystationFuturePaymentResponse>
      <ec>0</ec>
      <em>Transaction successful</em>
      <ti>0006713018-01</ti>
      <ct>visa</ct>
      <merchant_ref>Store Purchase</merchant_ref>
      <tm>T</tm>
      <MerchantSession>0fc70a577f19ae63f651f53c7044640a</MerchantSession>
      <UsedAcquirerMerchantID>123456</UsedAcquirerMerchantID>
      <TransactionID>0009062149-01</TransactionID>
      <PurchaseAmount>10000</PurchaseAmount>
      <Locale/>
      <ReturnReceiptNumber>9062149</ReturnReceiptNumber>
      <ShoppingTransactionNumber/>
      <AcqResponseCode>00</AcqResponseCode>
      <QSIResponseCode>0</QSIResponseCode>
      <CSCResultCode/>
      <AVSResultCode/>
      <TransactionTime>2011-07-10 13:55:00</TransactionTime>
      <PaystationErrorCode>0</PaystationErrorCode>
      <PaystationErrorMessage>Transaction successful</PaystationErrorMessage>
      <MerchantReference>Store Purchase</MerchantReference>
      <TransactionMode>T</TransactionMode>
      <BatchNumber>0710</BatchNumber>
      <AuthorizeID/>
      <Cardtype>VC</Cardtype>
      <Username>123456</Username>
      <RequestIP>192.168.0.1</RequestIP>
      <RequestUserAgent/>
      <RequestHttpReferrer/>
      <PaymentRequestTime>2011-07-10 13:55:00</PaymentRequestTime>
      <DigitalOrderTime/>
      <DigitalReceiptTime>2011-07-10 13:55:00</DigitalReceiptTime>
      <PaystationTransactionID>0009062149-01</PaystationTransactionID>
      <FuturePaymentToken>u09fxli14afpnd6022x0z82317beqe9e2w048l9it8286k6lpvz9x27hdal9bl95</FuturePaymentToken>
      <IssuerName>unknown</IssuerName>
      <IssuerCountry>unknown</IssuerCountry>
      </PaystationFuturePaymentResponse>)
    end
    
    def successful_authorization_response
      %(<?xml version="1.0" standalone="yes"?>
      <response>
      <ec>0</ec>
      <em>Transaction successful</em>
      <ti>0009062250-01</ti>
      <ct>visa</ct>
      <merchant_ref>Store Purchase</merchant_ref>
      <tm>T</tm>
      <MerchantSession>b2168af96076522466af4e3d61e5ba0c</MerchantSession>
      <UsedAcquirerMerchantID>123456</UsedAcquirerMerchantID>
      <TransactionID>0009062250-01</TransactionID>
      <PurchaseAmount>10000</PurchaseAmount>
      <Locale/>
      <ReturnReceiptNumber>9062250</ReturnReceiptNumber>
      <ShoppingTransactionNumber/>
      <AcqResponseCode>00</AcqResponseCode>
      <QSIResponseCode>0</QSIResponseCode>
      <CSCResultCode/>
      <AVSResultCode/>
      <TransactionTime>2011-07-10 14:11:00</TransactionTime>
      <PaystationErrorCode>0</PaystationErrorCode>
      <PaystationErrorMessage>Transaction successful</PaystationErrorMessage>
      <MerchantReference>Store Purchase</MerchantReference>
      <TransactionMode>T</TransactionMode>
      <BatchNumber>0710</BatchNumber>
      <AuthorizeID/>
      <Cardtype>VC</Cardtype>
      <Username>123456</Username>
      <RequestIP>192.168.0.1</RequestIP>
      <RequestUserAgent/>
      <RequestHttpReferrer/>
      <PaymentRequestTime>2011-07-10 14:11:00</PaymentRequestTime>
      <DigitalOrderTime/>
      <DigitalReceiptTime>2011-07-10 14:11:00</DigitalReceiptTime>
      <PaystationTransactionID>0009062250-01</PaystationTransactionID>
      <IssuerName>unknown</IssuerName>
      <IssuerCountry>unknown</IssuerCountry>
      </response>)
    end
    
    def successful_capture_response
      %(<?xml version="1.0" standalone="yes"?>
      <PaystationCaptureResponse>
      <ec>0</ec>
      <em>Transaction successful</em>
      <ti>0009062289-01</ti>
      <ct/>
      <merchant_ref>Store Purchase</merchant_ref>
      <tm>T</tm>
      <MerchantSession>485fdedc81dc83848dd799cd10a869db</MerchantSession>
      <UsedAcquirerMerchantID>123456</UsedAcquirerMerchantID>
      <TransactionID>0009062289-01</TransactionID>
      <CaptureAmount>10000</CaptureAmount>
      <Locale/>
      <ReturnReceiptNumber>9062289</ReturnReceiptNumber>
      <ShoppingTransactionNumber/>
      <AcqResponseCode>00</AcqResponseCode>
      <QSIResponseCode>0</QSIResponseCode>
      <CSCResultCode/>
      <AVSResultCode/>
      <TransactionTime>2011-07-10 14:17:36</TransactionTime>
      <PaystationErrorCode>0</PaystationErrorCode>
      <PaystationErrorMessage>Transaction successful</PaystationErrorMessage>
      <MerchantReference>Store Purchase</MerchantReference>
      <TransactionMode>T</TransactionMode>
      <BatchNumber>0710</BatchNumber>
      <AuthorizeID/>
      <Cardtype/>
      <Username>123456</Username>
      <RequestIP>192.168.0.1</RequestIP>
      <RequestUserAgent/>
      <RequestHttpReferrer/>
      <PaymentRequestTime>2011-07-10 14:17:36</PaymentRequestTime>
      <DigitalOrderTime>2011-07-10 14:17:36</DigitalOrderTime>
      <DigitalReceiptTime>2011-07-10 14:17:36</DigitalReceiptTime>
      <PaystationTransactionID/>
      <RefundedAmount/>
      <CapturedAmount>10000</CapturedAmount>
      <AuthorisedAmount/>
      </PaystationCaptureResponse>)
    end
end
