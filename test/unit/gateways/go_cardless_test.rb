require 'test_helper'

class GoCardlessTest < Test::Unit::TestCase
  def setup
    @gateway = GoCardlessGateway.new(:access_token => 'sandbox_example')
    @amount = 1000
    @token = 'MD0004471PDN9N'
    @options = {
      order_id: "doj-2018091812403467",
      description: "John Doe - gold: Signup payment",
      currency: "EUR"
    }
    @customer_attributes = { 'email' => 'foo@bar.com', 'first_name' => 'John', 'last_name' => 'Doe' }
  end

  def test_successful_store_iban
    bank_account = mock_bank_account_with_iban
    stub_requests_to_be_successful

    response = @gateway.store(@customer_attributes, bank_account)

    assert_instance_of MultiResponse, response
    assert_success response
  end

  def test_successful_store_bank_credentials
    bank_account = mock_bank_account
    stub_requests_to_be_successful

    response = @gateway.store(@customer_attributes, bank_account)

    assert_instance_of MultiResponse, response
    assert_success response
  end

  def test_successful_purchase_with_token
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @token, @options)
    assert_instance_of Response, response
    assert_success response

    assert response.test?
  end

  def test_appropriate_purchase_amount
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @token, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 1000, response.params['payments']['amount']
  end

  private

  def mock_bank_account
    mock.tap do |bank_account_mock|
      bank_account_mock.expects(:iban).returns(nil)
      bank_account_mock.expects(:first_name).returns('John')
      bank_account_mock.expects(:last_name).returns('Doe')
      bank_account_mock.expects(:account_number).returns('0500013M026')
      bank_account_mock.expects(:routing_number).returns('20041')
    end
  end

  def mock_bank_account_with_iban
    mock.tap do |bank_account_mock|
      bank_account_mock.expects(:first_name).returns('John')
      bank_account_mock.expects(:last_name).returns('Doe')
      bank_account_mock.expects(:iban).twice.returns('FR1420041010050500013M02606')
    end
  end

  def stub_requests_to_be_successful
    @gateway.expects(:ssl_request)
      .with(:post, 'https://api-sandbox.gocardless.com/customers', anything, anything)
      .returns(successful_create_customer_response)

    @gateway.expects(:ssl_request)
      .with(:post, 'https://api-sandbox.gocardless.com/customer_bank_accounts', anything, anything)
      .returns(successful_create_bank_account_response)

    @gateway.expects(:ssl_request)
      .with(:post, 'https://api-sandbox.gocardless.com/mandates', anything, anything)
      .returns(successful_create_mandate_response)
  end

  def successful_purchase_response
    <<~RESPONSE
      {
        "payments": {
          "id": "PM000BW9DTN7Q7",
          "created_at": "2018-09-18T12:45:18.664Z",
          "charge_date": "2018-09-21",
          "amount": 1000,
          "description": "John Doe - gold: Signup payment",
          "currency": "EUR",
          "status": "pending_submission",
          "amount_refunded": 0,
          "metadata": {},
          "links": {
            "mandate": "MD0004471PDN9N",
            "creditor": "CR00005PHGZZE7"
          }
        }
      }
    RESPONSE
  end

  def successful_create_customer_response
    <<~RESPONSE
      {
        "customers": {
          "id": "CU0004CKN9T1HZ"
        }
      }
    RESPONSE
  end

  def successful_create_bank_account_response
    <<~RESPONSE
      {
        "customer_bank_accounts": {
          "id": "BA00046869V55G"
        }
      }
    RESPONSE
  end

  def successful_create_mandate_response
    <<~RESPONSE
      {
        "customer_bank_accounts": {
          "id":"BA0004687N7GD5"
        }
      }
    RESPONSE
  end
end
