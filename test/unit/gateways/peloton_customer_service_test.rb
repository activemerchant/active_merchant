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
        :customer_id => '123',
        :customer_state => 'active',
        :customer_status => 'active',

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

  # @gateway.expects(:ssl_post).returns(ADD_STUB)
  #
  # response = @gateway.ADD_METHOD()
  # assert_success response
  # assert_equal 'ADD AUTHORIZATION', response.authorization.split(';')[0]
  # assert response.test?

  # @gateway.expects(:ssl_post).returns(ADD_FAILED_STUB)
  #
  # response = @gateway.ADD_METHOD()
  # assert_failure response

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '24db1813-d75a-e411-80c5-005056a927b9', response.authorization.split(';')[0]
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '9e910699-c95a-e411-80c5-005056a927b9', response.authorization.split(';')[0]
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_create
    @gateway.expects(:ssl_post).returns(successful_create_response)

    response = @gateway.create(@credit_card, @options)
    assert_success response

    assert_equal @options[:customer_id], response.authorization.split(';')[1]
    assert response.test?
  end

  def test_failed_create
    @gateway.expects(:ssl_post).returns(failed_create_response)

    response = @gateway.create(@credit_card, @options)
    assert_failure response
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, @options)
    assert_success response
    assert_equal '9e910699-c95a-e411-80c5-005056a927b9', response.authorization.split(';')[0]
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, @options)
    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, @options)
    assert_success response
    assert_equal '9e910699-c95a-e411-80c5-005056a927b9', response.authorization.split(';')[0]
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, @options)
    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void(@options)
    assert_success response
    assert_equal '9e910699-c95a-e411-80c5-005056a927b9', response.authorization.split(';')[0]
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void(@options)
    assert_failure response
  end

  def test_successful_modify_billing
    @gateway.expects(:ssl_post).returns(successful_modify_billing_response)

    response = @gateway.modify_billing(@options)
    assert_success response
    assert_equal nil, response.authorization.split(';')[0]
    assert response.test?
  end

  def test_failed_modify_billing
    @gateway.expects(:ssl_post).returns(failed_modify_billing_response)

    response = @gateway.modify_billing(@options)
    assert_failure response
  end

  def test_successful_modify_card
    @gateway.expects(:ssl_post).returns(successful_modify_card_response)

    response = @gateway.modify_card(@credit_card, @options)
    assert_success response
    assert_equal '1', response.authorization.split(';')[0]
    assert response.test?

  end

  def test_failed_modify_card
    @gateway.expects(:ssl_post).returns(failed_modify_card_response)

    response = @gateway.modify_card(@credit_card, @options)
    assert_failure response
  end

  def test_successful_modify_state_and_status
    @gateway.expects(:ssl_post).returns(successful_modify_state_and_status_response)

    response = @gateway.modify_state_and_status(@options)
    assert_success response
    assert_equal nil, response.authorization.split(';')[0]
    assert response.test?

  end

  def test_failed_modify_state_and_status
    @gateway.expects(:ssl_post).returns(failed_modify_state_and_status_response)

    response = @gateway.modify_state_and_status(@options)
    assert_failure response
  end

  def test_successful_get_state_and_status
    @gateway.expects(:ssl_post).returns(successful_get_state_and_status_response)

    response = @gateway.get_state_and_status(@options)
    assert_success response
    assert_equal '', response.authorization.split(';')[0]
    assert_equal 'Active', response.authorization.split(';')[2]
    assert_equal 'Active', response.authorization.split(';')[3]
    assert response.test?

  end

  def test_failed_get_state_and_status
    @gateway.expects(:ssl_post).returns(failed_get_state_and_status_response)

    response = @gateway.get_state_and_status(@options)
    assert_failure response
  end

  private

  # %(
  #     Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
  #     to "true" when running remote tests:
  #
  #     $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
  #       test/remote/gateways/remote_peloton_customer_service_test.rb \
  #       -n test_successful_purchase
  #   )

  def successful_purchase_response
    %q(
       <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <soap:Body>
            <ProcessCustomerPaymentResponse xmlns="http://www.peloton-technologies.com/">
               <ProcessCustomerPaymentResult>
                  <Success>true</Success>
                  <Message>Successful</Message>
                  <MessageCode>0</MessageCode>
                  <TransactionRefCode>24db1813-d75a-e411-80c5-005056a927b9</TransactionRefCode>
               </ProcessCustomerPaymentResult>
            </ProcessCustomerPaymentResponse>
          </soap:Body>
        </soap:Envelope>)

  end

  def failed_purchase_response
    %q(
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
       <soap:Body>
          <ProcessCustomerPaymentResponse xmlns="http://www.peloton-technologies.com/">
             <ProcessCustomerPaymentResult>
                <Success>false</Success>
                <Message>Client Customer does not exist</Message>
                <MessageCode>304</MessageCode>
                <TransactionRefCode/>
             </ProcessCustomerPaymentResult>
          </ProcessCustomerPaymentResponse>
       </soap:Body>
    </soap:Envelope>)
  end

  def successful_authorize_response
    %q(<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <soap:Body>
          <ProcessCustomerPaymentResponse xmlns="http://www.peloton-technologies.com/">
          <ProcessCustomerPaymentResult>
            <Success>true</Success>
            <Message>Success</Message>
            <MessageCode>0</MessageCode>
            <TransactionRefCode>9e910699-c95a-e411-80c5-005056a927b9</TransactionRefCode>
          </ProcessCustomerPaymentResult>
          </ProcessCustomerPaymentResponse>
          </soap:Body>
      </soap:Envelope>)
  end

  def failed_authorize_response
    %q(<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
       <soap:Body>
          <ProcessCustomerPaymentResponse xmlns="http://www.peloton-technologies.com/">
             <ProcessCustomerPaymentResult>
                <Success>false</Success>
                <Message>Type is required</Message>
                <MessageCode>1</MessageCode>
                <TransactionRefCode/>
             </ProcessCustomerPaymentResult>
          </ProcessCustomerPaymentResponse>
        </soap:Body>
        </soap:Envelope>)
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
                <CustomerId>123</CustomerId>
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
    %q( <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <CompleteCustomerPreAuthResponse xmlns="http://www.peloton-technologies.com/">
              <CompleteCustomerPreAuthResult>
                <Success>true</Success>
                <Message>successful</Message>
                <MessageCode>0</MessageCode>
                <TransactionRefCode>9e910699-c95a-e411-80c5-005056a927b9</TransactionRefCode>
              </CompleteCustomerPreAuthResult>
            </CompleteCustomerPreAuthResponse>
          </soap:Body>
        </soap:Envelope>)
  end

  def failed_capture_response
    %q( <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <CompleteCustomerPreAuthResponse xmlns="http://www.peloton-technologies.com/">
              <CompleteCustomerPreAuthResult>
                <Success>false</Success>
                <Message>invalid something or other</Message>
                <MessageCode>555</MessageCode>
                <TransactionRefCode/>
              </CompleteCustomerPreAuthResult>
            </CompleteCustomerPreAuthResponse>
          </soap:Body>
        </soap:Envelope>)
  end

  def successful_refund_response
    %q( <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <RefundCustomerPaymentResponse xmlns="http://www.peloton-technologies.com/">
              <RefundCustomerPaymentResult>
                <Success>true</Success>
                <Message>successful</Message>
                <MessageCode>0</MessageCode>
                <TransactionRefCode>9e910699-c95a-e411-80c5-005056a927b9</TransactionRefCode>
              </RefundCustomerPaymentResult>
            </RefundCustomerPaymentResponse>
          </soap:Body>
        </soap:Envelope>)
  end

  def failed_refund_response
    %q( <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <RefundCustomerPaymentResponse xmlns="http://www.peloton-technologies.com/">
              <RefundCustomerPaymentResult>
                <Success>false</Success>
                <Message>some error message</Message>
                <MessageCode>715</MessageCode>
                <TransactionRefCode/>
              </RefundCustomerPaymentResult>
            </RefundCustomerPaymentResponse>
          </soap:Body>
        </soap:Envelope>)
  end

  def successful_void_response

  %q( <?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <CancelCustomerPreAuthResponse xmlns="http://www.peloton-technologies.com/">
            <CancelCustomerPreAuthResult>
              <Success>true</Success>
              <Message>successful</Message>
              <MessageCode>0</MessageCode>
              <TransactionRefCode>9e910699-c95a-e411-80c5-005056a927b9</TransactionRefCode>
            </CancelCustomerPreAuthResult>
          </CancelCustomerPreAuthResponse>
        </soap:Body>
       </soap:Envelope>)
  end

  def failed_void_response
    %q(<?xml version="1.0" encoding="utf-8"?>
       <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <CancelCustomerPreAuthResponse xmlns="http://www.peloton-technologies.com/">
            <CancelCustomerPreAuthResult>
              <Success>false</Success>
              <Message>Customer ID does not exist</Message>
              <MessageCode>1</MessageCode>
              <TransactionRefCode/>
            </CancelCustomerPreAuthResult>
          </CancelCustomerPreAuthResponse>
        </soap:Body>
       </soap:Envelope>)
  end

  def successful_modify_billing_response
     %q(<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
           <soap:Body>
              <ModifyCustomerBillingInfoResponse xmlns="http://www.peloton-technologies.com/">
                 <ModifyCustomerBillingInfoResult>
                    <Success>true</Success>
                    <Message>Success</Message>
                    <MessageCode>0</MessageCode>
                    <TransactionRefCode/>
                 </ModifyCustomerBillingInfoResult>
              </ModifyCustomerBillingInfoResponse>
           </soap:Body>
        </soap:Envelope>)
  end

  def failed_modify_billing_response
    %q(<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
         <soap:Body>
            <ModifyCustomerBillingInfoResponse xmlns="http://www.peloton-technologies.com/">
               <ModifyCustomerBillingInfoResult>
                  <Success>false</Success>
                  <Message>BillingPhoneNumber is required</Message>
                  <MessageCode>1</MessageCode>
                  <TransactionRefCode/>
               </ModifyCustomerBillingInfoResult>
            </ModifyCustomerBillingInfoResponse>
         </soap:Body>
        </soap:Envelope>)
  end

  def successful_modify_card_response
    %q(<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
         <soap:Body>
            <ModifyCustomerCardInfoWithPreAuthResponse xmlns="http://www.peloton-technologies.com/">
               <ModifyCustomerCardInfoWithPreAuthResult>
                  <Success>true</Success>
                  <Message>Success</Message>
                  <MessageCode>0</MessageCode>
                  <TransactionRefCode>1</TransactionRefCode>
               </ModifyCustomerCardInfoWithPreAuthResult>
            </ModifyCustomerCardInfoWithPreAuthResponse>
         </soap:Body>
        </soap:Envelope>)
  end

  def failed_modify_card_response
    %q(<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
       <soap:Body>
          <ModifyCustomerCardInfoWithPreAuthResponse xmlns="http://www.peloton-technologies.com/">
             <ModifyCustomerCardInfoWithPreAuthResult>
                <Success>false</Success>
                <Message>ExpiryMonth must be 1 to 12</Message>
                <MessageCode>1</MessageCode>
                <TransactionRefCode/>
             </ModifyCustomerCardInfoWithPreAuthResult>
          </ModifyCustomerCardInfoWithPreAuthResponse>
       </soap:Body>
      </soap:Envelope>)
  end

  def successful_modify_state_and_status_response
    %q(<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
       <soap:Body>
          <ModifyCustomerStateAndStatusResponse xmlns="http://www.peloton-technologies.com/">
             <ModifyCustomerStateAndStatusResult>
                <Success>true</Success>
                <Message>Success</Message>
                <MessageCode>0</MessageCode>
                <TransactionRefCode/>
             </ModifyCustomerStateAndStatusResult>
          </ModifyCustomerStateAndStatusResponse>
       </soap:Body>
      </soap:Envelope>)
  end

  def failed_modify_state_and_status_response
    %q(<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
       <soap:Body>
          <ModifyCustomerStateAndStatusResponse xmlns="http://www.peloton-technologies.com/">
             <ModifyCustomerStateAndStatusResult>
                <Success>false</Success>
                <Message>actives is not a valid State.</Message>
                <MessageCode>1</MessageCode>
                <TransactionRefCode/>
             </ModifyCustomerStateAndStatusResult>
          </ModifyCustomerStateAndStatusResponse>
       </soap:Body>
      </soap:Envelope>)
  end

  def successful_get_state_and_status_response
    %q(<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
       <soap:Body>
          <GetCustomerStateAndStatusResponse xmlns="http://www.peloton-technologies.com/">
             <GetCustomerStateAndStatusResult>
                <Success>true</Success>
                <Message>Success</Message>
                <MessageCode>0</MessageCode>
                <TransactionRefCode/>
             </GetCustomerStateAndStatusResult>
             <getCustomerStateAndStatusResponse>
                <CustomerState>Active</CustomerState>
                <CustomerStatus>Active</CustomerStatus>
             </getCustomerStateAndStatusResponse>
          </GetCustomerStateAndStatusResponse>
       </soap:Body>
      </soap:Envelope>)
  end

  def failed_get_state_and_status_response
    %q(<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
       <soap:Body>
          <GetCustomerStateAndStatusResponse xmlns="http://www.peloton-technologies.com/">
             <GetCustomerStateAndStatusResult>
                <Success>false</Success>
                <Message>Invalid Account. Please ensure your ClientId, AccountName and Password are correct</Message>
                <MessageCode>105</MessageCode>
                <TransactionRefCode/>
             </GetCustomerStateAndStatusResult>
             <getCustomerStateAndStatusResponse>
                <CustomerState>Unknown</CustomerState>
                <CustomerStatus>Unknown</CustomerStatus>
             </getCustomerStateAndStatusResponse>
          </GetCustomerStateAndStatusResponse>
       </soap:Body>
      </soap:Envelope>)
  end

end
