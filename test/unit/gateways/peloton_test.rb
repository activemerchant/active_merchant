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
        :order_number => 124,
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
    }
  end

  def test_successful_purchase
    @gateway.purchase(@amount, @credit_card, @options)
    # @gateway.expects(:ssl_post).returns(successful_purchase_response)
    #
    # response = @gateway.purchase(@amount, @credit_card, @options)
    # assert_success response
    #
    # assert_equal 'REPLACE', response.authorization
    # assert response.test?
  end

  def test_failed_purchase
    # @gateway.expects(:ssl_post).returns(failed_purchase_response)
    #
    # response = @gateway.purchase(@amount, @credit_card, @options)
    # assert_failure response
  end

  def test_successful_authorize
  end

  def test_failed_authorize
  end

  def test_successful_capture
  end

  def test_failed_capture
  end

  def test_successful_refund
  end

  def test_failed_refund
  end

  def test_successful_void
  end

  def test_failed_void
  end

  def test_successful_verify
  end

  def test_successful_verify_with_failed_void
  end

  def test_failed_verify
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
  end

  def successful_authorize_response
  end

  def failed_authorize_response
  end

  def successful_capture_response
  end

  def failed_capture_response
  end

  def successful_refund_response
  end

  def failed_refund_response
  end

  def successful_void_response
  end

  def failed_void_response
  end
end
