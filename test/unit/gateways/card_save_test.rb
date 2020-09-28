require 'test_helper'

class CardSaveTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    @gateway = CardSaveGateway.new(:login => 'login', :password => 'password')
    @credit_card = credit_card
    @amount = 100
    @options = {:order_id =>'1', :billing_address => address, :description =>'Store Purchase'}
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_visa_no_3d_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '1;110706093540191601939772;939772', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(declined_switch_no_3d_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_nil response.authorization
    assert response.test?
  end

  def test_referred_request_is_a_failure
    @gateway.expects(:ssl_post).returns(referred_mastercard_no_3d_secure_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_nil response.authorization
    assert response.test?
  end

  def test_unsupported_card_currency_combination_is_a_failure
    @gateway.expects(:ssl_post).returns(failed_due_to_unsupported_card_currency_combination)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_nil response.authorization
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(authorization_successful)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal('1;110706124418747501702211;702211', response.authorization)
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(capture_successful)

    assert response = @gateway.capture(1111, "1;110706124418747501702211;702211")
    assert_success response
    assert_equal('110706124418747501702211', response.authorization)
    assert response.test?
  end

  def test_default_currency
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/CurrencyCode="826"/), anything).returns(successful_visa_no_3d_purchase_response)
    assert_success @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund)
    assert response = @gateway.refund(@amount, '123456789')
    assert_success response
    assert_equal 'Refund successful', response.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund)

    assert response = @gateway.refund(@amount, '123456789')
    assert_failure response
    assert_equal 'Amount exceeds that available for refund [1000]', response.message
  end

  private

  # Place raw successful response from gateway here
  def successful_visa_no_3d_purchase_response
    %(<?xml version="1.0" encoding="utf-8"?>
    <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <soap:Body>
        <CardDetailsTransactionResponse xmlns="https://www.thepaymentgateway.net/">
          <CardDetailsTransactionResult AuthorisationAttempted="True">
            <StatusCode>0</StatusCode>
            <Message>AuthCode: 939772</Message>
          </CardDetailsTransactionResult>
          <TransactionOutputData CrossReference="110706093540191601939772">
            <AuthCode>939772</AuthCode>
            <AddressNumericCheckResult>PASSED</AddressNumericCheckResult>
            <PostCodeCheckResult>PASSED</PostCodeCheckResult>
            <CV2CheckResult>PASSED</CV2CheckResult>
            <GatewayEntryPoints>
              <GatewayEntryPoint EntryPointURL="https://gw1.cardsaveonlinepayments.com:4430/" Metric="100"/>
              <GatewayEntryPoint EntryPointURL="https://gw2.cardsaveonlinepayments.com:4430/" Metric="200"/>
              <GatewayEntryPoint EntryPointURL="https://gw3.cardsaveonlinepayments.com:4430/" Metric="300"/>
            </GatewayEntryPoints>
          </TransactionOutputData>
        </CardDetailsTransactionResponse>
      </soap:Body>
    </soap:Envelope>)
  end

  def declined_switch_no_3d_purchase_response
    %(<?xml version="1.0" encoding="utf-8"?>
    <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <soap:Body>
        <CardDetailsTransactionResponse xmlns="https://www.thepaymentgateway.net/">
          <CardDetailsTransactionResult AuthorisationAttempted="True">
            <StatusCode>5</StatusCode>
            <Message>Card declined</Message>
          </CardDetailsTransactionResult>
          <TransactionOutputData CrossReference="110706102619764701991133">
            <AddressNumericCheckResult>NOT_SUBMITTED</AddressNumericCheckResult>
            <PostCodeCheckResult>NOT_SUBMITTED</PostCodeCheckResult>
            <CV2CheckResult>NOT_SUBMITTED</CV2CheckResult>
            <GatewayEntryPoints>
              <GatewayEntryPoint EntryPointURL="https://gw1.cardsaveonlinepayments.com:4430/" Metric="100"/>
              <GatewayEntryPoint EntryPointURL="https://gw2.cardsaveonlinepayments.com:4430/" Metric="200"/>
              <GatewayEntryPoint EntryPointURL="https://gw3.cardsaveonlinepayments.com:4430/" Metric="300"/>
            </GatewayEntryPoints>
          </TransactionOutputData>
        </CardDetailsTransactionResponse>
      </soap:Body>
    </soap:Envelope>)
  end

  def referred_mastercard_no_3d_secure_purchase_response
    %(<?xml version="1.0" encoding="utf-8"?>
    <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <soap:Body>
        <CardDetailsTransactionResponse xmlns="https://www.thepaymentgateway.net/">
          <CardDetailsTransactionResult AuthorisationAttempted="True">
            <StatusCode>4</StatusCode>
            <Message>Card referred</Message>
          </CardDetailsTransactionResult>
          <TransactionOutputData CrossReference="110706105145862601596515">
            <AddressNumericCheckResult>NOT_SUBMITTED</AddressNumericCheckResult>
            <PostCodeCheckResult>NOT_SUBMITTED</PostCodeCheckResult>
            <CV2CheckResult>NOT_SUBMITTED</CV2CheckResult>
            <GatewayEntryPoints>
              <GatewayEntryPoint EntryPointURL="https://gw1.cardsaveonlinepayments.com:4430/" Metric="100"/>
              <GatewayEntryPoint EntryPointURL="https://gw2.cardsaveonlinepayments.com:4430/" Metric="200"/>
              <GatewayEntryPoint EntryPointURL="https://gw3.cardsaveonlinepayments.com:4430/" Metric="300"/>
            </GatewayEntryPoints>
          </TransactionOutputData>
        </CardDetailsTransactionResponse>
      </soap:Body>
    </soap:Envelope>)
  end

  def failed_due_to_unsupported_card_currency_combination
    %(<?xml version="1.0" encoding="utf-8"?>
    <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <soap:Body>
        <CardDetailsTransactionResponse xmlns="https://www.thepaymentgateway.net/">
          <CardDetailsTransactionResult AuthorisationAttempted="False">
            <StatusCode>30</StatusCode>
            <Message>No routes found for American Express/GBP</Message>
          </CardDetailsTransactionResult>
          <TransactionOutputData>
            <AddressNumericCheckResult>NOT_SUBMITTED</AddressNumericCheckResult>
            <PostCodeCheckResult>NOT_SUBMITTED</PostCodeCheckResult>
            <CV2CheckResult>NOT_SUBMITTED</CV2CheckResult>
            <GatewayEntryPoints>
              <GatewayEntryPoint EntryPointURL="https://gw1.cardsaveonlinepayments.com:4430/" Metric="100"/>
              <GatewayEntryPoint EntryPointURL="https://gw2.cardsaveonlinepayments.com:4430/" Metric="200"/>
              <GatewayEntryPoint EntryPointURL="https://gw3.cardsaveonlinepayments.com:4430/" Metric="300"/>
            </GatewayEntryPoints>
          </TransactionOutputData>
        </CardDetailsTransactionResponse>
      </soap:Body>
    </soap:Envelope>)
  end

  def authorization_successful
    %(<?xml version="1.0" encoding="utf-8"?>
    <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <soap:Body>
        <CardDetailsTransactionResponse xmlns="https://www.thepaymentgateway.net/">
          <CardDetailsTransactionResult AuthorisationAttempted="True">
            <StatusCode>0</StatusCode>
            <Message>AuthCode: 702211</Message>
          </CardDetailsTransactionResult>
          <TransactionOutputData CrossReference="110706124418747501702211">
            <AuthCode>702211</AuthCode>
            <AddressNumericCheckResult>PASSED</AddressNumericCheckResult>
            <PostCodeCheckResult>PASSED</PostCodeCheckResult>
            <CV2CheckResult>PASSED</CV2CheckResult>
            <GatewayEntryPoints>
              <GatewayEntryPoint EntryPointURL="https://gw1.cardsaveonlinepayments.com:4430/" Metric="100"/>
              <GatewayEntryPoint EntryPointURL="https://gw2.cardsaveonlinepayments.com:4430/" Metric="200"/>
              <GatewayEntryPoint EntryPointURL="https://gw3.cardsaveonlinepayments.com:4430/" Metric="300"/>
            </GatewayEntryPoints>
          </TransactionOutputData>
        </CardDetailsTransactionResponse>
      </soap:Body>
    </soap:Envelope>)
  end

  def capture_successful
    %(<?xml version="1.0" encoding="utf-8"?>
    <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <soap:Body>
        <CrossReferenceTransactionResponse xmlns="https://www.thepaymentgateway.net/">
          <CrossReferenceTransactionResult AuthorisationAttempted="True">
            <StatusCode>0</StatusCode>
            <Message>Collection successful</Message>
          </CrossReferenceTransactionResult>
          <TransactionOutputData CrossReference="110706124418747501702211">
            <GatewayEntryPoints>
              <GatewayEntryPoint EntryPointURL="https://gw1.cardsaveonlinepayments.com:4430/" Metric="100"/>
              <GatewayEntryPoint EntryPointURL="https://gw2.cardsaveonlinepayments.com:4430/" Metric="200"/>
              <GatewayEntryPoint EntryPointURL="https://gw3.cardsaveonlinepayments.com:4430/" Metric="300"/>
            </GatewayEntryPoints>
          </TransactionOutputData>
        </CrossReferenceTransactionResponse>
      </soap:Body>
    </soap:Envelope>
    )
  end

  def successful_refund
    %(<?xml version="1.0" encoding="utf-8"?>
    <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <soap:Body>
        <CrossReferenceTransactionResponse xmlns="https://www.thepaymentgateway.net/">
          <CrossReferenceTransactionResult AuthorisationAttempted="True">
            <StatusCode>0</StatusCode>
            <Message>Refund successful</Message>
          </CrossReferenceTransactionResult>
          <TransactionOutputData CrossReference="110706132015423601247790">
            <GatewayEntryPoints>
              <GatewayEntryPoint EntryPointURL="https://gw1.cardsaveonlinepayments.com:4430/" Metric="100"/>
              <GatewayEntryPoint EntryPointURL="https://gw2.cardsaveonlinepayments.com:4430/" Metric="200"/>
              <GatewayEntryPoint EntryPointURL="https://gw3.cardsaveonlinepayments.com:4430/" Metric="300"/>
            </GatewayEntryPoints>
          </TransactionOutputData>
        </CrossReferenceTransactionResponse>
      </soap:Body>
    </soap:Envelope>)
  end

  def failed_refund
    %(<?xml version="1.0" encoding="utf-8"?>
    <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <soap:Body>
        <CrossReferenceTransactionResponse xmlns="https://www.thepaymentgateway.net/">
          <CrossReferenceTransactionResult AuthorisationAttempted="False">
            <StatusCode>30</StatusCode>
            <Message>Amount exceeds that available for refund [1000]</Message>
          </CrossReferenceTransactionResult>
          <TransactionOutputData CrossReference="110706132233872701536706">
            <GatewayEntryPoints>
              <GatewayEntryPoint EntryPointURL="https://gw1.cardsaveonlinepayments.com:4430/" Metric="100"/>
              <GatewayEntryPoint EntryPointURL="https://gw2.cardsaveonlinepayments.com:4430/" Metric="200"/>
              <GatewayEntryPoint EntryPointURL="https://gw3.cardsaveonlinepayments.com:4430/" Metric="300"/>
            </GatewayEntryPoints>
          </TransactionOutputData>
        </CrossReferenceTransactionResponse>
      </soap:Body>
    </soap:Envelope>)
  end

end
