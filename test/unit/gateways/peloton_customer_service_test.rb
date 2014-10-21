require 'test_helper'

class PelotonCustomerServiceTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = PelotonCustomerServiceGateway.new(
        :client_id => 678,
        :account_name =>'I',
        :password => 'P'
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

    @amount = 1000

    @options = {
        :canadian_address_verification => false,
        :order_id => 115,
        :language_code => 'EN',
        :email => 'john@example.com',
        :billing_amount => '',
        :billing_increment => '',
        :billing_period => '',
        :billing_begin_date_time => '',

        :billing_address => {
            :name => "John",
            :address1 => "772 1 Ave",
            :address2 => "",
            :city => "Calgary",
            :state => "AB",
            :country => "Canada",
            :zip => "T2N 0A3",
            :phone => "5872284918",
        },
        :shipping_address => {
            :name => "John",
            :address1 => "772 1 Ave",
            :address2 => "",
            :city => "Calgary",
            :state => "AB",
            :country => "Canada",
            :zip => "T2N 0A3",
            :phone => "5872284918",
        }
    }
  end

  def test_successful_purchase
  end

  def test_failed_purchase
  end

  def test_successful_create
    @gateway.expects(:ssl_post).returns(successful_create_response)

    response = @gateway.create(@credit_card, @options)
    assert_success response

    assert_equal '1', response.authorization
    assert response.test?
  end

  def test_failed_create
    @gateway.expects(:ssl_post).returns(failed_create_response)

    response = @gateway.create(@credit_card, @options)
    assert_failure response
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
    %(
      Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
      to "true" when running remote tests:

      $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
        test/remote/gateways/remote_peloton_customer_service_test.rb \
        -n test_successful_purchase
    )
  end

  def failed_purchase_response
  end

  def successful_create_response
    %q(<?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <CreateCustomerWithPreAuthResponse xmlns="http://www.peloton-technologies.com/">
              <CreateCustomerWithPreAuthResult>
                <Success>true</Success>
                <Message>Successful</Message>
                <MessageCode>0</MessageCode>
                <TransactionRefCode>1</TransactionRefCode>
                <CustomerId>1234</CustomerId>
              </CreateCustomerWithPreAuthResult>
            </CreateCustomerWithPreAuthResponse>
          </soap:Body>
        </soap:Envelope>)
  end

  def failed_create_response
    %q(<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <CreateCustomerWithPreAuthResponse xmlns="http://www.peloton-technologies.com/">
             <CreateCustomerWithPreAuthResult>
                <Success>false</Success>
                <Message>Customer code already exists</Message>
                <MessageCode>0</MessageCode>
                <TransactionRefCode/>
                <CustomerId/>
             </CreateCustomerWithPreAuthResult>
          </CreateCustomerWithPreAuthResponse>
        </soap:Body>
      </soap:Envelope>)
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
