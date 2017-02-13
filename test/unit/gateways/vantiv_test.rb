require "test_helper"

class VantivTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.mode = :test

    @merchant_id = "merchant_id"

    @gateway = VantivGateway.new(
      login: "login",
      password: "password",
      merchant_id: @merchant_id
    )

    # String returned from AM Gateway as Vantiv "authorization"
    @authorize_authorization = "100000000000000001;authorization;100"
    @authorize_authorization_invalid_id = "123456789012345360;authorization;100"
    @capture_authorization = "100000000000000002;capture;100"
    @invalid_authorization = "12345;invalid-authorization;0"
    @refund_authorization = "123456789012345360;credit;100"
    @purchase_authorization = "100000000000000006;sale;100"

    @credit_card = credit_card
    @apple_pay = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new(
      {
        month: "01",
        year: "2012",
        brand: "visa",
        number: "44444444400009",
        payment_cryptogram: "BwABBJQ1AgAAAAAgJDUCAAAAAAA="
      }
    )

    @paypage_id = "cDZJcmd1VjNlYXNaSlRMTGpocVZQY1NNlYE4ZW5UTko4NU9KK3" \
                  "p1L1p1VzE4ZWVPQVlSUHNITG1JN2I0NzlyTg="

    @token = ActiveMerchant::Billing::VantivGateway::Token.new(
      "1234123412341234",
      month: "01",
      verification_value: "098",
      year: "2020"
    )

    @amount = 100
    @options = {}
  end

  ## authorize
  def test_authorize__credit_card_failed
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(_response_authorize__credit_card_failed)

    assert_failure response
    assert_equal "110", response.params["response"]
    assert_equal "Insufficient Funds", response.message
  end

  def test_authorize__credit_card_request
    stub_commit do |_, data, _|
      assert_match %r(<authorization .*</authorization>)m, data
      assert_match %r(<orderId>this-must-be-truncated--</orderId>), data
      assert_match %r(<amount>#{@amount}</amount>), data
      assert_match %r(<orderSource>ecommerce</orderSource>), data
      # address nodes
      assert_match %r(<billToAddress>.*</billToAddress>)m, data
      assert_match %r(<name>Longbob Longsen</name>), data
      assert_match %r(<firstName>Longbob</firstName>), data
      assert_match %r(<lastName>Longsen</lastName>), data
      # card nodes
      assert_match %r(<card>.*</card>)m, data
      assert_match %r(<type>VI</type>), data
      assert_match %r(<number>4242424242424242</number>), data
      assert_match %r(<expDate>0918</expDate>), data
      assert_match %r(<cardValidationNum>123</cardValidationNum>), data
      # nodes that shouldn't be present by default
      assert_no_match %r(<shipToAddress>), data
      assert_no_match %r(<pos>), data
      assert_no_match %r(<customBilling>), data
      assert_no_match %r(<debtRepayment>), data
    end

    @gateway.authorize(
      @amount,
      @credit_card,
      order_id: "this-must-be-truncated--to-24-chars"
    )
  end

  def test_authorize__credit_card_request_with_debt_repayment
    stub_commit do |_, data, _|
      assert_match %r(<authorization .*</authorization>)m, data
      assert_match %r(<debtRepayment>true</debtRepayment>), data
    end

    @gateway.authorize(@amount, @credit_card, debt_repayment: true)
  end

  def test_authorize__credit_card_request_with_descriptor
    stub_commit do |_, data, _|
      assert_match %r(<authorization .*</authorization>)m, data
      assert_match %r(<customBilling>.*<descriptor>Name</descriptor>)m, data
      assert_match %r(<customBilling>.*<phone>Phone</phone>)m, data
    end

    @gateway.authorize(
      @amount,
      @credit_card,
      descriptor_name: "Name",
      descriptor_phone: "Phone"
    )
  end

  def test_authorize__credit_card_request_with_order_source
    stub_commit do |_, data, _|
      assert_match %r(<authorization .*</authorization>)m, data
      assert_match %r(<orderSource>some-order-source</orderSource>), data
    end

    @gateway.authorize(@amount, @credit_card, order_source: "some-order-source")
  end

  def test_authorize__credit_card_request_with_track_data
    @credit_card.track_data = "credit-card-track-data"

    stub_commit do |_, data, _|
      assert_match %r(<authorization .*</authorization>)m, data
      assert_match(
        %r(<card>.*<track>credit-card-track-data</track>.*</card>)m,
        data
      )
      assert_match %r(<orderSource>retail</orderSource>), data
      assert_match %r(<pos>.+<\/pos>)m, data
    end

    @gateway.authorize(@amount, @credit_card)
  end

  def test_authorize__token_request
    stub_commit do |_, data, _|
      assert_match %r(<authorization .*</authorization>)m, data
      assert_match %r(<orderId>this-must-be-truncated--</orderId>), data
      assert_match %r(<amount>#{@amount}</amount>), data
      assert_match %r(<orderSource>ecommerce</orderSource>), data
      # token nodes
      assert_match %r(<token>.*</token>)m, data
      assert_match %r(<litleToken>1234123412341234</litleToken>), data
      assert_match %r(<expDate>0120</expDate>), data
      assert_match %r(<cardValidationNum>098</cardValidationNum>), data
      # nodes that shouldn't be present by default
      assert_no_match %r(<billToAddress>)m, data
      assert_no_match %r(<shipToAddress>), data
      assert_no_match %r(<pos>), data
      assert_no_match %r(<customBilling>), data
      assert_no_match %r(<debtRepayment>), data
    end

    @gateway.authorize(
      @amount,
      @token,
      order_id: "this-must-be-truncated--to-24-chars"
    )
  end

  ## capture
  def test_capture__authorization_request
    stub_commit do |_, data, _|
      assert_match %r(<capture .*</capture>)m, data
      assert_match %r(<litleTxnId>100000000000000001</litleTxnId>), data
      assert_match %r(<amount>#{@amount}</amount>), data
    end

    @gateway.capture(@amount, @authorize_authorization)
  end

  def test_capture__authorization_request_without_amount
    stub_commit do |_, data, _|
      assert_match %r(<capture .*</capture>)m, data
      assert_match %r(<litleTxnId>100000000000000001</litleTxnId>), data
      assert_no_match %r(<amount>.*</amount>), data
    end

    @gateway.capture(nil, @authorize_authorization)
  end

  def test_capture__credit_card_failed
    response = stub_comms do
      @gateway.capture(@amount, @credit_card)
    end.respond_with(_response_capture__credit_card_failed)

    assert_failure response
    assert_equal "360", response.params["response"]
    assert_equal(
      "No transaction found with specified litleTxnId",
      response.message
    )
  end

  def test_capture__credit_card_successful
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(_response_authorize__credit_card_successful)

    assert_success response

    assert_equal "100000000000000001;authorization;100", response.authorization
    assert response.test?

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/100000000000000001/, data)
    end.respond_with(_response_capture__credit_card_successful)

    assert_success capture
    assert_equal "100000000000000002;capture;100", capture.authorization
    assert capture.test?
  end

  ## purchase
  def test_purchase__apple_pay_request_order_source
    stub_commit do |_, data, _|
      assert_match "<orderSource>applepay</orderSource>", data
    end

    @gateway.purchase(@amount, @apple_pay)
  end

  def test_purchase__apple_pay_request_payment_cryptogram
    stub_commit do |_, data, _|
      assert_match(/BwABBJQ1AgAAAAAgJDUCAAAAAAA=/, data)
    end

    @gateway.purchase(@amount, @apple_pay)
  end

  def test_purchase__credit_card_failed
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(_response_purchase__credit_card_failed)

    assert_failure response
    assert_equal "110", response.params["response"]
    assert_equal "Insufficient Funds", response.message
    assert response.test?
  end

  def test_purchase__credit_card_request
    stub_commit do |_, data, _|
      assert_match %r(<sale .*</sale>)m, data
      assert_match %r(<orderId>this-must-be-truncated--</orderId>), data
      assert_match %r(<amount>#{@amount}</amount>), data
      assert_match %r(<orderSource>ecommerce</orderSource>), data
      # address nodes
      assert_match %r(<billToAddress>.*</billToAddress>)m, data
      assert_match %r(<name>Longbob Longsen</name>), data
      assert_match %r(<firstName>Longbob</firstName>), data
      assert_match %r(<lastName>Longsen</lastName>), data
      # card nodes
      assert_match %r(<card>.*</card>)m, data
      assert_match %r(<type>VI</type>), data
      assert_match %r(<number>4242424242424242</number>), data
      assert_match %r(<expDate>0918</expDate>), data
      assert_match %r(<cardValidationNum>123</cardValidationNum>), data
      # nodes that shouldn't be present by default
      assert_no_match %r(<shipToAddress>), data
      assert_no_match %r(<pos>), data
      assert_no_match %r(<customBilling>), data
      assert_no_match %r(<debtRepayment>), data
    end

    @gateway.purchase(
      @amount,
      @credit_card,
      order_id: "this-must-be-truncated--to-24-chars"
    )
  end

  def test_purchase__credit_card_request_with_billing_address
    stub_commit do |_, data, _|
      assert_match %r(<sale .*</sale>)m, data
      assert_match(
        %r(<billToAddress>.*Longbob Longsen.*Longbob.*Longsen)m,
        data
      )
      assert_match(
        %r(<billToAddress>.*456.*Apt 1.*Otta.*ON.*K1C.*CA.*555-5.*Widgets)m,
        data
      )
    end

    @gateway.purchase(@amount, @credit_card, billing_address: address)
  end

  def test_purchase__credit_card_request_with_descriptor
    stub_commit do |_, data, _|
      assert_match %r(<sale .*</sale>)m, data
      assert_match %r(<customBilling>.*<descriptor>Name</descriptor>)m, data
      assert_match %r(<customBilling>.*<phone>Phone</phone>)m, data
    end

    @gateway.purchase(
      @amount,
      @credit_card,
      descriptor_name: "Name",
      descriptor_phone: "Phone"
    )
  end

  def test_purchase__credit_card_request_with_order_source
    stub_commit do |_, data, _|
      assert_match %r(<sale .*</sale>)m, data
      assert_match %r(<orderSource>some-order-source</orderSource>), data
    end

    @gateway.purchase(@amount, @credit_card, order_source: "some-order-source")
  end

  def test_purchase__credit_card_request_with_shipping_address
    stub_commit do |_, data, _|
      assert_match %r(<sale .*</sale>)m, data
      assert_match(
        %r(<shipToAddress>.*Jim Smith.*456.*Apt 1.*Otta.*ON.*K1C.*CA.*555-5)m,
        data
      )
    end

    @gateway.purchase(@amount, @credit_card, shipping_address: address)
  end

  def test_purchase__credit_card_request_with_track_data
    @credit_card.track_data = "credit-card-track-data"

    stub_commit do |_, data, _|
      assert_match %r(<sale .*</sale>)m, data
      assert_match(
        %r(<card>.*<track>credit-card-track-data</track>.*</card>)m,
        data
      )
      assert_match %r(<orderSource>retail</orderSource>), data
      assert_match %r(<pos>.+<\/pos>)m, data
    end

    @gateway.purchase(@amount, @credit_card)
  end

  def test_purchase__credit_card_successful
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(_response_purchase__credit_card_successful)

    assert_success response
    assert_equal "100000000000000006;sale;100", response.authorization
    assert response.test?
  end

  def test_purchase__token_request
    stub_commit do |_, data, _|
      assert_match %r(<sale .*</sale>)m, data
      assert_match %r(<orderId>this-must-be-truncated--</orderId>), data
      assert_match %r(<amount>#{@amount}</amount>), data
      assert_match %r(<orderSource>ecommerce</orderSource>), data
      # token nodes
      assert_match %r(<token>.*</token>)m, data
      assert_match %r(<litleToken>1234123412341234</litleToken>), data
      assert_match %r(<expDate>0120</expDate>), data
      assert_match %r(<cardValidationNum>098</cardValidationNum>), data
      # nodes that shouldn't be present by default
      assert_no_match %r(<billToAddress>)m, data
      assert_no_match %r(<shipToAddress>), data
      assert_no_match %r(<pos>), data
      assert_no_match %r(<customBilling>), data
      assert_no_match %r(<debtRepayment>), data
    end

    @gateway.purchase(
      @amount,
      @token,
      order_id: "this-must-be-truncated--to-24-chars"
    )
  end

  ## refund
  def test_refund__authorization_failed
    response = stub_comms do
      @gateway.refund(@amount, @invalid_authorization)
    end.respond_with(_response_refund__authorization_failed)

    assert_failure response
    assert_equal "360", response.params["response"]
    assert_equal(
      "No transaction found with specified litleTxnId",
      response.message
    )
  end

  def test_refund__authorization_request
    stub_commit do |_, data, _|
      assert_match %r(<credit .*</credit>)m, data
      assert_match %r(<litleTxnId>100000000000000001</litleTxnId>), data
      assert_match %r(<amount>#{@amount}</amount>), data
      # nodes that shouldn't be present by default
      assert_no_match %r(<customBilling>), data
    end

    @gateway.refund(@amount, @authorize_authorization)
  end

  def test_refund__authorization_request_with_descriptor
    stub_commit do |_, data, _|
      assert_match %r(<credit .*</credit>)m, data
      assert_match(
        %r(<customBilling>.*<descriptor>descriptor-name</descriptor>)m,
        data
      )
      assert_match(
        %r(<customBilling>.*<phone>descriptor-phone</phone>)m,
        data
      )
    end

    @gateway.refund(
      @amount,
      @authorize_authorization,
      descriptor_name: "descriptor-name",
      descriptor_phone: "descriptor-phone"
    )
  end

  def test_refund__authorization_successful
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(_response_purchase__credit_card_successful)

    assert_equal "100000000000000006;sale;100", response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/100000000000000006/, data)
    end.respond_with(_response_refund__purchase_successful)

    assert_success refund
  end

  ## scrubbing
  def test_scrub
    assert_equal _fixture__after_scrub, @gateway.scrub(_fixture__before_scrub)
  end

  def test_scrubbing_support
    assert @gateway.supports_scrubbing?
  end

  ## store
  def test_store__credit_card_failed
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(_response_store__credit_card_failed)

    assert_failure response
    assert_equal "820", response.params["response"]
    assert_equal "Credit card number was invalid", response.message
  end

  def test_store__credit_card_request
    stub_commit do |_, data, _|
      assert_match %r(<registerTokenRequest .*</registerTokenRequest>)m, data
      assert_match %r(<accountNumber>4242424242424242</accountNumber>), data
      assert_match %r(<cardValidationNum>123</cardValidationNum>), data
      # nodes that shouldn't be present by default
      assert_no_match %r(<orderId>), data
    end

    @gateway.store(@credit_card)
  end

  def test_store__credit_card_request_with_order_id
    stub_commit do |_, data, _|
      assert_match %r(<registerTokenRequest .*</registerTokenRequest>)m, data
      assert_match %r(<orderId>this-must-be-truncated--</orderId>), data
    end

    @gateway.store(
      @credit_card,
      order_id: "this-must-be-truncated--to-24-chars"
    )
  end

  def test_store__credit_card_successful
    response = stub_comms do
      @gateway.store(@credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match(/<accountNumber>4242424242424242</, data)
    end.respond_with(_response_store__credit_card_successful)

    assert_success response
    assert_equal "1111222233330123", response.authorization
  end

  def test_store__paypage_registration_id_request
    stub_commit do |_, data, _|
      assert_match %r(<registerTokenRequest .*</registerTokenRequest>)m, data
      assert_match(
        %r(<paypageRegistrationId>#{@paypage_id}</paypageRegistrationId>),
        data
      )
      # nodes that shouldn't be present by default
      assert_no_match %r(<orderId>), data
    end

    @gateway.store(@paypage_id)
  end

  def test_store__paypage_registration_id_successful
    response = stub_comms do
      @gateway.store(@paypage_id)
    end.respond_with(_response_store__paypage_registration_id_successful)

    assert_success response
    assert_equal "1111222233334444", response.authorization
  end

  ## token
  def test_token__initialize_with_options
    token = ActiveMerchant::Billing::VantivGateway::Token.new(
      "987654321",
      month: "01",
      verification_value: "098",
      year: "2020"
    )

    assert_respond_to(token, :metadata)
    assert_equal "987654321", token.payment_data
    assert_equal "987654321", token.litle_token
    assert_equal "01", token.month
    assert_equal "098", token.verification_value
    assert_equal "2020", token.year
  end

  def test_token__initialize_without_options
    token = ActiveMerchant::Billing::VantivGateway::Token.new("555666777")

    assert_equal "555666777", token.payment_data
    assert_equal "555666777", token.litle_token
    assert_equal "", token.month
    assert_equal "", token.verification_value
    assert_equal "", token.year
  end

  ## verify
  def test_verify__credit_card_failed
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(
      _response_authorize__credit_card_failed,
      _response_void__authorize_successful
    )

    assert_failure response
    assert_equal "Insufficient Funds", response.message
  end

  def test_verify__credit_card_successful
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(
      _response_authorize__credit_card_successful,
      _response_void__authorize_successful
    )

    assert_success response
  end

  def test_verify__credit_card_with_failed_void_successful
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(
      _response_authorize__credit_card_successful,
      _response_verify__credit_card_void_failed
    )

    assert_success response
    assert_equal "Approved", response.message
  end

  ## void
  def test_void__authorization_failed
    response = stub_comms do
      @gateway.void(@authorize_authorization_invalid_id)
    end.respond_with(_response_verify__credit_card_void_failed)

    assert_failure response
    assert_equal "360", response.params["response"]
    assert_equal(
      "No transaction found with specified litleTxnId",
      response.message
    )
  end

  def test_void__authorization_request
    stub_commit do |_, data, _|
      assert_match %r(<authReversal .*</authReversal>)m, data
      assert_match %r(<litleTxnId>100000000000000001</litleTxnId>), data
      assert_match %r(<amount>100</amount>), data
    end

    @gateway.void(@authorize_authorization, amount: "100")
  end

  def test_void__authorization_successful
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(_response_authorize__credit_card_successful)

    assert_success response
    assert_equal "100000000000000001;authorization;100", response.authorization

    void = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/<authReversal.*<litleTxnId>100000000000000001</m, data)
    end.respond_with(_response_void__authorize_successful)

    assert_success void
  end

  def test_void__capture_authorization_request
    stub_commit do |_, data, _|
      assert_match %r(<void .*</void>)m, data
      assert_match %r(<litleTxnId>100000000000000002</litleTxnId>), data
      # amount is not included for standard void transactions
      assert_no_match %r(<amount>), data
    end

    @gateway.void(@capture_authorization, amount: "125")
  end

  def test_void__purchase_authorization_request
    stub_commit do |_, data, _|
      assert_match %r(<void .*</void>)m, data
      assert_match %r(<litleTxnId>100000000000000006</litleTxnId>), data
      # amount is not included for standard void transactions
      assert_no_match %r(<amount>), data
    end

    @gateway.void(@purchase_authorization, amount: "150")
  end

  def test_void__refund_authorization_failed
    response = stub_comms do
      @gateway.void(@refund_authorization)
    end.respond_with(_response_void__refund_failed)

    assert_failure response
    assert_equal "360", response.params["response"]
    assert_equal(
      "No transaction found with specified litleTxnId",
      response.message
    )
  end

  def test_void__refund_authorization_request
    stub_commit do |_, data, _|
      assert_match %r(<void .*</void>)m, data
      assert_match %r(<litleTxnId>123456789012345360</litleTxnId>), data
      # amount is not included for standard void transactions
      assert_no_match %r(<amount>), data
    end

    @gateway.void(@refund_authorization, amount: "150")
  end

  def test_void__refund_authorization_successful
    refund = stub_comms do
      @gateway.refund(@amount, @authorize_authorization)
    end.respond_with(_response_refund__purchase_successful)

    assert_equal "100000000000000003;credit;", refund.authorization

    void = stub_comms do
      @gateway.void(refund.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/<void.*<litleTxnId>100000000000000003</m, data)
    end.respond_with(_response_void__refund_successful)

    assert_success void
  end

  ## xml
  def test_xml__request_format
    stub_commit do |_, data, _|
      assert_match(%r(<#{VantivGateway::XML_REQUEST_ROOT}), data)
      assert_match(%r(</#{VantivGateway::XML_REQUEST_ROOT}>), data)
      assert_match(%r(version="#{VantivGateway::SCHEMA_VERSION}"), data)
      assert_match(%r(xmlns="#{VantivGateway::XML_NAMESPACE}"), data)
      assert_match(%r(merchantId="#{@merchant_id}"), data)
    end

    # Use `#purchase` to test request format
    @gateway.purchase(@amount, @credit_card)
  end

  def test_xml__request_with_authentication
    stub_commit do |_, data, |
      assert_match %r(<authentication>.*</authentication>)m, data
      assert_match %r(<user>login</user>), data
      assert_match %r(<password>password</password>), data
    end

    # Use `#purchase` to test authentication
    @gateway.purchase(@amount, @credit_card)
  end

  # Some requests use a payment method that results in a `pos` node created.
  # The values of the nodes below `<pos>` are the same regardless of the action
  # or the payment method. (Probably always a credit card with track data).
  def test_xml__request_with_pos
    @credit_card.track_data = "credit-card-track-data"

    stub_commit do |_, data, _|
      assert_match %r(<pos>.+<\/pos>)m, data
      assert_match(
        %r(<capability>#{VantivGateway::POS_CAPABILITY}</capability>)m,
        data
      )
      assert_match(
        %r(<entryMode>#{VantivGateway::POS_ENTRY_MODE}</entryMode>)m,
        data
      )
      assert_match(
        %r(<cardholderId>#{VantivGateway::POS_CARDHOLDER_ID}</cardholderId>)m,
        data
      )
    end

    @gateway.purchase(@amount, @credit_card)
  end

  def test_xml__request_with_transaction_attributes
    stub_commit do |_, data, |
      assert_match %r(id="MyOrderId\d"), data
      assert_match %r(reportGroup="My Report Group\d"), data
      assert_match %r(customerId="MyCustomerId\d"), data
    end

    # Use `#purchase` to test request format
    @gateway.purchase(
      @amount,
      @credit_card,
      id: "MyOrderId1",
      merchant: "My Report Group1",
      customer: "MyCustomerId1"
    )

    # Test other option names
    @gateway.purchase(
      @amount,
      @credit_card,
      order_id: "MyOrderId2",
      merchant: "My Report Group2",
      customer: "MyCustomerId2"
    )
  end

  def test_xml__request_with_transaction_attributes_defaults
    stub_commit do |_, data, |
      assert_no_match %r(id=".*"), data
      assert_match(
        %r(reportGroup="#{VantivGateway::DEFAULT_REPORT_GROUP}"),
        data
      )
      assert_no_match %r(customerId=".*"), data
    end

    # Use `#purchase` to test request format
    @gateway.purchase(@amount, @credit_card)
  end

  def test_xml_schema__validation_unsuccessful
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(_response_xml_schema__validation_failed)

    assert_failure response
    assert_equal "1", response.params["response"]
    assert_match(
      /^Error validating xml data against the schema/,
      response.message
    )
  end

  private

  # Private: Stub a method and yield arguments to block
  #
  # Uses mocha to stub out `stub_method` using `#with` to get the params
  # which are yielded to the block in our tests.
  def stub_and_yield_arguments(stub_method:, args_length:)
    @gateway.stubs(stub_method).with do |*args|
      yield(*args)
      # `#with` requires we return true, check the length of args passed in
      # which is just a nice check on our expectation of stubbing `commit`
      args.length >= args_length
    end
  end

  # Private: Stub the `commit` method on the gateway and yield the arguments
  # to the block
  #
  # The built-in `stub_comms` method requires that a response be returned
  # and checked in order for the `#check_request` block to run. This is
  # more than we need when we're simply checking if the request is being
  # built correctly.
  def stub_commit
    stub_and_yield_arguments(stub_method: :commit, args_length: 2) do |*args|
      yield(*args)
    end
  end

  def _fixture__before_scrub
    <<-pre_scrub
      opening connection to www.testlitle.com:443...
      opened
      starting SSL for www.testlitle.com:443...
      SSL established
      <- "POST /sandbox/communicator/online HTTP/1.1\r\nContent-Type: text/xml\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: www.testlitle.com\r\nContent-Length: 406\r\n\r\n"
      <- "<litleOnlineRequest xmlns=\"http://www.litle.com/schema\" merchantId=\"101\" version=\"9.4\">\n  <authentication>\n    <user>ACTIVE</user>\n    <password>MERCHANT</password>\n  </authentication>\n  <registerTokenRequest reportGroup=\"Default Report Group\">\n    <orderId/>\n    <accountNumber>4242424242424242</accountNumber>\n    <cardValidationNum>111</cardValidationNum>\n  </registerTokenRequest>\n</litleOnlineRequest>"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Mon, 16 May 2016 03:07:36 GMT\r\n"
      -> "Server: Apache-Coyote/1.1\r\n"
      -> "Content-Type: text/xml;charset=utf-8\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "\r\n"
      -> "1bf\r\n"
      reading 447 bytes...
      -> ""
      -> "<litleOnlineResponse version='10.1' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>\n  <registerTokenResponse id='' reportGroup='Default Report Group' customerId=''>\n    <litleTxnId>185074924759529000</litleTxnId>\n    <litleToken>1111222233334444</litleToken>\n    <response>000</response>\n    <responseTime>2016-05-15T23:07:36</responseTime>\n    <message>Approved</message>\n  </registerTokenResponse>\n</litleOnlineResponse>"
      read 447 bytes
      reading 2 bytes...
      -> ""
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    pre_scrub
  end

  def _fixture__after_scrub
    <<-post_scrub
      opening connection to www.testlitle.com:443...
      opened
      starting SSL for www.testlitle.com:443...
      SSL established
      <- "POST /sandbox/communicator/online HTTP/1.1\r\nContent-Type: text/xml\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: www.testlitle.com\r\nContent-Length: 406\r\n\r\n"
      <- "<litleOnlineRequest xmlns=\"http://www.litle.com/schema\" merchantId=\"101\" version=\"9.4\">\n  <authentication>\n    <user>[FILTERED]</user>\n    <password>[FILTERED]</password>\n  </authentication>\n  <registerTokenRequest reportGroup=\"Default Report Group\">\n    <orderId/>\n    <accountNumber>[FILTERED]</accountNumber>\n    <cardValidationNum>[FILTERED]</cardValidationNum>\n  </registerTokenRequest>\n</litleOnlineRequest>"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Mon, 16 May 2016 03:07:36 GMT\r\n"
      -> "Server: Apache-Coyote/1.1\r\n"
      -> "Content-Type: text/xml;charset=utf-8\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "\r\n"
      -> "1bf\r\n"
      reading 447 bytes...
      -> ""
      -> "<litleOnlineResponse version='10.1' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>\n  <registerTokenResponse id='' reportGroup='Default Report Group' customerId=''>\n    <litleTxnId>185074924759529000</litleTxnId>\n    <litleToken>1111222233334444</litleToken>\n    <response>000</response>\n    <responseTime>2016-05-15T23:07:36</responseTime>\n    <message>Approved</message>\n  </registerTokenResponse>\n</litleOnlineResponse>"
      read 447 bytes
      reading 2 bytes...
      -> ""
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    post_scrub
  end

  # authorize
  def _response_authorize__credit_card_failed
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <authorizationResponse id='6' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>600000000000000001</litleTxnId>
          <orderId>6</orderId>
          <response>110</response>
          <responseTime>2014-03-31T12:24:21</responseTime>
          <message>Insufficient Funds</message>
          <fraudResult>
            <avsResult>34</avsResult>
            <cardValidationResult>P</cardValidationResult>
          </fraudResult>
        </authorizationResponse>
      </litleOnlineResponse>
    )
  end

  def _response_authorize__credit_card_successful
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <authorizationResponse id='1' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>100000000000000001</litleTxnId>
          <orderId>1</orderId>
          <response>000</response>
          <responseTime>2014-03-31T12:21:56</responseTime>
          <message>Approved</message>
          <authCode>11111 </authCode>
          <fraudResult>
            <avsResult>01</avsResult>
            <cardValidationResult>M</cardValidationResult>
          </fraudResult>
        </authorizationResponse>
      </litleOnlineResponse>
    )
  end

  # capture
  def _response_capture__credit_card_failed
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <captureResponse id='' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>304546900824606360</litleTxnId>
          <response>360</response>
          <responseTime>2014-03-31T12:30:53</responseTime>
          <message>No transaction found with specified litleTxnId</message>
        </captureResponse>
      </litleOnlineResponse>
    )
  end

  def _response_capture__credit_card_successful
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <captureResponse id='' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>100000000000000002</litleTxnId>
          <response>000</response>
          <responseTime>2014-03-31T12:28:07</responseTime>
          <message>Approved</message>
        </captureResponse>
      </litleOnlineResponse>
    )
  end

  # purchase
  def _response_purchase__credit_card_failed
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <saleResponse id='6' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>600000000000000002</litleTxnId>
          <orderId>6</orderId>
          <response>110</response>
          <responseTime>2014-03-31T11:48:47</responseTime>
          <message>Insufficient Funds</message>
          <fraudResult>
            <avsResult>34</avsResult>
            <cardValidationResult>P</cardValidationResult>
          </fraudResult>
        </saleResponse>
      </litleOnlineResponse>
    )
  end

  def _response_purchase__credit_card_successful
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <saleResponse id='1' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>100000000000000006</litleTxnId>
          <orderId>1</orderId>
          <response>000</response>
          <responseTime>2014-03-31T11:34:39</responseTime>
          <message>Approved</message>
          <authCode>11111 </authCode>
          <fraudResult>
            <avsResult>01</avsResult>
            <cardValidationResult>M</cardValidationResult>
          </fraudResult>
        </saleResponse>
      </litleOnlineResponse>
    )
  end

  # refund
  def _response_refund__authorization_failed
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <creditResponse id='' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>996483567570258360</litleTxnId>
          <response>360</response>
          <responseTime>2014-03-31T12:42:41</responseTime>
          <message>No transaction found with specified litleTxnId</message>
        </creditResponse>
      </litleOnlineResponse>
    )
  end

  def _response_refund__purchase_successful
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <creditResponse id='' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>100000000000000003</litleTxnId>
          <response>000</response>
          <responseTime>2014-03-31T12:36:50</responseTime>
          <message>Approved</message>
        </creditResponse>
      </litleOnlineResponse>
    )
  end

  # store
  def _response_store__credit_card_failed
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <registerTokenResponse id='51' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>510000000000000001</litleTxnId>
          <orderId>51</orderId>
          <response>820</response>
          <responseTime>2014-03-31T13:10:51</responseTime>
          <message>Credit card number was invalid</message>
        </registerTokenResponse>
      </litleOnlineResponse>
    )
  end

  def _response_store__credit_card_successful
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <registerTokenResponse id='50' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>501000000000000001</litleTxnId>
          <orderId>50</orderId>
          <litleToken>1111222233330123</litleToken>
          <response>801</response>
          <responseTime>2014-03-31T13:06:41</responseTime>
          <message>Account number was successfully registered</message>
          <bin>445711</bin>
          <type>VI</type>
        </registerTokenResponse>
      </litleOnlineResponse>
    )
  end

  def _response_store__paypage_registration_id_successful
    %(
      <litleOnlineResponse version='8.2' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <registerTokenResponse id='99999' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>222358384397377801</litleTxnId>
          <orderId>F12345</orderId>
          <litleToken>1111222233334444</litleToken>
          <response>801</response>
          <responseTime>2015-05-20T14:37:22</responseTime>
          <message>Account number was successfully registered</message>
        </registerTokenResponse>
      </litleOnlineResponse>
    )
  end

  # verify
  def _response_verify__credit_card_void_failed
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <authReversalResponse id='' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>775712323632364360</litleTxnId>
          <orderId>123</orderId>
          <response>360</response>
          <responseTime>2014-03-31T13:03:17</responseTime>
          <message>No transaction found with specified litleTxnId</message>
        </authReversalResponse>
      </litleOnlineResponse>
    )
  end

  # void
  def _response_void__authorize_successful
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <authReversalResponse id='' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>972619753208653000</litleTxnId>
          <orderId>123</orderId>
          <response>000</response>
          <responseTime>2014-03-31T12:45:44</responseTime>
          <message>Approved</message>
        </authReversalResponse>
      </litleOnlineResponse>
    )
  end

  def _response_void__refund_failed
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <voidResponse id='' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>486912375928374360</litleTxnId>
          <response>360</response>
          <responseTime>2014-03-31T12:55:46</responseTime>
          <message>No transaction found with specified litleTxnId</message>
        </voidResponse>
      </litleOnlineResponse>
    )
  end

  def _response_void__refund_successful
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <voidResponse id='' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>100000000000000004</litleTxnId>
          <response>000</response>
          <responseTime>2014-03-31T12:44:52</responseTime>
          <message>Approved</message>
        </voidResponse>
      </litleOnlineResponse>
    )
  end

  # xml schema
  def _response_xml_schema__validation_failed
    %(
    <litleOnlineResponse version='8.29' xmlns='http://www.litle.com/schema'
                     response='1'
                     message='Error validating xml data against the schema on line 8\nthe length of the value is 10, but the required minimum is 13.'/>

    )
  end
end
