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

  def test_successful_update
    bank_account = mock_bank_account_with_iban
    stub_update_requests_to_be_successful

    customer_id = JSON.parse(successful_create_customer_response)["customers"]["id"]

    update_response = @gateway.update(customer_id, @customer_attributes, bank_account)
    assert_success update_response
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

  def test_unstore_customer
    bank_account = mock_bank_account_with_iban
    stub_requests_to_be_successful
    stub_unstore_requests_to_be_successful

    response = @gateway.store(@customer_attributes, bank_account)

    assert customer_id = response.responses.first.params["customers"]["id"]
    delete_response = @gateway.unstore(customer_id)
    assert_success delete_response
  end

  def test_cancel_mandate
    bank_account = mock_bank_account_with_iban
    stub_requests_to_be_successful
    stub_cancel_requests_to_be_successful

    response = @gateway.store(@customer_attributes, bank_account)

    assert bank_account_id = response.params["customer_bank_accounts"]["id"]
    cancel_response = @gateway.cancel_mandate(bank_account_id)
    assert_success cancel_response
  end

  def test_successful_refund
    @gateway.expects(:ssl_request)
       .with(:post, 'https://api-sandbox.gocardless.com/refunds', anything, anything)
      .returns(successful_refund_response)

    @gateway.expects(:ssl_request)
       .with(:get, 'https://api-sandbox.gocardless.com/refunds?payment=PM000C7A086NA7', anything, anything)
       .returns(successful_refunds_response)

    assert response = @gateway.refund(@amount, 'PM000C7A086NA7', @options)
    assert_instance_of MultiResponse, response
    assert_success response
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def mock_bank_account
    mock.tap do |bank_account_mock|
      bank_account_mock.expects(:iban).returns(nil)
      bank_account_mock.expects(:first_name).returns('John')
      bank_account_mock.expects(:last_name).returns('Doe')
      bank_account_mock.expects(:account_number).returns('0500013M026')
      bank_account_mock.expects(:routing_number).returns('20041')
      bank_account_mock.expects(:branch_code).returns('01005')
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

  def stub_update_requests_to_be_successful
    @gateway.expects(:ssl_request)
      .with(:put, 'https://api-sandbox.gocardless.com/customers/CU0004CKN9T1HZ', anything, anything)
      .returns(successful_create_customer_response)

    @gateway.expects(:ssl_request)
      .with(:post, 'https://api-sandbox.gocardless.com/customer_bank_accounts', anything, anything)
      .returns(successful_create_bank_account_response)

    @gateway.expects(:ssl_request)
      .with(:post, 'https://api-sandbox.gocardless.com/mandates', anything, anything)
      .returns(successful_create_mandate_response)
  end

  def stub_unstore_requests_to_be_successful
    @gateway.expects(:ssl_request)
      .with(:delete, 'https://api-sandbox.gocardless.com/customers/CU0004CKN9T1HZ', anything, anything)
  end

  def stub_cancel_requests_to_be_successful
    @gateway.expects(:ssl_request)
      .with(:post, 'https://api-sandbox.gocardless.com/mandates/BA0004687N7GD5/actions/cancel', anything, anything)
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

  def successful_refund_response
    <<~RESPONSE
      {
        "refunds": {
          "id": "RF00001YXDDTBJ",
          "amount":1000,
          "created_at":"2018-11-14T09:34:51.899Z",
          "reference":"TESTOWA-7NFMZDD6DK",
          "metadata":{},
          "currency":"EUR",
          "links": {
            "payment": "PM000C7A086NA7",
            "mandate":"MD00048KV3PRCX"
          }
        }
      }
    RESPONSE
  end

  def successful_refunds_response
    <<~RESPONSE
      {
        "refunds": []
      }
    RESPONSE
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
      "opening connection to api-sandbox.gocardless.com:443...\n
      opened\n
      starting SSL for api-sandbox.gocardless.com:443...\n
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384\n
      <- \"POST /customers HTTP/1.1\\r\\n
      Content-Type: application/json\\r\\n
      Accept: application/json\\r\\n
      User-Agent: ActiveMerchantBindings/1.60.0\\r\\n
      Authorization: Bearer sandbox_2q9vefoLmsn99vvSu2togwKjvfOPtlyKUHMx2o5q\\r\\n
      Gocardless-Version: 2015-07-06\\r\\n
      Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\n
      Connection: close\\r\\n
      Host: api-sandbox.gocardless.com\\r\\n
      Content-Length: 291\\r\\n
      \\r\\n\"\n
      <- \"{\\\"customers\\\":{\\\"email\\\":\\\"test@example.com\\\",\\\"given_name\\\":\\\"John\\\",\\\"family_name\\\":\\\"GoCardless\\\",\\\"phone_number\\\":null,\\\"danish_identity_number\\\":null,\\\"swedish_identity_number\\\":\\\"198112289874\\\",\\\"address_line1\\\":\\\"Test\\\",\\\"address_line2\\\":\\\"\\\",\\\"city\\\":\\\"Test\\\",\\\"region\\\":\\\"K\\\",\\\"postal_code\\\":\\\"12345\\\",\\\"country_code\\\":\\\"SE\\\"}}\"\n
      -> \"HTTP/1.1 201 Created\\r\\n\"\n->
      opening connection to api-sandbox.gocardless.com:443...\n
      opened\nstarting SSL for api-sandbox.gocardless.com:443...\n
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384\n
      <- \"POST /customer_bank_accounts HTTP/1.1\\r\\nContent-Type: application/json\\r\\nAccept: application/json\\r\\nUser-Agent: ActiveMerchantBindings/1.60.0\\r\\nAuthorization: Bearer sandbox_2q9vefoLmsn99vvSu2togwKjvfOPtlyKUHMx2o5q\\r\\nGocardless-Version: 2015-07-06\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nConnection: close\\r\\nHost: api-sandbox.gocardless.com\\r\\nContent-Length: 208\\r\\n\\r\\n\"\n<- \"{\\\"customer_bank_accounts\\\":{\\\"account_holder_name\\\":\\\"John GoCardless\\\",\\\"links\\\":{\\\"customer\\\":\\\"CU000JN4G2PXE7\\\"},\\\"currency\\\":\\\"SEK\\\",\\\"country_code\\\":\\\"SE\\\",\\\"bank_code\\\":null,\\\"branch_code\\\":\\\"5491\\\",\\\"account_number\\\":\\\"0000003\\\"}}\"\n
      -> \"HTTP/1.1 201 Created
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      "opening connection to api-sandbox.gocardless.com:443...\n
      opened\n
      starting SSL for api-sandbox.gocardless.com:443...\n
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384\n
      <- \"POST /customers HTTP/1.1\\r\\n
      Content-Type: application/json\\r\\n
      Accept: application/json\\r\\n
      User-Agent: ActiveMerchantBindings/1.60.0\\r\\n
      Authorization: Bearer [FILTERED]\\r\\n
      Gocardless-Version: 2015-07-06\\r\\n
      Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\n
      Connection: close\\r\\n
      Host: api-sandbox.gocardless.com\\r\\n
      Content-Length: 291\\r\\n
      \\r\\n\"\n
      <- \"{\\\"customers\\\":{\\\"email\\\":\\\"test@example.com\\\",\\\"given_name\\\":\\\"John\\\",\\\"family_name\\\":\\\"GoCardless\\\",\\\"phone_number\\\":null,\\\"danish_identity_number\\\":[FILTERED],\\\"swedish_identity_number\\\":[FILTERED],\\\"address_line1\\\":\\\"Test\\\",\\\"address_line2\\\":\\\"\\\",\\\"city\\\":\\\"Test\\\",\\\"region\\\":\\\"K\\\",\\\"postal_code\\\":\\\"12345\\\",\\\"country_code\\\":\\\"SE\\\"}}\"\n
      -> \"HTTP/1.1 201 Created\\r\\n\"\n->
      opening connection to api-sandbox.gocardless.com:443...\n
      opened\nstarting SSL for api-sandbox.gocardless.com:443...\n
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384\n
      <- \"POST /customer_bank_accounts HTTP/1.1\\r\\nContent-Type: application/json\\r\\nAccept: application/json\\r\\nUser-Agent: ActiveMerchantBindings/1.60.0\\r\\nAuthorization: Bearer [FILTERED]\\r\\nGocardless-Version: 2015-07-06\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nConnection: close\\r\\nHost: api-sandbox.gocardless.com\\r\\nContent-Length: 208\\r\\n\\r\\n\"\n<- \"{\\\"customer_bank_accounts\\\":{\\\"account_holder_name\\\":\\\"John GoCardless\\\",\\\"links\\\":{\\\"customer\\\":\\\"CU000JN4G2PXE7\\\"},\\\"currency\\\":\\\"SEK\\\",\\\"country_code\\\":\\\"SE\\\",\\\"bank_code\\\":[FILTERED],\\\"branch_code\\\":[FILTERED],\\\"account_number\\\":[FILTERED]}}\"\n
      -> \"HTTP/1.1 201 Created
    POST_SCRUBBED
  end
end
