require 'test_helper'

class DecidirPlusTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = DecidirPlusGateway.new(public_key: 'public_key', private_key: 'private_key')
    @credit_card = credit_card
    @payment_reference = '2bf7bffb-1257-4b45-8d42-42d090409b8a|448459'
    @amount = 100

    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }

    @sub_payments = [
      {
        site_id: '04052018',
        installments: 1,
        amount: 1500
      },
      {
        site_id: '04052018',
        installments: 1,
        amount: 1500
      }
    ]
    @fraud_detection = {
      send_to_cs: false,
      channel: 'Web',
      dispatch_method: 'Store Pick Up',
      csmdds: [
        {
          code: 17,
          description: 'Campo MDD17'
        }
      ]
    }
  end

  def test_successful_purchase
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @payment_reference, @options)
    end.check_request do |_action, _endpoint, data, _headers|
      assert_match(/2bf7bffb-1257-4b45-8d42-42d090409b8a/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_failed_purchase
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(failed_purchase_response)

    assert_failure response
  end

  def test_failed_purchase_response
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(failed_purchase_message_response)

    assert_failure response
    assert_equal response.message, 'invalid_card: TRANS. NO PERMITIDA'
  end

  def test_successful_capture
    authorization = '12420186'
    stub_comms(@gateway, :ssl_request) do
      @gateway.capture(@amount, authorization)
    end.check_request do |_action, endpoint, data, _headers|
      request = JSON.parse(data)
      assert_includes endpoint, "payments/#{authorization}"
      assert_equal @amount, request['amount']
    end.respond_with(successful_purchase_response)
  end

  def test_failed_authorize
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal response.error_code, response.params['status_details']['error']['reason']['id']
  end

  def test_successful_refund
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.refund(@amount, @payment_reference)
    end.respond_with(successful_refund_response)

    assert_success response
  end

  def test_failed_refund
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.refund(@amount, @payment_reference)
    end.respond_with(failed_purchase_response)

    assert_failure response
  end

  def test_successful_store
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.store(@credit_card, @options)
    end.check_request do |_action, _endpoint, data, _headers|
      assert_match(/#{@credit_card.number}/, data)
      assert_match(/#{@credit_card.name}/, data)
    end.respond_with(successful_store_response)

    assert_success response
  end

  def test_successful_store_with_additional_data_validation
    options = {
      card_holder_identification_type: 'dni',
      card_holder_identification_number: '44567890',
      card_holder_door_number: '348',
      card_holder_birthday: '01012017'
    }
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.store(@credit_card, options)
    end.check_request do |_action, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal(options[:card_holder_identification_type], request['card_holder_identification']['type'])
      assert_equal(options[:card_holder_identification_number], request['card_holder_identification']['number'])
      assert_equal(options[:card_holder_door_number].to_i, request['card_holder_door_number'])
      assert_equal(options[:card_holder_birthday], request['card_holder_birthday'])
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_unstore
    token_id = '3d5992f9-90f8-4ac4-94dd-6baa7306941f'
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.unstore(token_id)
    end.check_request do |_action, endpoint, data, _headers|
      assert_includes endpoint, "cardtokens/#{token_id}"
      assert_empty JSON.parse(data)
    end.respond_with(successful_unstore_response)

    assert_success response
  end

  def test_successful_purchase_with_options
    options = @options.merge(sub_payments: @sub_payments)
    options[:installments] = 4
    options[:payment_type] = 'distributed'
    options[:debit] = 'true'
    options[:card_brand] = 'visa_debit'

    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @payment_reference, options)
    end.check_request do |_action, _endpoint, data, _headers|
      assert_equal(@sub_payments, JSON.parse(data, symbolize_names: true)[:sub_payments])
      assert_match(/#{options[:installments]}/, data)
      assert_match(/#{options[:payment_type]}/, data)
      assert_match(/\"payment_method_id\":31/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_fraud_detection
    options = @options.merge(fraud_detection: @fraud_detection)

    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @payment_reference, options)
    end.check_request do |_action, _endpoint, data, _headers|
      assert_equal(@fraud_detection, JSON.parse(data, symbolize_names: true)[:fraud_detection])
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_establishment_name
    establishment_name = 'Heavenly Buffaloes'
    options = @options.merge(establishment_name: establishment_name)

    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @payment_reference, options)
    end.check_request do |_action, _endpoint, data, _headers|
      assert_equal(establishment_name, JSON.parse(data)['establishment_name'])
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_aggregate_data
    aggregate_data = {
      indicator: '1',
      identification_number: '308103480',
      bill_to_pay: 'test1',
      bill_to_refund: 'test2',
      merchant_name: 'Heavenly Buffaloes',
      street: 'Sesame',
      number: '123',
      postal_code: '22001',
      category: 'yum',
      channel: '005',
      geographic_code: 'C1234',
      city: 'Ciudad de Buenos Aires',
      merchant_id: 'dec_agg',
      province: 'Buenos Aires',
      country: 'Argentina',
      merchant_email: 'merchant@mail.com',
      merchant_phone: '2678433111'
    }
    options = @options.merge(aggregate_data: aggregate_data)

    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @payment_reference, options)
    end.check_request do |_action, _endpoint, data, _headers|
      assert_equal(aggregate_data, JSON.parse(data, symbolize_names: true)[:aggregate_data])
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_fraud_detection_without_csmdds
    @fraud_detection.delete(:csmdds)
    options = @options.merge(fraud_detection: @fraud_detection)

    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @payment_reference, options)
    end.check_request do |_action, _endpoint, data, _headers|
      fraud_detection_fields = JSON.parse(data, symbolize_names: true)[:fraud_detection]
      assert_equal(@fraud_detection, fraud_detection_fields)
      assert_nil fraud_detection_fields[:csmdds]
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_void
    authorization = '418943'
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.void(authorization)
    end.check_request do |_action, endpoint, data, _headers|
      assert_includes endpoint, "payments/#{authorization}/refunds"
      assert_equal '{}', data
    end.respond_with(successful_void_response)

    assert_success response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      opening connection to developers.decidir.com:443...
      opened
      starting SSL for developers.decidir.com:443...
      SSL established
      <- "POST /api/v2/tokens HTTP/1.1\r\nContent-Type: application/json\r\nApikey: 96e7f0d36a0648fb9a8dcb50ac06d260\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: developers.decidir.com\r\nContent-Length: 207\r\n\r\n"
      <- "{\"card_number\":\"4484590159923090\",\"card_expiration_month\":\"09\",\"card_expiration_year\":\"22\",\"security_code\":\"123\",\"card_holder_name\":\"Longbob Longsen\",\"card_holder_identification\":{\"type\":null,\"number\":null}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 342\r\n"
      -> "Connection: close\r\n"
      -> "Date: Wed, 15 Dec 2021 15:04:23 GMT\r\n"
      -> "vary: Origin\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "X-Kong-Upstream-Latency: 42\r\n"
      -> "X-Kong-Proxy-Latency: 2\r\n"
      -> "Via: kong/2.0.5\r\n"
      -> "Strict-Transport-Security: max-age=16070400; includeSubDomains\r\n"
      -> "Set-Cookie: TS017a11a6=012e46d8ee3b62f63065925e2c71ee113cba96e0166c66ac2397184d6961bbe2cd1b41d64f6ee14cb9d440cf66a097465e0a31a786; Path=/; Domain=.developers.decidir.com\r\n"
      -> "\r\n"
      reading 342 bytes...
      -> "{\"id\":\"2e416527-b757-47e1-80e1-51b2cb77092f\",\"status\":\"active\",\"card_number_length\":16,\"date_created\":\"2021-12-14T16:20Z\",\"bin\":\"448459\",\"last_four_digits\":\"3090\",\"security_code_length\":3,\"expiration_month\":9,\"expiration_year\":22,\"date_due\":\"2021-12-14T16:35Z\",\"cardholder\":{\"identification\":{\"type\":\"\",\"number\":\"\"},\"name\":\"Longbob Longsen\"}}"
      read 342 bytes
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to developers.decidir.com:443...
      opened
      starting SSL for developers.decidir.com:443...
      SSL established
      <- "POST /api/v2/tokens HTTP/1.1\r\nContent-Type: application/json\r\nApikey: [FILTERED]\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: developers.decidir.com\r\nContent-Length: 207\r\n\r\n"
      <- "{\"card_number\":\"[FILTERED]",\"card_expiration_month\":\"09\",\"card_expiration_year\":\"22\",\"security_code\":\"[FILTERED]",\"card_holder_name\":\"Longbob Longsen\",\"card_holder_identification\":{\"type\":null,\"number\":null}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 342\r\n"
      -> "Connection: close\r\n"
      -> "Date: Wed, 15 Dec 2021 15:04:23 GMT\r\n"
      -> "vary: Origin\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "X-Kong-Upstream-Latency: 42\r\n"
      -> "X-Kong-Proxy-Latency: 2\r\n"
      -> "Via: kong/2.0.5\r\n"
      -> "Strict-Transport-Security: max-age=16070400; includeSubDomains\r\n"
      -> "Set-Cookie: TS017a11a6=012e46d8ee3b62f63065925e2c71ee113cba96e0166c66ac2397184d6961bbe2cd1b41d64f6ee14cb9d440cf66a097465e0a31a786; Path=/; Domain=.developers.decidir.com\r\n"
      -> "\r\n"
      reading 342 bytes...
      -> "{\"id\":\"2e416527-b757-47e1-80e1-51b2cb77092f\",\"status\":\"active\",\"card_number_length\":16,\"date_created\":\"2021-12-14T16:20Z\",\"bin\":\"448459\",\"last_four_digits\":\"3090\",\"security_code_length\":3,\"expiration_month\":9,\"expiration_year\":22,\"date_due\":\"2021-12-14T16:35Z\",\"cardholder\":{\"identification\":{\"type\":\"\",\"number\":\"\"},\"name\":\"Longbob Longsen\"}}"
      read 342 bytes
      Conn close
    )
  end

  def successful_store_response
    %{
      {\"id\":\"cd4ba1c0-4b41-4c5c-8530-d0c757df8603\",\"status\":\"active\",\"card_number_length\":16,\"date_created\":\"2022-01-07T17:37Z\",\"bin\":\"448459\",\"last_four_digits\":\"3090\",\"security_code_length\":3,\"expiration_month\":9,\"expiration_year\":23,\"date_due\":\"2022-01-07T17:52Z\",\"cardholder\":{\"identification\":{\"type\":\"\",\"number\":\"\"},\"name\":\"Longbob Longsen\"}}
    }
  end

  def successful_unstore_response; end

  def successful_purchase_response
    %{
      {\"id\":12232003,\"site_transaction_id\":\"d80cb4c7430b558cb9362b7bb89d2d38\",\"payment_method_id\":1,\"card_brand\":\"Visa\",\"amount\":100,\"currency\":\"ars\",\"status\":\"approved\",\"status_details\":{\"ticket\":\"4588\",\"card_authorization_code\":\"173710\",\"address_validation_code\":\"VTE0011\",\"error\":null},\"date\":\"2022-01-07T17:37Z\",\"customer\":null,\"bin\":\"448459\",\"installments\":1,\"first_installment_expiration_date\":null,\"payment_type\":\"single\",\"sub_payments\":[],\"site_id\":\"99999999\",\"fraud_detection\":null,\"aggregate_data\":null,\"establishment_name\":null,\"spv\":null,\"confirmed\":null,\"pan\":\"48d2eeca7a9041dc4b2008cf495bc5a8c4\",\"customer_token\":null,\"card_data\":\"/tokens/12232003\",\"token\":\"cd4ba1c0-4b41-4c5c-8530-d0c757df8603\"}
    }
  end

  def failed_purchase_response
    %{
      {\"error_type\":\"invalid_request_error\",\"validation_errors\":[{\"code\":\"invalid_param\",\"param\":\"site_transaction_id\"}]}
    }
  end

  def failed_purchase_message_response
    %{
      {\"id\":552537664,\"site_transaction_id\":\"9a59630fd51de97fbd8390adf796c683\",\"payment_method_id\":1,\"card_brand\":\"Visa\",\"amount\":74416,\"currency\":\"ars\",\"status\":\"rejected\",\"status_details\":{\"ticket\":\"2\",\"card_authorization_code\":\"\",\"address_validation_code\":\"VTE0000\",\"error\":{\"type\":\"invalid_card\",\"reason\":{\"id\":57,\"description\":\"TRANS. NO PERMITIDA\",\"additional_description\":\"\"}}},\"date\":\"2022-02-07T10:16Z\",\"customer\":null,\"bin\":\"466057\",\"installments\":1,\"first_installment_expiration_date\":null,\"payment_type\":\"single\",\"sub_payments\":[],\"site_id\":\"92003011\",\"fraud_detection\":{\"status\":null},\"aggregate_data\":null,\"establishment_name\":null,\"spv\":null,\"confirmed\":null,\"pan\":null,\"customer_token\":null,\"card_data\":\"/tokens/552537664\",\"token\":\"ea1bde57-5bdf-4f58-8586-df45c4359664\"}
    }
  end

  def successful_refund_response
    %{
      {\"id\":417921,\"amount\":100,\"sub_payments\":null,\"error\":null,\"status\":\"approved\",\"status_details\":{\"ticket\":\"4589\",\"card_authorization_code\":\"173711\",\"address_validation_code\":\"VTE0011\",\"error\":null}}
    }
  end

  def failed_refund_response
    %{
      {\"error_type\":\"not_found_error\",\"entity_name\":\"\",\"id\":\"\"}
    }
  end

  def failed_authorize_response
    %{
      {\"id\": 12516088,  \"site_transaction_id\": \"e77f40284fd5e0fba8e8ef7d1b784c5e\",  \"payment_method_id\": 1,  \"card_brand\": \"Visa\",  \"amount\": 100,  \"currency\": \"ars\",  \"status\": \"rejected\",  \"status_details\": {    \"ticket\": \"393\",    \"card_authorization_code\": \"\",    \"address_validation_code\": \"VTE0000\",    \"error\": {      \"type\": \"invalid_card\",      \"reason\": {        \"id\": 3,        \"description\": \"COMERCIO INVALIDO\",        \"additional_description\": \"\"      }    }  },  \"date\": \"2022-03-21T13:08Z\",  \"customer\": null,  \"bin\": \"400030\",  \"installments\": 1,  \"first_installment_expiration_date\": null,  \"payment_type\": \"single\",  \"sub_payments\": [],  \"site_id\": \"92002480\",  \"fraud_detection\": {    \"status\": null  },  \"aggregate_data\": null,  \"establishment_name\": null,  \"spv\": null,  \"confirmed\": null,  \"pan\": null,  \"customer_token\": null,  \"card_data\": \"/tokens/12516088\",  \"token\": \"058972ba-4235-4452-bfdf-fc9f61e2c0f9\"}
    }
  end

  def successful_void_response
    %{
      {"id":418966,"amount":100,"sub_payments":null,"error":null,"status":"approved","status_details":{"ticket":"4630","card_authorization_code":"074206","address_validation_code":"VTE0011","error":null}}
    }
  end

  def successful_verify_response
    %{
      {"id":12421487,"site_transaction_id":"e6936a3fbc65cfa1fded1e84d4bbeaf9","payment_method_id":1,"card_brand":"Visa","amount":100,"currency":"ars","status":"approved","status_details":{"ticket":"4747","card_authorization_code":"094329","address_validation_code":"VTE0011","error":null},"date":"2022-01-20T09:43Z","customer":null,"bin":"448459","installments":1,"first_installment_expiration_date":null,"payment_type":"single","sub_payments":[],"site_id":"99999999","fraud_detection":null,"aggregate_data":null,"establishment_name":null,"spv":null,"confirmed":null,"pan":"48d2eeca7a9041dc4b2008cf495bc5a8c4","customer_token":null,"card_data":"/tokens/12421487","token":"a36cadd5-5b06-41f5-972d-fffd524e2a35"}
    }
  end
end
