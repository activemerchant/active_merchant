require 'test_helper'

class PlexoTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = PlexoGateway.new(client_id: 'abcd', api_key: 'efgh', merchant_id: 'test090')

    @amount = 100
    @credit_card = credit_card('5555555555554444', month: '12', year: '2024', verification_value: '111', first_name: 'Santiago', last_name: 'Navatta')
    @declined_card = credit_card('5555555555554445')
    @options = {
      email: 'snavatta@plexo.com.uy',
      ip: '127.0.0.1',
      items: [
        {
          name: 'prueba',
          description: 'prueba desc',
          quantity: '1',
          price: '100',
          discount: '0'
        }
      ],
      amount_details: {
        tip_amount: '5'
      },
      metadata: {
        custom_one: 'test1',
        test_a: 'abc'
      },
      identification_type: '1',
      identification_value: '123456',
      billing_address: address
    }

    @cancel_options = {
      description: 'Test desc',
      reason: 'requested by client'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'You have been mocked', response.message
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 400, response.error_code
  end

  def test_successful_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal 'test090', request['MerchantId']
      assert_equal @credit_card.number, request['paymentMethod']['Card']['Number']
      assert_equal @credit_card.verification_value, request['paymentMethod']['Card']['Cvc']
      assert_equal @credit_card.first_name, request['paymentMethod']['Card']['Cardholder']['FirstName']
      assert_equal @options[:email], request['paymentMethod']['Card']['Cardholder']['Email']
      assert_equal @options[:identification_type], request['paymentMethod']['Card']['Cardholder']['Identification']['Type']
      assert_equal @options[:identification_value], request['paymentMethod']['Card']['Cardholder']['Identification']['Value']
      assert_equal @options[:billing_address][:city], request['paymentMethod']['Card']['Cardholder']['BillingAddress']['City']
      assert_equal @options[:billing_address][:country], request['paymentMethod']['Card']['Cardholder']['BillingAddress']['Country']
      assert_equal @options[:billing_address][:address1], request['paymentMethod']['Card']['Cardholder']['BillingAddress']['Line1']
      assert_equal @options[:billing_address][:address2], request['paymentMethod']['Card']['Cardholder']['BillingAddress']['Line2']
      assert_equal @options[:billing_address][:zip], request['paymentMethod']['Card']['Cardholder']['BillingAddress']['PostalCode']
      assert_equal @options[:billing_address][:state], request['paymentMethod']['Card']['Cardholder']['BillingAddress']['State']
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_successful_authorize_with_items
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      request['Items'].each_with_index do |item, index|
        assert_not_nil item['ReferenceId']
        assert_equal item['Name'], @options[:items][index][:name] if item['Name']
        assert_equal item['Description'], @options[:items][index][:description] if item['Description']
        assert_equal item['Quantity'], @options[:items][index][:quantity] if item['Quantity']
        assert_equal item['Price'], @options[:items][index][:price] if item['Price']
        assert_equal item['Discount'], @options[:items][index][:discount] if item['Discount']
      end
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_successful_authorize_with_meta_fields
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      @options[:metadata].each_key do |meta_key|
        camel_key = meta_key.to_s.camelize
        assert_equal request['Metadata'][camel_key], @options[:metadata][meta_key]
      end
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_successful_authorize_with_finger_print
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge({ finger_print: 'USABJHABSFASNJKN123532' }))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['BrowserDetails']['DeviceFingerprint'], 'USABJHABSFASNJKN123532'
    end.respond_with(successful_authorize_response)
  end

  def test_successful_authorize_with_invoice_number
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge({ invoice_number: '12345abcde' }))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['InvoiceNumber'], '12345abcde'
    end.respond_with(successful_authorize_response)
  end

  def test_successful_authorize_with_merchant_id
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge({ merchant_id: 1234 }))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['MerchantId'], 1234
    end.respond_with(successful_authorize_response)
  end

  def test_successful_reordering_of_amount_in_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    original_response = JSON.parse(successful_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal response.params['amount'], original_response['amount']['total']
    assert_equal response.params['currency'], original_response['amount']['currency']
    assert_equal response.params['amount_details'], original_response['amount']['details']
  end

  def test_successful_authorize_with_extra_options
    other_fields = {
      installments: '1',
      statement_descriptor: 'Plexo * Test',
      customer_id: 'customer1',
      cardholder_birthdate: '1999-08-18T19:49:37.023Z'
    }
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(other_fields))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['Installments'], other_fields[:installments]
      assert_equal request['CustomerId'], other_fields[:customer_id]
      assert_equal request['StatementDescriptor'], other_fields[:statement_descriptor]
      assert_equal request['paymentMethod']['Card']['Cardholder']['Birthdate'], other_fields[:cardholder_birthdate]
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_successful_authorize_with_amount_fields
    amount_fields = {
      taxed_amount: '100',
      tip_amount: '32',
      discount_amount: '10',
      taxable_amount: '302',
      tax: {
        type: '17934',
        amount: '22',
        rate: '0.22'
      }
    }
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge({ amount_details: amount_fields, currency: 'USD' }))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['Amount']['Currency'], 'USD'
      assert_equal request['Amount']['Details']['TaxedAmount'], amount_fields[:taxed_amount]
      assert_equal request['Amount']['Details']['TipAmount'], amount_fields[:tip_amount]
      assert_equal request['Amount']['Details']['DiscountAmount'], amount_fields[:discount_amount]
      assert_equal request['Amount']['Details']['TaxableAmount'], amount_fields[:taxable_amount]
      assert_equal request['Amount']['Details']['Tax']['Type'], amount_fields[:tax][:type]
      assert_equal request['Amount']['Details']['Tax']['Amount'], amount_fields[:tax][:amount]
      assert_equal request['Amount']['Details']['Tax']['Rate'], amount_fields[:tax][:rate]
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 400, response.error_code
  end

  def test_successful_capture
    response = stub_comms do
      @gateway.capture(@amount, '123456abcdef', { reference_id: 'reference123' })
    end.check_request do |endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['ReferenceId'], 'reference123'
      assert_includes endpoint, '123456abcdef'
    end.respond_with(successful_capture_response)

    assert_success response
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 400, response.error_code
  end

  def test_successful_refund
    refund_options = {
      reference_id: 'reference123',
      refund_type: 'partial-refund',
      description: 'my description',
      reason: 'reason abc'
    }
    response = stub_comms do
      @gateway.refund(@amount, '123456abcdef', refund_options)
    end.check_request do |endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['ReferenceId'], refund_options[:reference_id]
      assert_equal request['Type'], refund_options[:refund_type]
      assert_equal request['Description'], refund_options[:description]
      assert_equal request['Reason'], refund_options[:reason]
      assert_includes endpoint, '123456abcdef'
    end.respond_with(successful_refund_response)

    assert_success response
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 400, response.error_code
  end

  def test_successful_void
    void_options = {
      reference_id: 'reference123',
      description: 'my description',
      reason: 'reason abc'
    }
    response = stub_comms do
      @gateway.void('123456abcdef', void_options)
    end.check_request do |endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['ReferenceId'], void_options[:reference_id]
      assert_equal request['Description'], void_options[:description]
      assert_equal request['Reason'], void_options[:reason]
      assert_includes endpoint, '123456abcdef'
    end.respond_with(successful_void_response)

    assert_success response
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void(@credit_card, @options)
    assert_failure response
    assert_equal 400, response.error_code
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'You have been mocked.', response.message
  end

  def test_successful_verify_with_custom_amount
    stub_comms do
      @gateway.verify(@credit_card, @options.merge({ verify_amount: '900' }))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['Amount']['Total'], '9.00'
    end.respond_with(successful_verify_response)
  end

  def test_successful_verify_with_invoice_number
    stub_comms do
      @gateway.verify(@credit_card, @options.merge({ invoice_number: '12345abcde' }))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['InvoiceNumber'], '12345abcde'
    end.respond_with(successful_verify_response)
  end

  def test_successful_verify_with_merchant_id
    stub_comms do
      @gateway.verify(@credit_card, @options.merge({ merchant_id: 1234 }))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['MerchantId'], 1234
    end.respond_with(successful_verify_response)
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal 400, response.error_code
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<~PRE_SCRUBBED
      opening connection to api.testing.plexo.com.uy:443...
      opened
      starting SSL for api.testing.plexo.com.uy:443...
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384
      <- "POST /v1/payments/628b723aa450dab85ba2fa03/captures HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic MjIxOjlkZWZhZWVlYmMzOTQ1NDFhZmY2MzMyOTE4MmRkODQyNDA1MTJhYTI0NWE0NDY2MDkxZWQ3MGY2OTAxYjQ5NDc=\r\nX-Mock-Tokenization: true\r\nX-Mock-Switcher: true\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: api.testing.plexo.com.uy\r\nContent-Length: 66\r\n\r\n"
      <- "{\"ReferenceId\":\"e6742109bb60458b1c5a7c69ffcc3f54\",\"Amount\":\"1.00\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Mon, 23 May 2022 11:38:35 GMT\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "X-MiniProfiler-Ids: [\"c6b2ce60-757c-4115-b802-e33a27c2e311\",\"e1533461-72dc-4693-97a6-deea47601ca4\",\"da8b919f-a1f8-4051-870d-3679f4c8ac6b\",\"4465311a-ab60-470d-8f69-e06eed35c271\",\"c4b23b7d-e824-4fd6-95b9-82fa4786f4a2\",\"c5fe47c7-6155-4eb7-b9f4-84cd7fae7acf\",\"80e2f132-1ac1-4b25-b030-5eaccd44a0db\",\"525c97a7-5df7-4dd5-b1da-4c6abe9a5995\",\"98694fd6-f3ff-497a-b6d4-477a50a093aa\",\"802b9242-97c6-4438-bd72-960dbdf2f752\",\"7aa9078c-12f1-41f4-bc57-c77fb8a9ecc8\",\"4890d7e1-22c9-4e9d-afe1-88149e743aa0\",\"cafed17f-08ce-49cc-91d0-d8d9865facc7\",\"98fea53d-ad00-44cb-8e82-0829e5c8aaee\",\"5730d4fa-1c70-4679-a097-d9c8b7156f2d\",\"ba7d9c5a-e2bc-461f-b87d-552ae9fabb65\",\"3b1dbbbe-8112-4293-9be3-c865741c5494\",\"3ab01bd5-a2b5-4d9c-84c7-9c743f1e9978\",\"d6e397a3-cf95-413c-b3c6-4729aa463d33\",\"fc9cb79e-ab22-42b0-b611-0b3f62a203bb\",\"b16fd902-f50a-43e2-8e82-cc0fe763b16b\",\"dc702114-866c-4b9a-bc07-291b0b0f8b73\"]\r\n"
      -> "x-correlation-id: 24ebd1ee-a69a-4163-85cf-e5a1ab7fd26b\r\n"
      -> "Strict-Transport-Security: max-age=15724800; includeSubDomains\r\n"
      -> "\r\n"
      -> "192\r\n"
      reading 402 bytes...
      -> "{\"id\":\"628b723ba450dab85ba2fa0a\",\"uniqueId\":\"978260656060936192\",\"parentId\":\"cf8ecc4a-b0ed-4a40-945e-0eaff39e66f9\",\"referenceId\":\"e6742109bb60458b1c5a7c69ffcc3f54\",\"type\":\"capture\",\"status\":\"approved\",\"createdAt\":\"2022-05-23T11:38:35.6091676Z\",\"processedAt\":\"2022-05-23T11:38:35.6091521Z\",\"resultCode\":\"0\",\"resultMessage\":\"You have been mocked.\",\"authorization\":\"12133\",\"ticket\":\"111111\",\"amount\":1.00}"
      read 402 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<~POST_SCRUBBED
      opening connection to api.testing.plexo.com.uy:443...
      opened
      starting SSL for api.testing.plexo.com.uy:443...
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384
      <- "POST /v1/payments/628b723aa450dab85ba2fa03/captures HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]=\r\nX-Mock-Tokenization: true\r\nX-Mock-Switcher: true\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: api.testing.plexo.com.uy\r\nContent-Length: 66\r\n\r\n"
      <- "{\"ReferenceId\":\"e6742109bb60458b1c5a7c69ffcc3f54",\"Amount\":\"1.00\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Mon, 23 May 2022 11:38:35 GMT\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "X-MiniProfiler-Ids: [\"c6b2ce60-757c-4115-b802-e33a27c2e311\",\"e1533461-72dc-4693-97a6-deea47601ca4\",\"da8b919f-a1f8-4051-870d-3679f4c8ac6b\",\"4465311a-ab60-470d-8f69-e06eed35c271\",\"c4b23b7d-e824-4fd6-95b9-82fa4786f4a2\",\"c5fe47c7-6155-4eb7-b9f4-84cd7fae7acf\",\"80e2f132-1ac1-4b25-b030-5eaccd44a0db\",\"525c97a7-5df7-4dd5-b1da-4c6abe9a5995\",\"98694fd6-f3ff-497a-b6d4-477a50a093aa\",\"802b9242-97c6-4438-bd72-960dbdf2f752\",\"7aa9078c-12f1-41f4-bc57-c77fb8a9ecc8\",\"4890d7e1-22c9-4e9d-afe1-88149e743aa0\",\"cafed17f-08ce-49cc-91d0-d8d9865facc7\",\"98fea53d-ad00-44cb-8e82-0829e5c8aaee\",\"5730d4fa-1c70-4679-a097-d9c8b7156f2d\",\"ba7d9c5a-e2bc-461f-b87d-552ae9fabb65\",\"3b1dbbbe-8112-4293-9be3-c865741c5494\",\"3ab01bd5-a2b5-4d9c-84c7-9c743f1e9978\",\"d6e397a3-cf95-413c-b3c6-4729aa463d33\",\"fc9cb79e-ab22-42b0-b611-0b3f62a203bb\",\"b16fd902-f50a-43e2-8e82-cc0fe763b16b\",\"dc702114-866c-4b9a-bc07-291b0b0f8b73\"]\r\n"
      -> "x-correlation-id: 24ebd1ee-a69a-4163-85cf-e5a1ab7fd26b\r\n"
      -> "Strict-Transport-Security: max-age=15724800; includeSubDomains\r\n"
      -> "\r\n"
      -> "192\r\n"
      reading 402 bytes...
      -> "{\"id\":\"628b723ba450dab85ba2fa0a\",\"uniqueId\":\"978260656060936192\",\"parentId\":\"cf8ecc4a-b0ed-4a40-945e-0eaff39e66f9\",\"referenceId\":\"e6742109bb60458b1c5a7c69ffcc3f54",\"type\":\"capture\",\"status\":\"approved\",\"createdAt\":\"2022-05-23T11:38:35.6091676Z\",\"processedAt\":\"2022-05-23T11:38:35.6091521Z\",\"resultCode\":\"0\",\"resultMessage\":\"You have been mocked.\",\"authorization\":\"12133\",\"ticket\":\"111111\",\"amount\":1.00}"
      read 402 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    POST_SCRUBBED
  end

  def failed_purchase_response
    <<~RESPONSE
      {
        "code": "merchant-not-found",
        "message": "The requested Merchant was not found.",
        "type": "invalid-request-error",
        "status": 400
      }
    RESPONSE
  end

  def successful_authorize_response
    <<~RESPONSE
      {
        "id": "62878b1fa450dab85ba2f983",
        "token": "7c23b951-599f-462e-8a47-6bbbb4dc5ad0",
        "referenceId": "e7dbc06224f646ad8e63ec1c6e670a39",
        "status": "approved",
        "processingMethod": "api",
        "browserDetails": {
            "DeviceFingerprint": "12345",
            "IpAddress": "127.0.0.1"
        },
        "createdAt": "2022-05-20T12:35:43.1389809Z",
        "merchant": {
            "id": 3243,
            "name": "spreedly",
            "settings": {
                "id": 41363,
                "issuerId": 4,
                "issuer": {
                    "id": 4,
                    "code": "mastercard",
                    "name": "MASTERCARD",
                    "type": "online"
                },
                "metadata": {
                    "ProviderCommerceNumber": "153289",
                    "TerminalNumber": "1K153289",
                    "SoftDescriptor": "VTEX-Testing",
                    "PaymentProcessorId": "oca"
                },
                "paymentProcessor": {
                    "acquirer": "oca",
                    "settings": {
                        "commerce": {
                            "fields": [
                                {
                                    "name": "ProviderCommerceNumber",
                                    "type": 2049
                                },
                                {
                                    "name": "TerminalNumber",
                                    "type": 2051
                                }
                            ]
                        },
                        "fingerprint": {
                            "name": "cybersource-oca"
                        },
                        "fields": [
                            {
                                "name": "Email",
                                "type": 261
                            },
                            {
                                "name": "FirstName",
                                "type": 271
                            },
                            {
                                "name": "LastName",
                                "type": 272
                            },
                            {
                                "name": "CVC",
                                "type": 33154
                            }
                        ]
                    }
                }
            },
            "clientId": 221
        },
        "client": {
            "id": 221,
            "name": "Spreedly",
            "tier": 2,
            "sessionTimeInSeconds": 36000
        },
        "paymentMethod": {
            "type": "card",
            "card": {
                "name": "555555XXXXXX4444",
                "bin": "555555",
                "last4": "4444",
                "expMonth": 12,
                "expYear": 24,
                "cardholder": {
                    "firstName": "Santiago",
                    "lastName": "Navatta",
                    "email": "snavatta@plexo.com.uy"
                },
                "fingerprint": "2cccefc7e6e54644b5f5540aaab7744b"
            },
            "issuer": {
                "id": "mastercard",
                "name": "MasterCard",
                "pictureUrl": "https://static.plexo.com.uy/issuers/4.svg",
                "type": "online"
            },
            "processor": {
                "acquirer": "oca"
            }
        },
        "installments": 1,
        "amount": {
            "currency": "UYU",
            "total": 147,
            "details": {
                "taxedAmount": 0
            }
        },
        "items": [
            {
                "referenceId": "7c34953392e84949ab511667db0ebef2",
                "name": "prueba",
                "description": "prueba desc",
                "quantity": 1,
                "price": 100,
                "discount": 0
            }
        ],
        "capture": {
            "method": "manual"
        },
        "transactions": [
            {
                "id": "62878b1fa450dab85ba2f987",
                "uniqueId": "977187868889886720",
                "parentId": "7c23b951-599f-462e-8a47-6bbbb4dc5ad0",
                "referenceId": "e7dbc06224f646ad8e63ec1c6e670a39",
                "type": "authorization",
                "status": "approved",
                "createdAt": "2022-05-20T12:35:43.2161946Z",
                "processedAt": "2022-05-20T12:35:43.2161798Z",
                "resultCode": "0",
                "resultMessage": "You have been mocked.",
                "authorization": "12133",
                "ticket": "111111",
                "amount": 147
            }
        ]
      }
    RESPONSE
  end

  def successful_purchase_response
    <<~RESPONSE
      {
        "id": "6305dd2d000d6ed5d1ecf79b",
        "token": "82ae122c-d235-43bc-a454-fba16b2ae3a4",
        "referenceId": "e7dbc06224f646ad8e63ec1c6e670a39",
        "status": "approved",
        "processingMethod": "api",
        "createdAt": "2022-08-24T08:11:25.677Z",
        "updatedAt": "2022-08-24T08:11:26.2893146Z",
        "processedAt": "2022-08-24T08:11:26.2893146Z",
        "merchant": {
            "id": 3243,
            "name": "spreedly",
            "settings": {
                "merchantIdentificationNumber": "98001456",
                "paymentProcessor": {
                    "acquirer": "fiserv"
                }
            },
            "clientId": 221
        },
        "client": {
            "id": 221,
            "name": "Spreedly",
            "tier": 2,
            "sessionTimeInSeconds": 36000
        },
        "paymentMethod": {
            "id": "mastercard",
            "name": "MASTERCARD",
            "type": "card",
            "card": {
                "name": "555555XXXXXX4444",
                "bin": "555555",
                "last4": "4444",
                "expMonth": 12,
                "expYear": 24,
                "cardholder": {
                    "firstName": "Santiago",
                    "lastName": "Navatta",
                    "email": "snavatta@plexo.com.uy",
                    "identification": {
                        "type": 1,
                        "value": "123456"
                    },
                    "billingAddress": {
                        "city": "Karachi",
                        "country": "Pakistan",
                        "line1": "street 4"
                    }
                },
                "type": "credit",
                "origin": "international",
                "token": "03d43b25971546e0ab27e8b4698c9b7d"
            },
            "issuer": {
                "id": "mastercard",
                "name": "MasterCard",
                "pictureUrl": "https://static.plexo.com.uy/issuers/4.svg",
                "type": "online"
            },
            "processor": {
                "id": 4,
                "acquirer": "fiserv"
            }
        },
        "installments": 1,
        "amount": {
            "currency": "UYU",
            "total": 147.0,
            "details": {
                "tax": {
                    "type": "17934",
                    "amount": 22.0
                },
                "taxedAmount": 100.0,
                "tipAmount": 25.0,
                "discountAmount": 0.0
            }
        },
        "items": [
            {
                "referenceId": "7c34953392e84949ab511667db0ebef2",
                "name": "prueba",
                "description": "prueba desc",
                "quantity": 1,
                "price": 100.0,
                "discount": 0.0
            }
        ],
        "transactions": [
            {
                "id": "6305dd2e000d6ed5d1ecf79f",
                "uniqueId": "1011910592648278016",
                "parentId": "82ae122c-d235-43bc-a454-fba16b2ae3a4",
                "traceId": "cbf814cd-8b28-4145-ac0b-7381980015e8",
                "referenceId": "e7dbc06224f646ad8e63ec1c6e670a39",
                "type": "purchase",
                "status": "approved",
                "createdAt": "2022-08-24T08:11:26.2893133Z",
                "processedAt": "2022-08-24T08:11:26.2893129Z",
                "resultCode": "0",
                "resultMessage": "You have been mocked",
                "authorization": "1234567890",
                "ticket": "1234567890",
                "amount": 147.0
            }
        ]
      }
    RESPONSE
  end

  def failed_authorize_response
    <<~RESPONSE
      {
        "code": "merchant-not-found",
        "message": "The requested Merchant was not found.",
        "type": "invalid-request-error",
        "status": 400
      }
    RESPONSE
  end

  def successful_capture_response
    <<~RESPONSE
      {
        "id": "62878b1fa450dab85ba2f987",
        "uniqueId": "977187868889886720",
        "parentId": "7c23b951-599f-462e-8a47-6bbbb4dc5ad0",
        "referenceId": "e7dbc06224f646ad8e63ec1c6e670a39",
        "type": "capture",
        "status": "approved",
        "createdAt": "2022-05-20T12:35:43.216Z",
        "processedAt": "2022-05-20T12:35:43.216Z",
        "resultCode": "0",
        "resultMessage": "You have been mocked.",
        "authorization": "12133",
        "ticket": "111111",
        "amount": 147
      }
    RESPONSE
  end

  def failed_capture_response
    <<~RESPONSE
      {
        "code": "internal-error",
        "message": "An internal error occurred. Contact support.",
        "type": "api-error",
        "status": 400
      }
    RESPONSE
  end

  def successful_refund_response
    <<~RESPONSE
      {
        "id": "62878b1fa450dab85ba2f987",
        "uniqueId": "977187868889886720",
        "parentId": "7c23b951-599f-462e-8a47-6bbbb4dc5ad0",
        "referenceId": "e7dbc06224f646ad8e63ec1c6e670a39",
        "type": "refund",
        "status": "approved",
        "resultCode": "0",
        "resultMessage": "You have been mocked.",
        "authorization": "12133",
        "ticket": "111111",
        "amount": 147,
        "reason": "ClientRequest"
      }
    RESPONSE
  end

  def failed_refund_response
    <<~RESPONSE
      {
        "code": "internal-error",
        "message": "An internal error occurred. Contact support.",
        "type": "api-error",
        "status": 400
      }
    RESPONSE
  end

  def successful_void_response
    <<~RESPONSE
      {
        "id": "62878c0fa450dab85ba2f994",
        "uniqueId": "977188875178913792",
        "parentId": "49fe7306-d706-43e4-97cd-8de94683c9ae",
        "referenceId": "e7dbc06224f646ad8e63ec1c6e670a39",
        "type": "cancellation",
        "status": "approved",
        "createdAt": "2022-05-20T12:39:43.134Z",
        "processedAt": "2022-05-20T12:39:43.134Z",
        "resultCode": "0",
        "resultMessage": "You have been mocked.",
        "authorization": "12133",
        "ticket": "111111",
        "amount": 147.0
      }
    RESPONSE
  end

  def failed_void_response
    <<~RESPONSE
      {
        "code": "internal-error",
        "message": "An internal error occurred. Contact support.",
        "type": "api-error",
        "status": 400
      }
    RESPONSE
  end

  def successful_verify_response
    <<~RESPONSE
      {
        "id": "62ac2c5eaf353be57867f977",
        "token": "7220c5cc-4b57-43e6-ae91-3fd3f3e8d49f",
        "referenceId": "e7dbc06224f646ad8e63ec1c6e670a39",
        "status": "approved",
        "processingMethod": "api",
        "browserDetails": {
          "DeviceFingerprint": "12345",
          "IpAddress": "127.0.0.1"
        },
        "createdAt": "2022-06-17T07:25:18.1421498Z",
        "merchant": {
          "id": 3243,
          "name": "spreedly",
          "settings": {
            "id": 41363,
            "issuerId": 4,
            "issuer": {
              "id": 4,
              "code": "mastercard",
              "name": "MASTERCARD",
              "type": "online"
            },
            "metadata": {
              "ProviderCommerceNumber": "153289",
              "TerminalNumber": "1K153289",
              "SoftDescriptor": "VTEX-Testing",
              "PaymentProcessorId": "oca"
            },
            "paymentProcessor": {
              "acquirer": "oca",
              "settings": {
                "commerce": {
                  "fields": [
                    {
                      "name": "ProviderCommerceNumber",
                      "type": 2049
                    },
                    {
                      "name": "TerminalNumber",
                      "type": 2051
                    }
                  ]
                },
                "fingerprint": {
                  "name": "cybersource-oca"
                },
                "fields": [
                  {
                    "name": "Email",
                    "type": 261
                  },
                  {
                    "name": "FirstName",
                    "type": 271
                  },
                  {
                    "name": "LastName",
                    "type": 272
                  },
                  {
                    "name": "CVC",
                    "type": 33154
                  }
                ]
              }
            }
          },
          "clientId": 221
        },
        "client": {
          "id": 221,
          "name": "Spreedly",
          "tier": 2,
          "sessionTimeInSeconds": 36000
        },
        "paymentMethod": {
          "type": "card",
          "card": {
            "name": "555555XXXXXX4444",
            "bin": "555555",
            "last4": "4444",
            "expMonth": 12,
            "expYear": 24,
            "cardholder": {
              "firstName": "Santiago",
              "lastName": "Navatta",
              "email": "snavatta@plexo.com.uy"
            },
            "fingerprint": "36e2219cc4734a61af258905c1c59ba4"
          },
          "issuer": {
            "id": "mastercard",
            "name": "MasterCard",
            "pictureUrl": "https://static.plexo.com.uy/issuers/4.svg",
            "type": "online"
          },
          "processor": {
            "acquirer": "oca"
          }
        },
        "installments": 1,
        "amount": {
          "currency": "UYU",
          "total": 20
        },
        "items": [
          {
            "referenceId": "997d4aafe29b4421ac52a3ddf5b28dfd",
            "name": "card-verification",
            "quantity": 1,
            "price": 20
          }
        ],
        "capture": {
          "method": "manual",
          "delay": 0
        },
        "metadata": {
          "One": "abc"
        },
        "transactions": [
          {
            "id": "62ac2c5eaf353be57867f97b",
            "uniqueId": "987256610059481088",
            "parentId": "7220c5cc-4b57-43e6-ae91-3fd3f3e8d49f",
            "referenceId": "e7dbc06224f646ad8e63ec1c6e670a39",
            "type": "authorization",
            "status": "approved",
            "createdAt": "2022-06-17T07:25:18.1796516Z",
            "processedAt": "2022-06-17T07:25:18.1796366Z",
            "resultCode": "0",
            "resultMessage": "You have been mocked.",
            "authorization": "12133",
            "ticket": "111111",
            "amount": 20
          }
        ]
      }
    RESPONSE
  end

  def failed_verify_response
    <<~RESPONSE
      {
        "code": "invalid-transaction-state",
        "message": "The selected payment state is not valid.",
        "type": "api-error",
        "status": 400
      }
    RESPONSE
  end
end
