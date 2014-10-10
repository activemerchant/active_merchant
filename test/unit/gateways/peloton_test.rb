require 'test_helper'

class PelotonTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = PelotonGateway.new(
      :client_id => 22,
      :account_name =>'Ivrnet Inc.',
      :password => 'Password123'
    )

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
        :number => 4030000010001234,
        :month => 8,
        :year => 2016,
        :first_name => 'xiaobo',
        :last_name => 'zzz',
        :verification_value => 123,
        :brand => 'visa'
    )

    @check       = check(
        :institution_number => '001',
        :transit_number     => '26729'
    )

    @amount = 1000

    @options = {
        :canadian_address_verification => false,
        :type => 'P',
        :order_number => 126,
        :language_code => 'EN',

        :billing_name => "John",
        :billing_address1 => "772 1 Ave",
        :billing_address2 => "",
        :billing_city => "Calgary",
        :billing_province_state => "AB",
        :billing_country => "CA",
        :billing_postal_zip_code => "T2N 0A3",
        :billing_email_address => "john@example.com",
        :billing_phone_number => "5872284918",

        :shipping_name => "John",
        :shipping_address1 => "772 1 Ave",
        :shipping_address2 => "",
        :shipping_city => "Calgary",
        :shipping_province_state => "AB",
        :shipping_country => "Canada",
        :shipping_postal_zip_code => "T2N 0A3",
        :shipping_email_address => "john@example.com",
        :shipping_phone_number => "5872284918",
        :transaction_ref_code => '927d2150-f44f-e411-80c5-005056a927b9'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, @options)
    assert_success response
    assert_equal 'Success', response.message
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, @options)
    assert_success response
    assert_equal 'Success', response.message
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void(@options)
    assert_success response
    assert_equal 'Success', response.message
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void(@options)
    assert_failure response
    assert response.test?
  end


  private

  def successful_purchase_response
    # %(
    #   Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
    #   to "true" when running remote tests:
    #
    #   $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
    #     test/remote/gateways/remote_peloton_test.rb \
    #     -n test_successful_purchase
    # )

    %q( <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
         <soap:Body>
         <ProcessCustomerPaymentResponse xmlns="http://www.peloton-technologies.com/">
         <ProcessCustomerPaymentResult>
         <Success>true</Success>
                     <Message>Success</Message>
         <MessageCode>0</MessageCode>
                     <TransactionRefCode>edd7cafb-474e-e411-80c5-005056a927b9</TransactionRefCode>
         </ProcessCustomerPaymentResult>
               </ProcessCustomerPaymentResponse>
         </soap:Body>
         </soap:Envelope>)
  end

  def failed_purchase_response
    %q(<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <ProcessPaymentResponse xmlns="http://www.peloton-technologies.com/">
             <ProcessPaymentResult>
                <Success>false</Success>
                <Message>Duplicate Transaction exists within specified time period</Message>
                <MessageCode>715</MessageCode>
                <TransactionRefCode/>
             </ProcessPaymentResult>
          </ProcessPaymentResponse>
        </soap:Body>
      </soap:Envelope>
    )
  end

  def successful_capture_response
    %q(<?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <CompletePreAuthResponse xmlns="http://www.peloton-technologies.com/">
              <CompletePreAuthResult>
                <Success>true</Success>
                <Message>Success</Message>
                <MessageCode>0</MessageCode>
                <TransactionRefCode>edd7cafb-474e-e411-80c5-005056a927b9</TransactionRefCode>
              </CompletePreAuthResult>
            </CompletePreAuthResponse>
          </soap:Body>
        </soap:Envelope>
    )
  end

  def failed_capture_response
    %q(<?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <CompletePreAuthResponse xmlns="http://www.peloton-technologies.com/">
              <CompletePreAuthResult>
                <Success>false</Success>
                <Message>error message for failed capture</Message>
                <MessageCode>715</MessageCode>
                <TransactionRefCode>edd7cafb-474e-e411-80c5-005056a927b9</TransactionRefCode>
              </CompletePreAuthResult>
            </CompletePreAuthResponse>
          </soap:Body>
        </soap:Envelope>
      )
  end

  def successful_authorize_response
    %q(<?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <ProcessPaymentResponse xmlns="http://www.peloton-technologies.com/">
              <CompletePreAuthResult>
                <Success>true</Success>
                <Message>Success</Message>
                <MessageCode>0</MessageCode>
                <TransactionRefCode>edd7cafb-474e-e411-80c5-005056a927b9</TransactionRefCode>
              </CompletePreAuthResult>
            </CompletePreAuthResponse>
          </soap:Body>
        </soap:Envelope>)
  end

  def failed_authorize_response

    %q(<?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <ProcessPaymentResponse xmlns="http://www.peloton-technologies.com/">
              <ProcessPaymentResult>
                <Success>false</Success>
                <Message>specific error code depending on return from server</Message>
                <MessageCode>error code as int</MessageCode>
                <TransactionRefCode>edd7cafb-474e-e411-80c5-005056a927b9</TransactionRefCode>
              </ProcessPaymentResult>
            </ProcessPaymentResponse>
          </soap:Body>
        </soap:Envelope>)
  end

  def successful_refund_response
    %q(<?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <RefundPaymentResponse xmlns="http://www.peloton-technologies.com/">
              <RefundPaymentResult>
                <Success>true</Success>
                <Message>Success</Message>
                <MessageCode>0</MessageCode>
                <TransactionRefCode>edd7cafb-474e-e411-80c5-005056a927b9</TransactionRefCode>
              </RefundPaymentResult>
            </RefundPaymentResponse>
          </soap:Body>
        </soap:Envelope>
      )
  end

  def failed_refund_response
    %q(<?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <RefundPaymentResponse xmlns="http://www.peloton-technologies.com/">
              <RefundPaymentResult>
                <Success>false</Success>
                <Message>specific error code depending on return from server</Message>
                <MessageCode>error code as int</MessageCode>
                <TransactionRefCode>edd7cafb-474e-e411-80c5-005056a927b9</TransactionRefCode>
              </RefundPaymentResult>
            </RefundPaymentResponse>
          </soap:Body>
        </soap:Envelope>
      )
  end

  def successful_void_response
    %q(<?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <CancelPreAuthResponse xmlns="http://www.peloton-technologies.com/">
              <CancelPreAuthResult>
                <Success>true</Success>
                <Message>Success</Message>
                <MessageCode>0</MessageCode>
                <TransactionRefCode>edd7cafb-474e-e411-80c5-005056a927b9</TransactionRefCode>
              </CancelPreAuthResult>
            </CancelPreAuthResponse>
          </soap:Body>
        </soap:Envelope>)
  end

  def failed_void_response
    %q(<?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <CancelPreAuthResponse xmlns="http://www.peloton-technologies.com/">
              <CancelPreAuthResult>
                <Success>false</Success>
                <Message>error from server</Message>
                <MessageCode>715</MessageCode>
                <TransactionRefCode>edd7cafb-474e-e411-80c5-005056a927b9</TransactionRefCode>
              </CancelPreAuthResult>
            </CancelPreAuthResponse>
          </soap:Body>
        </soap:Envelope>)
  end
end
