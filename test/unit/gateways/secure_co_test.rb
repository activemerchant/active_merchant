require 'test_helper'

class SecureCoTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = SecureCoGateway.new(:username => 'username', :password => 'password', :merchant_account_id => '00000000-0000-0000-0000-000000000000')
    @credit_card = credit_card('4111 1111 1111 1111', :verification_value => '123')
    @amount = 1000

    @options = {}
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal "purchase|9be3566b-5307-4141-9afe-2a47030571cd", response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "authorization|7b97ed99-5077-4c5b-9456-843f63e240fd", response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    authorize_response = @gateway.authorize(@amount, @credit_card, @options)

    @gateway.expects(:ssl_post).returns(successful_capture_response)
    response = @gateway.capture(@amount, authorize_response.authorization, @options)
    assert_success response
    assert_equal "capture-authorization|df564532-74c7-48ac-8f43-0d04623cb6e8", response.authorization
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    authorize_response = @gateway.authorize(@amount, @credit_card, @options)

    @gateway.expects(:ssl_post).returns(failed_capture_response)
    response = @gateway.capture(@amount, authorize_response.authorization, @options)
    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    payment_response = @gateway.purchase(@amount, @credit_card, @options)

    @gateway.expects(:ssl_post).returns(successful_refund_response)
    response = @gateway.refund(@amount, payment_response.authorization, @options)
    assert_success response
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    payment_response = @gateway.purchase(@amount, @credit_card, @options)

    @gateway.expects(:ssl_post).returns(failed_refund_response)
    response = @gateway.refund(@amount, payment_response.authorization, @options)
    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    payment_response = @gateway.purchase(@amount, @credit_card, @options)

    @gateway.expects(:ssl_post).returns(successful_void_response)
    response = @gateway.void(payment_response.authorization, @options)
    assert_success response
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    payment_response = @gateway.purchase(@amount, @credit_card, @options)

    @gateway.expects(:ssl_post).returns(failed_void_response)
    response = @gateway.void(payment_response.authorization, @options)
    assert_failure response
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).twice.returns(successful_authorize_response).then.returns(successful_void_response)
    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_post).twice.returns(successful_authorize_response).then.returns(failed_void_response)
    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    response = @gateway.verify(@credit_card, @options)
    assert_failure response
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal '0123456789012345', response.authorization
  end

  def test_failed_store
    @gateway.expects(:ssl_post).returns(failed_store_response)
    response = @gateway.store(@credit_card, @options)
    assert_failure response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_optional_fields
    stub_comms do
      @gateway.purchase(2000, @credit_card, @options.merge(:currency => 'CAD'))
    end.check_request do |endpoint, data, headers|
      assert_match '<requested-amount currency="CAD">20.00</requested-amount>', data
      assert_match '<account-number>4111111111111111</account-number>', data
      assert_match '<card-security-code>123</card-security-code>', data
      assert_match %r{<request-id>[0-9a-f]{32}<\/request-id>}, data
    end.respond_with(successful_purchase_response)

    stub_comms do
      @gateway.purchase(2000, @credit_card, @options.merge(
        ip: '127.0.0.1',
        request_id: '00000000-0000-0000-0000-000000000000',
        order_id: 'ORDER1234',
        custom_fields: [["field1", "value1"], [:field2, "value2"], ["field three", 3]],
        email: 'test.email@secureco.co',
      ))
    end.check_request do |endpoint, data, headers|
      assert_match '<ip-address>127.0.0.1</ip-address>', data
      assert_match '<request-id>00000000-0000-0000-0000-000000000000</request-id>', data
      assert_match '<order-number>ORDER1234</order-number>', data
      assert_match '<custom-field field-name="field1" field-value="value1"/>', data
      assert_match '<custom-field field-name="field2" field-value="value2"/>', data
      assert_match '<custom-field field-name="field three" field-value="3"/>', data
      assert_match '<email>test.email@secureco.co</email>', data
    end.respond_with(successful_purchase_response)

    stub_comms do
      @gateway.purchase(2000, @credit_card, @options.merge(
        custom_fields: {"field1" => "value1", :field2 => "value2", "field three" => 3},
      ))
    end.check_request do |endpoint, data, headers|
      refute_match %r{<ip-address\b}, data
      refute_match %r{<order-number\b}, data
      assert_match '<custom-field field-name="field1" field-value="value1"/>', data
      assert_match '<custom-field field-name="field2" field-value="value2"/>', data
      assert_match '<custom-field field-name="field three" field-value="3"/>', data
      refute_match %r{<email\b}, data
    end.respond_with(successful_purchase_response)
  end

  def test_refund_purchase
    purchase_response = nil
    stub_comms do
      purchase_response = @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match '<transaction-type>purchase</transaction-type>', data
    end.respond_with(successful_purchase_response)

    stub_comms do
      @gateway.refund(@amount, purchase_response.authorization, @options)
    end.check_request do |endpoint, data, headers|
      assert_match '<transaction-type>refund-purchase</transaction-type>', data
    end.respond_with(successful_refund_response)
  end

  def test_refund_capture
    authorize_response = nil
    stub_comms do
      authorize_response = @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match '<transaction-type>authorization</transaction-type>', data
    end.respond_with(successful_authorize_response)

    capture_response = nil
    stub_comms do
      capture_response = @gateway.capture(@amount, authorize_response.authorization, @options)
    end.check_request do |endpoint, data, headers|
      assert_match '<transaction-type>capture-authorization</transaction-type>', data
    end.respond_with(successful_capture_response)

    stub_comms do
      @gateway.refund(@amount, capture_response.authorization, @options)
    end.check_request do |endpoint, data, headers|
      assert_match '<transaction-type>refund-capture</transaction-type>', data
    end.respond_with(successful_refund_response)
  end

  def test_void_purchase
    purchase_response = nil
    stub_comms do
      purchase_response = @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match '<transaction-type>purchase</transaction-type>', data
    end.respond_with(successful_purchase_response)

    stub_comms do
      @gateway.void(purchase_response.authorization, @options)
    end.check_request do |endpoint, data, headers|
      assert_match '<transaction-type>void-purchase</transaction-type>', data
    end.respond_with(successful_void_response)
  end

  def test_void_authorize
    authorize_response = nil
    stub_comms do
      authorize_response = @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match '<transaction-type>authorization</transaction-type>', data
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.void(authorize_response.authorization, @options)
    end.check_request do |endpoint, data, headers|
      assert_match '<transaction-type>void-authorization</transaction-type>', data
    end.respond_with(successful_void_response)
  end

  def test_void_capture
    authorize_response = nil
    stub_comms do
      authorize_response = @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match '<transaction-type>authorization</transaction-type>', data
    end.respond_with(successful_authorize_response)

    capture_response = nil
    stub_comms do
      capture_response = @gateway.capture(@amount, authorize_response.authorization, @options)
    end.check_request do |endpoint, data, headers|
      assert_match '<transaction-type>capture-authorization</transaction-type>', data
    end.respond_with(successful_capture_response)

    stub_comms do
      @gateway.void(capture_response.authorization, @options)
    end.check_request do |endpoint, data, headers|
      assert_match '<transaction-type>void-capture</transaction-type>', data
    end.respond_with(successful_void_response)
  end

  private

  def pre_scrubbed
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<payment xmlns=\"http://www.elastic-payments.com/schema/payment\">\n<merchant-account-id>00000000-0000-0000-0000-000000000000</merchant-account-id>\n<transaction-type>purchase</transaction-type>\n<payment-methods>\n<payment-method name=\"creditcard\"/>\n</payment-methods>\n<card>\n<account-number>4111111111111111</account-number>\n<card-security-code>123</card-security-code>\n<card-type>visa</card-type>\n<expiration-month>10</expiration-month>\n<expiration-year>2017</expiration-year>\n</card>\n<request-id>353954aa8d386f2e4e2a72b1f3da8cfa</request-id>\n<requested-amount currency=\"AUD\">10.00</requested-amount>\n<entry-mode>ecommerce</entry-mode>\n<account-holder>\n<first-name>Bob</first-name>\n<last-name>Bobsen</last-name>\n</account-holder>\n<order-number>123456</order-number>\n</payment>\n"
  end

  def post_scrubbed
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<payment xmlns=\"http://www.elastic-payments.com/schema/payment\">\n<merchant-account-id>00000000-0000-0000-0000-000000000000</merchant-account-id>\n<transaction-type>purchase</transaction-type>\n<payment-methods>\n<payment-method name=\"creditcard\"/>\n</payment-methods>\n<card>\n<account-number>[FILTERED]</account-number>\n<card-security-code>[FILTERED]</card-security-code>\n<card-type>visa</card-type>\n<expiration-month>10</expiration-month>\n<expiration-year>2017</expiration-year>\n</card>\n<request-id>353954aa8d386f2e4e2a72b1f3da8cfa</request-id>\n<requested-amount currency=\"AUD\">10.00</requested-amount>\n<entry-mode>ecommerce</entry-mode>\n<account-holder>\n<first-name>Bob</first-name>\n<last-name>Bobsen</last-name>\n</account-holder>\n<order-number>123456</order-number>\n</payment>\n"
  end

  def successful_purchase_response
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><payment xmlns=\"http://www.elastic-payments.com/schema/payment\" xmlns:ns2=\"http://www.elastic-payments.com/schema/epa/transaction\" self=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000/payments/9be3566b-5307-4141-9afe-2a47030571cd\"><merchant-account-id ref=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000\">00000000-0000-0000-0000-000000000000</merchant-account-id><transaction-id>9be3566b-5307-4141-9afe-2a47030571cd</transaction-id><request-id>05a03fcbf6eddaab25838e9464f927a8</request-id><transaction-type>purchase</transaction-type><transaction-state>success</transaction-state><completion-time-stamp>2017-02-08T06:42:09.000Z</completion-time-stamp><statuses><status code=\"201.0000\" description=\"3d-acquirer:The resource was successfully created.\" severity=\"information\"/></statuses><requested-amount currency=\"AUD\">10.00</requested-amount><group-transaction-id>9be3566b-5307-4141-9afe-2a47030571cd</group-transaction-id><account-holder><first-name>Bob</first-name><last-name>Bobsen</last-name></account-holder><card-token><token-id>5827377749249125</token-id><masked-account-number>543460******9125</masked-account-number></card-token><order-number>123456</order-number><descriptor></descriptor><payment-methods><payment-method name=\"creditcard\"/></payment-methods><authorization-code>883798</authorization-code><api-id>elastic-api</api-id><entry-mode>ecommerce</entry-mode></payment>"
  end

  def failed_purchase_response
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><payment xmlns=\"http://www.elastic-payments.com/schema/payment\" xmlns:ns2=\"http://www.elastic-payments.com/schema/epa/transaction\" self=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000/payments/e5f466ae-4cb1-44d2-aae5-7b09c626470e\"><merchant-account-id ref=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000\">00000000-0000-0000-0000-000000000000</merchant-account-id><transaction-id>e5f466ae-4cb1-44d2-aae5-7b09c626470e</transaction-id><request-id>22fb726f0ea00bca9334022833c6d97f</request-id><transaction-type>purchase</transaction-type><transaction-state>failed</transaction-state><completion-time-stamp>2017-02-08T06:42:59.000Z</completion-time-stamp><statuses><status code=\"400.1000\" description=\"Luhn Check failed on the credit card number.  Please check your input and try again.  \" severity=\"error\"/></statuses><requested-amount currency=\"AUD\">10.00</requested-amount><group-transaction-id>e5f466ae-4cb1-44d2-aae5-7b09c626470e</group-transaction-id><account-holder><first-name>Bob</first-name><last-name>Bobsen</last-name></account-holder><order-number>123456</order-number><payment-methods><payment-method name=\"creditcard\"/></payment-methods><api-id>elastic-api</api-id><entry-mode>ecommerce</entry-mode></payment>"
  end

  def successful_authorize_response
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><payment xmlns=\"http://www.elastic-payments.com/schema/payment\" xmlns:ns2=\"http://www.elastic-payments.com/schema/epa/transaction\" self=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000/payments/7b97ed99-5077-4c5b-9456-843f63e240fd\"><merchant-account-id ref=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000\">00000000-0000-0000-0000-000000000000</merchant-account-id><transaction-id>7b97ed99-5077-4c5b-9456-843f63e240fd</transaction-id><request-id>5474</request-id><transaction-type>authorization</transaction-type><transaction-state>success</transaction-state><completion-time-stamp>2017-02-08T06:43:45.000Z</completion-time-stamp><statuses><status code=\"201.0000\" description=\"3d-acquirer:The resource was successfully created.\" severity=\"information\"/></statuses><requested-amount currency=\"AUD\">10.00</requested-amount><group-transaction-id>7b97ed99-5077-4c5b-9456-843f63e240fd</group-transaction-id><account-holder><first-name>Bob</first-name><last-name>Bobsen</last-name></account-holder><card-token><token-id>5827377749249125</token-id><masked-account-number>543460******9125</masked-account-number></card-token><order-number>123459</order-number><descriptor></descriptor><authorization-code>749453</authorization-code><api-id>elastic-api</api-id><entry-mode>ecommerce</entry-mode></payment>"
  end

  def failed_authorize_response
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><payment xmlns=\"http://www.elastic-payments.com/schema/payment\" xmlns:ns2=\"http://www.elastic-payments.com/schema/epa/transaction\" self=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000/payments/bdb199a3-e72d-45df-b23a-8971666c2109\"><merchant-account-id ref=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000\">00000000-0000-0000-0000-000000000000</merchant-account-id><transaction-id>bdb199a3-e72d-45df-b23a-8971666c2109</transaction-id><request-id>3430</request-id><transaction-type>authorization</transaction-type><transaction-state>failed</transaction-state><completion-time-stamp>2017-02-08T06:46:05.000Z</completion-time-stamp><statuses><status code=\"400.1018\" description=\"The same Request Id for the Merchant Account is being tried a second time.  Please use another Request Id.  \" severity=\"error\"/></statuses><requested-amount currency=\"AUD\">10.00</requested-amount><account-holder><first-name>Bob</first-name><last-name>Bobsen</last-name></account-holder><card-token><token-id>4643275967361111</token-id><masked-account-number>411111******1111</masked-account-number></card-token><order-number>123459</order-number><api-id>elastic-api</api-id><entry-mode>ecommerce</entry-mode></payment>"
  end

  def successful_capture_response
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><payment xmlns=\"http://www.elastic-payments.com/schema/payment\" xmlns:ns2=\"http://www.elastic-payments.com/schema/epa/transaction\" self=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000/payments/df564532-74c7-48ac-8f43-0d04623cb6e8\"><merchant-account-id ref=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000\">00000000-0000-0000-0000-000000000000</merchant-account-id><transaction-id>df564532-74c7-48ac-8f43-0d04623cb6e8</transaction-id><request-id>6486</request-id><transaction-type>capture-authorization</transaction-type><transaction-state>success</transaction-state><completion-time-stamp>2017-02-08T06:46:27.000Z</completion-time-stamp><statuses><status code=\"201.0000\" description=\"3d-acquirer:The resource was successfully created.\" severity=\"information\"/></statuses><requested-amount currency=\"AUD\">10.00</requested-amount><parent-transaction-id>a3ae6518-d6d7-4490-845e-113c85e594ac</parent-transaction-id><group-transaction-id>a3ae6518-d6d7-4490-845e-113c85e594ac</group-transaction-id><account-holder><first-name>Bob</first-name><last-name>Bobsen</last-name></account-holder><card-token><token-id>4643275967361111</token-id><masked-account-number>411111******1111</masked-account-number></card-token><order-number>123459</order-number><payment-methods><payment-method name=\"creditcard\"/></payment-methods><authorization-code>717741</authorization-code><api-id>elastic-api</api-id><entry-mode>ecommerce</entry-mode></payment>"
  end

  def failed_capture_response
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><payment xmlns=\"http://www.elastic-payments.com/schema/payment\" xmlns:ns2=\"http://www.elastic-payments.com/schema/epa/transaction\" self=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000/payments/a3d6219b-e0a4-48e7-95ad-41ef60e7cb27\"><merchant-account-id ref=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000\">00000000-0000-0000-0000-000000000000</merchant-account-id><transaction-id>a3d6219b-e0a4-48e7-95ad-41ef60e7cb27</transaction-id><request-id>9862</request-id><transaction-type>capture-authorization</transaction-type><transaction-state>failed</transaction-state><completion-time-stamp>2017-02-08T06:46:55.000Z</completion-time-stamp><statuses><status code=\"400.1027\" description=\"The Requested Amount exceeds the Parent Transaction Amount.  Please check your input and try again.\" severity=\"error\"/></statuses><requested-amount currency=\"AUD\">11.00</requested-amount><parent-transaction-id>0498b007-6f27-4fdf-ae4b-fc4c4b071bdb</parent-transaction-id><group-transaction-id>0498b007-6f27-4fdf-ae4b-fc4c4b071bdb</group-transaction-id><account-holder><first-name>Bob</first-name><last-name>Bobsen</last-name></account-holder><card-token><token-id>4643275967361111</token-id><masked-account-number>411111******1111</masked-account-number></card-token><order-number>123459</order-number><payment-methods><payment-method name=\"creditcard\"/></payment-methods><api-id>elastic-api</api-id><entry-mode>ecommerce</entry-mode></payment>"
  end

  def successful_refund_response
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><payment xmlns=\"http://www.elastic-payments.com/schema/payment\" xmlns:ns2=\"http://www.elastic-payments.com/schema/epa/transaction\" self=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000/payments/fe701d6a-f6d4-406f-b41d-e7b5115ceb91\"><merchant-account-id ref=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000\">00000000-0000-0000-0000-000000000000</merchant-account-id><transaction-id>fe701d6a-f6d4-406f-b41d-e7b5115ceb91</transaction-id><request-id>7417d41b4c22159893c47dd0ab1c691a</request-id><transaction-type>refund-purchase</transaction-type><transaction-state>success</transaction-state><completion-time-stamp>2017-02-08T06:47:27.000Z</completion-time-stamp><statuses><status code=\"201.0000\" description=\"3d-acquirer:The resource was successfully created.\" severity=\"information\"/></statuses><requested-amount currency=\"AUD\">1.20</requested-amount><parent-transaction-id>6f8cc744-b500-4e95-9eeb-c4f45c40a3eb</parent-transaction-id><group-transaction-id>6f8cc744-b500-4e95-9eeb-c4f45c40a3eb</group-transaction-id><account-holder><first-name>Bob</first-name><last-name>Bobsen</last-name></account-holder><card-token><token-id>4643275967361111</token-id><masked-account-number>411111******1111</masked-account-number></card-token><order-number>123456</order-number><payment-methods><payment-method name=\"creditcard\"/></payment-methods><authorization-code>227450</authorization-code><api-id>elastic-api</api-id><entry-mode>ecommerce</entry-mode></payment>"
  end

  def failed_refund_response
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><payment xmlns=\"http://www.elastic-payments.com/schema/payment\" xmlns:ns2=\"http://www.elastic-payments.com/schema/epa/transaction\" self=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000/payments/19503d44-517b-4077-945e-f6a432ac18c6\"><merchant-account-id ref=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000\">00000000-0000-0000-0000-000000000000</merchant-account-id><transaction-id>19503d44-517b-4077-945e-f6a432ac18c6</transaction-id><request-id>40bb232fe138f8dfa7dc6457d9594436</request-id><transaction-type>refund-purchase</transaction-type><transaction-state>failed</transaction-state><completion-time-stamp>2017-02-08T06:47:55.000Z</completion-time-stamp><statuses><status code=\"400.1027\" description=\"The Requested Amount exceeds the Parent Transaction Amount.  Please check your input and try again.\" severity=\"error\"/></statuses><requested-amount currency=\"AUD\">11.00</requested-amount><parent-transaction-id>537f4e4b-6412-4c9a-b2ca-69e72ae8faea</parent-transaction-id><group-transaction-id>537f4e4b-6412-4c9a-b2ca-69e72ae8faea</group-transaction-id><account-holder><first-name>Bob</first-name><last-name>Bobsen</last-name></account-holder><card-token><token-id>4643275967361111</token-id><masked-account-number>411111******1111</masked-account-number></card-token><order-number>123456</order-number><payment-methods><payment-method name=\"creditcard\"/></payment-methods><api-id>elastic-api</api-id><entry-mode>ecommerce</entry-mode></payment>"
  end

  def successful_void_response
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><payment xmlns=\"http://www.elastic-payments.com/schema/payment\" xmlns:ns2=\"http://www.elastic-payments.com/schema/epa/transaction\" self=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000/payments/15a3d4fd-53b5-4d80-85d6-bc1a433ef45f\"><merchant-account-id ref=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000\">00000000-0000-0000-0000-000000000000</merchant-account-id><transaction-id>15a3d4fd-53b5-4d80-85d6-bc1a433ef45f</transaction-id><request-id>4cf98d421fa2e139daa08e388eb3111f</request-id><transaction-type>void-authorization</transaction-type><transaction-state>success</transaction-state><completion-time-stamp>2017-02-08T06:48:24.000Z</completion-time-stamp><statuses><status code=\"201.0000\" description=\"3d-acquirer:The resource was successfully created.\" severity=\"information\"/></statuses><requested-amount currency=\"AUD\">10.00</requested-amount><parent-transaction-id>e8bba7a9-2aa5-4a00-8406-aef710f579ed</parent-transaction-id><group-transaction-id>e8bba7a9-2aa5-4a00-8406-aef710f579ed</group-transaction-id><account-holder><first-name>Bob</first-name><last-name>Bobsen</last-name></account-holder><card-token><token-id>4643275967361111</token-id><masked-account-number>411111******1111</masked-account-number></card-token><order-number>123459</order-number><payment-methods><payment-method name=\"creditcard\"/></payment-methods><api-id>elastic-api</api-id><entry-mode>ecommerce</entry-mode></payment>"
  end

  def failed_void_response
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><payment xmlns=\"http://www.elastic-payments.com/schema/payment\" xmlns:ns2=\"http://www.elastic-payments.com/schema/epa/transaction\" self=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000/payments/ad384180-c260-4fe6-9e2d-ee3de2531e12\"><merchant-account-id ref=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000\">00000000-0000-0000-0000-000000000000</merchant-account-id><transaction-id>ad384180-c260-4fe6-9e2d-ee3de2531e12</transaction-id><request-id>e33846c3f689389368fca3df85ccbf39</request-id><transaction-type>void-authorization</transaction-type><transaction-state>failed</transaction-state><completion-time-stamp>2017-02-08T06:50:15.000Z</completion-time-stamp><statuses><status code=\"400.1027\" description=\"The Requested Amount exceeds the Parent Transaction Amount.  Please check your input and try again.\" severity=\"error\"/></statuses><requested-amount currency=\"AUD\">10.00</requested-amount><parent-transaction-id>8526239f-7eff-4475-9f5c-2072a06b08e8</parent-transaction-id><group-transaction-id>8526239f-7eff-4475-9f5c-2072a06b08e8</group-transaction-id><account-holder><first-name>Bob</first-name><last-name>Bobsen</last-name></account-holder><card-token><token-id>4643275967361111</token-id><masked-account-number>411111******1111</masked-account-number></card-token><order-number>123459</order-number><payment-methods><payment-method name=\"creditcard\"/></payment-methods><api-id>elastic-api</api-id><entry-mode>ecommerce</entry-mode></payment>"
  end

  def successful_store_response
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><payment xmlns=\"http://www.elastic-payments.com/schema/payment\" xmlns:ns2=\"http://www.elastic-payments.com/schema/epa/transaction\" self=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000/payments/f8400a22-a297-4c3b-9a17-444cba1b1922\"><merchant-account-id ref=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000\">00000000-0000-0000-0000-000000000000</merchant-account-id><transaction-id>f8400a22-a297-4c3b-9a17-444cba1b1922</transaction-id><request-id>3af710ac318c324d19c1826dcbb3c318</request-id><transaction-type>tokenize</transaction-type><transaction-state>success</transaction-state><completion-time-stamp>2017-02-16T00:00:40.000Z</completion-time-stamp><statuses><status code=\"201.0000\" description=\"The resource was successfully created.\" severity=\"information\"/></statuses><account-holder><first-name>Bob</first-name><last-name>Bobsen</last-name></account-holder><card-token><token-id>0123456789012345</token-id><masked-account-number>411111******1111</masked-account-number></card-token><api-id>elastic-api</api-id><entry-mode>ecommerce</entry-mode></payment>"
  end

  def failed_store_response
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><payment xmlns=\"http://www.elastic-payments.com/schema/payment\" xmlns:ns2=\"http://www.elastic-payments.com/schema/epa/transaction\" self=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000/payments/4c4bd5f0-bf42-4b28-96c1-154824441e66\"><merchant-account-id ref=\"http://localhost/engine/rest/merchants/00000000-0000-0000-0000-000000000000\">00000000-0000-0000-0000-000000000000</merchant-account-id><transaction-id>4c4bd5f0-bf42-4b28-96c1-154824441e66</transaction-id><request-id>1009004dc9a3289e4530f7f2032dd9ee</request-id><transaction-type>tokenize</transaction-type><transaction-state>failed</transaction-state><completion-time-stamp>2017-02-15T23:54:34.000Z</completion-time-stamp><statuses><status code=\"400.1005\" description=\"The Card Type has not been provided or is incorrect.\" severity=\"warning\"/></statuses><account-holder><first-name>Bob</first-name><last-name>Bobsen</last-name></account-holder><api-id>elastic-api</api-id><entry-mode>ecommerce</entry-mode></payment>"
  end
end
