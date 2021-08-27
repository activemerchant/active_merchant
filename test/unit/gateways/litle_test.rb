require 'test_helper'

class LitleTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.mode = :test

    @gateway = LitleGateway.new(
      login: 'login',
      password: 'password',
      merchant_id: 'merchant_id'
    )

    @credit_card = credit_card
    @decrypted_apple_pay = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new(
      {
        month: '01',
        year: '2012',
        brand: 'visa',
        number:  '44444444400009',
        payment_cryptogram: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA='
      }
    )
    @decrypted_android_pay = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new(
      {
        source: :android_pay,
        month: '01',
        year: '2021',
        brand: 'visa',
        number:  '4457000300000007',
        payment_cryptogram: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA='
      }
    )
    @amount = 100
    @options = {}
    @check = check(
      name: 'Tom Black',
      routing_number:  '011075150',
      account_number: '4099999992',
      account_type: 'checking'
    )
    @authorize_check = check(
      name: 'John Smith',
      routing_number: '011075150',
      account_number: '1099999999',
      account_type: 'checking'
    )

    @long_address = {
      address1: '1234 Supercalifragilisticexpialidocious',
      address2: 'Unit 6',
      city: '‎Lake Chargoggagoggmanchauggagoggchaubunagungamaugg',
      state: 'ME',
      zip: '09901',
      country: 'US'
    }
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, _data, _headers|
      # Counterpoint to test_successful_postlive_url:
      assert_match(/www\.testvantivcnp\.com/, endpoint)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal '100000000000000006;sale;100', response.authorization
    assert response.test?
  end

  def test_successful_postlive_url
    @gateway = LitleGateway.new(
      login: 'login',
      password: 'password',
      merchant_id: 'merchant_id',
      url_override: 'postlive'
    )

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, _data, _headers|
      assert_match(/payments\.vantivpostlive\.com/, endpoint)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal '100000000000000006;sale;100', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_echeck
    response = stub_comms do
      @gateway.purchase(2004, @check)
    end.respond_with(successful_purchase_with_echeck_response)

    assert_success response

    assert_equal '621100411297330000;echeckSales;2004', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert_equal 'Insufficient Funds', response.message
    assert_equal '110', response.params['response']
    assert response.test?
  end

  def test_passing_merchant_data
    options = @options.merge(
      affiliate: 'some-affiliate',
      campaign: 'super-awesome-campaign',
      merchant_grouping_id: 'brilliant-group'
    )
    stub_comms do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<affiliate>some-affiliate</affiliate>), data)
      assert_match(%r(<campaign>super-awesome-campaign</campaign>), data)
      assert_match(%r(<merchantGroupingId>brilliant-group</merchantGroupingId>), data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_name_on_card
    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<billToAddress>\s*<name>Longbob Longsen<), data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_order_id
    stub_comms do
      @gateway.purchase(@amount, @credit_card, order_id: '774488')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/774488/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_customer_id_on_purchase
    stub_comms do
      @gateway.purchase(@amount, @credit_card, customer_id: '8675309')
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(customerId=\"8675309\">\n), data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_customer_id_on_capture
    stub_comms do
      @gateway.capture(@amount, @credit_card, customer_id: '8675309')
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(customerId=\"8675309\">\n), data)
    end.respond_with(successful_capture_response)
  end

  def test_passing_customer_id_on_refund
    stub_comms do
      @gateway.credit(@amount, @credit_card, customer_id: '8675309')
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(customerId=\"8675309\">\n), data)
    end.respond_with(successful_credit_response)
  end

  def test_passing_billing_address
    stub_comms do
      @gateway.purchase(@amount, @credit_card, billing_address: address)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<billToAddress>.*Widgets.*456.*Apt 1.*Otta.*ON.*K1C.*CA.*555-5/m, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_shipping_address
    stub_comms do
      @gateway.purchase(@amount, @credit_card, shipping_address: address)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<shipToAddress>.*Widgets.*456.*Apt 1.*Otta.*ON.*K1C.*CA.*555-5/m, data)
    end.respond_with(successful_purchase_response)
  end

  def test_truncating_billing_address
    stub_comms do
      @gateway.purchase(@amount, @credit_card, billing_address: @long_address)
    end.check_request do |_endpoint, data, _headers|
      refute_match(/<billToAddress>Supercalifragilisticexpialidocious/m, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_descriptor
    stub_comms do
      @gateway.authorize(@amount, @credit_card, {
        descriptor_name: 'Name', descriptor_phone: 'Phone'
      })
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<customBilling>.*<descriptor>Name<)m, data)
      assert_match(%r(<customBilling>.*<phone>Phone<)m, data)
    end.respond_with(successful_authorize_response)
  end

  def test_passing_debt_repayment
    stub_comms do
      @gateway.authorize(@amount, @credit_card, { debt_repayment: true })
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<debtRepayment>true</debtRepayment>), data)
    end.respond_with(successful_authorize_response)
  end

  def test_passing_payment_cryptogram
    stub_comms do
      @gateway.purchase(@amount, @decrypted_apple_pay)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/BwABBJQ1AgAAAAAgJDUCAAAAAAA=/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_basis_date
    stub_comms do
      @gateway.purchase(@amount, 'token', { basis_expiration_month: '04', basis_expiration_year: '2027' })
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<expDate>0427<\/expDate>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_does_not_pass_empty_checknum
    check = check(
      name: 'Tom Black',
      routing_number:  '011075150',
      account_number: '4099999992',
      number: nil,
      account_type: 'checking'
    )
    stub_comms do
      @gateway.purchase(@amount, check)
    end.check_request do |_endpoint, data, _headers|
      assert_not_match(/<checkNum\/>/m, data)
    end.respond_with(successful_purchase_response)
  end

  def test_add_applepay_order_source
    stub_comms do
      @gateway.purchase(@amount, @decrypted_apple_pay)
    end.check_request do |_endpoint, data, _headers|
      assert_match '<orderSource>applepay</orderSource>', data
    end.respond_with(successful_purchase_response)
  end

  def test_add_android_pay_order_source
    stub_comms do
      @gateway.purchase(@amount, @decrypted_android_pay)
    end.check_request do |_endpoint, data, _headers|
      assert_match '<orderSource>androidpay</orderSource>', data
    end.respond_with(successful_purchase_response)
  end

  def test_successful_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response

    assert_equal '100000000000000001;authorization;100', response.authorization
    assert response.test?

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/100000000000000001/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal 'Insufficient Funds', response.message
    assert_equal '110', response.params['response']
  end

  def test_failed_capture
    response = stub_comms do
      @gateway.capture(@amount, @credit_card)
    end.respond_with(failed_capture_response)

    assert_failure response
    assert_equal 'No transaction found with specified litleTxnId', response.message
    assert_equal '360', response.params['response']
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_equal '100000000000000006;sale;100', response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/100000000000000006/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(@amount, 'SomeAuthorization')
    end.respond_with(failed_refund_response)

    assert_failure response
    assert_equal 'No transaction found with specified litleTxnId', response.message
    assert_equal '360', response.params['response']
  end

  def test_successful_credit
    credit = stub_comms do
      @gateway.credit(@amount, @credit_card)
    end.respond_with(successful_credit_response)

    assert_success credit
    assert_equal 'Approved', credit.message
  end

  def test_failed_credit
    credit = stub_comms do
      @gateway.credit(@amount, @credit_card)
    end.respond_with(failed_credit_response)

    assert_failure credit
  end

  def test_successful_void_of_authorization
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal '100000000000000001;authorization;100', response.authorization

    void = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<authReversal.*<litleTxnId>100000000000000001</m, data)
    end.respond_with(successful_void_of_auth_response)

    assert_success void
  end

  def test_successful_void_of_other_things
    refund = stub_comms do
      @gateway.refund(@amount, 'SomeAuthorization')
    end.respond_with(successful_refund_response)

    assert_equal '100000000000000003;credit;', refund.authorization

    void = stub_comms do
      @gateway.void(refund.authorization)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<void.*<litleTxnId>100000000000000003</m, data)
    end.respond_with(successful_void_of_other_things_response)

    assert_success void
  end

  def test_failed_void_of_authorization
    response = stub_comms do
      @gateway.void('123456789012345360;authorization;100')
    end.respond_with(failed_void_of_authorization_response)

    assert_failure response
    assert_equal 'No transaction found with specified litleTxnId', response.message
    assert_equal '360', response.params['response']
  end

  def test_failed_void_of_other_things
    response = stub_comms do
      @gateway.void('123456789012345360;credit;100')
    end.respond_with(failed_void_of_other_things_response)

    assert_failure response
    assert_equal 'No transaction found with specified litleTxnId', response.message
    assert_equal '360', response.params['response']
  end

  def test_successful_void_of_echeck
    response = stub_comms do
      @gateway.void('945032206979933000;echeckSales;2004')
    end.respond_with(successful_void_of_echeck_response)

    assert_success response
    assert_equal '986272331806746000;echeckVoid;', response.authorization
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<accountNumber>4242424242424242</, data)
    end.respond_with(successful_store_response)

    assert_success response
    assert_equal '1111222233330123', response.authorization
  end

  def test_successful_store_with_paypage_registration_id
    response = stub_comms do
      @gateway.store('cDZJcmd1VjNlYXNaSlRMTGpocVZQY1NNlYE4ZW5UTko4NU9KK3p1L1p1VzE4ZWVPQVlSUHNITG1JN2I0NzlyTg=')
    end.respond_with(successful_store_paypage_response)

    assert_success response
    assert_equal '1111222233334444', response.authorization
  end

  def test_failed_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(failed_store_response)

    assert_failure response
    assert_equal 'Credit card number was invalid', response.message
    assert_equal '820', response.params['response']
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorize_response, successful_void_of_auth_response)
    assert_success response
  end

  def test_successful_verify_failed_void
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, failed_void_of_authorization_response)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_unsuccessful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorize_response, successful_void_of_auth_response)
    assert_failure response
    assert_equal 'Insufficient Funds', response.message
  end

  def test_add_swipe_data_with_creditcard
    @credit_card.track_data = 'Track Data'

    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |_endpoint, data, _headers|
      assert_match '<track>Track Data</track>', data
      assert_match '<orderSource>retail</orderSource>', data
      assert_match %r{<pos>.+<\/pos>}m, data
    end.respond_with(successful_purchase_response)
  end

  def test_order_source_with_creditcard_no_track_data
    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |_endpoint, data, _headers|
      assert_match '<orderSource>ecommerce</orderSource>', data
      assert %r{<pos>.+<\/pos>}m !~ data
    end.respond_with(successful_purchase_response)
  end

  def test_order_source_override
    stub_comms do
      @gateway.purchase(@amount, @credit_card, order_source: 'recurring')
    end.check_request do |_endpoint, data, _headers|
      assert_match '<orderSource>recurring</orderSource>', data
    end.respond_with(successful_purchase_response)
  end

  def test_unsuccessful_xml_schema_validation
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(unsuccessful_xml_schema_validation_response)

    assert_failure response
    assert_match(/^Error validating xml data against the schema/, response.message)
    assert_equal '1', response.params['response']
  end

  def test_stored_credential_cit_card_on_file_initial
    options = @options.merge(
      stored_credential: {
        initial_transaction: true,
        reason_type: 'unscheduled',
        initiator: 'cardholder',
        network_transaction_id: nil
      }
    )

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<processingType>initialCOF</processingType>), data)
    end.respond_with(successful_authorize_stored_credentials)

    assert_success response
  end

  def test_stored_credential_cit_card_on_file_used
    options = @options.merge(
      stored_credential: {
        initial_transaction: false,
        reason_type: 'unscheduled',
        initiator: 'cardholder',
        network_transaction_id: network_transaction_id
      }
    )

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<processingType>cardholderInitiatedCOF</processingType>), data)
      assert_match(%r(<originalNetworkTransactionId>#{network_transaction_id}</originalNetworkTransactionId>), data)
      assert_match(%r(<orderSource>ecommerce</orderSource>), data)
    end.respond_with(successful_authorize_stored_credentials)

    assert_success response
  end

  def test_stored_credential_cit_cof_doesnt_override_order_source
    options = @options.merge(
      order_source: '3dsAuthenticated',
      xid: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
      cavv: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
      stored_credential: {
        initial_transaction: false,
        reason_type: 'unscheduled',
        initiator: 'cardholder',
        network_transaction_id: network_transaction_id
      }
    )

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<processingType>cardholderInitiatedCOF</processingType>), data)
      assert_match(%r(<originalNetworkTransactionId>#{network_transaction_id}</originalNetworkTransactionId>), data)
      assert_match(%r(<orderSource>3dsAuthenticated</orderSource>), data)
    end.respond_with(successful_authorize_stored_credentials)

    assert_success response
  end

  def test_stored_credential_mit_card_on_file_initial
    options = @options.merge(
      stored_credential: {
        initial_transaction: true,
        reason_type: 'unscheduled',
        initiator: 'merchant',
        network_transaction_id: nil
      }
    )

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<processingType>initialCOF</processingType>), data)
    end.respond_with(successful_authorize_stored_credentials)

    assert_success response
  end

  def test_stored_credential_mit_card_on_file_used
    options = @options.merge(
      stored_credential: {
        initial_transaction: false,
        reason_type: 'unscheduled',
        initiator: 'merchant',
        network_transaction_id: network_transaction_id
      }
    )

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<processingType>merchantInitiatedCOF</processingType>), data)
      assert_match(%r(<originalNetworkTransactionId>#{network_transaction_id}</originalNetworkTransactionId>), data)
      assert_match(%r(<orderSource>ecommerce</orderSource>), data)
    end.respond_with(successful_authorize_stored_credentials)

    assert_success response
  end

  def test_stored_credential_installment_initial
    options = @options.merge(
      stored_credential: {
        initial_transaction: true,
        reason_type: 'installment',
        initiator: 'merchant',
        network_transaction_id: nil
      }
    )

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<processingType>initialInstallment</processingType>), data)
    end.respond_with(successful_authorize_stored_credentials)

    assert_success response
  end

  def test_stored_credential_installment_used
    options = @options.merge(
      stored_credential: {
        initial_transaction: false,
        reason_type: 'installment',
        initiator: 'merchant',
        network_transaction_id: network_transaction_id
      }
    )

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<originalNetworkTransactionId>#{network_transaction_id}</originalNetworkTransactionId>), data)
      assert_match(%r(<orderSource>installment</orderSource>), data)
    end.respond_with(successful_authorize_stored_credentials)

    assert_success response
  end

  def test_stored_credential_recurring_initial
    options = @options.merge(
      stored_credential: {
        initial_transaction: true,
        reason_type: 'recurring',
        initiator: 'merchant',
        network_transaction_id: nil
      }
    )

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<processingType>initialRecurring</processingType>), data)
    end.respond_with(successful_authorize_stored_credentials)

    assert_success response
  end

  def test_stored_credential_recurring_used
    options = @options.merge(
      stored_credential: {
        initial_transaction: false,
        reason_type: 'recurring',
        initiator: 'merchant',
        network_transaction_id: network_transaction_id
      }
    )

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<originalNetworkTransactionId>#{network_transaction_id}</originalNetworkTransactionId>), data)
      assert_match(%r(<orderSource>recurring</orderSource>), data)
    end.respond_with(successful_authorize_stored_credentials)

    assert_success response
  end

  def test_scrub
    assert_equal @gateway.scrub(pre_scrub), post_scrub
  end

  def test_supports_scrubbing?
    assert @gateway.supports_scrubbing?
  end

  private

  def network_transaction_id
    '63225578415568556365452427825'
  end

  def successful_purchase_response
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

  def successful_purchase_with_echeck_response
    %(
      <litleOnlineResponse version='9.12' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <echeckSalesResponse id='42' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>621100411297330000</litleTxnId>
          <orderId>42</orderId>
          <response>000</response>
          <responseTime>2018-01-09T14:02:20</responseTime>
          <message>Approved</message>
        </echeckSalesResponse>
      </litleOnlineResponse>
    )
  end

  def successful_authorize_stored_credentials
    %(
      <litleOnlineResponse xmlns="http://www.litle.com/schema" version="9.14" response="0" message="Valid Format">
        <authorizationResponse id="1" reportGroup="Default Report Group">
          <litleTxnId>991939023768015826</litleTxnId>
          <orderId>1</orderId>
          <response>000</response>
          <message>Approved</message>
          <responseTime>2019-02-26T17:45:29.885</responseTime>
          <authCode>75045</authCode>
          <networkTransactionId>63225578415568556365452427825</networkTransactionId>
        </authorizationResponse>
      </litleOnlineResponse>
    )
  end

  def failed_purchase_response
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

  def successful_authorize_response
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

  def failed_authorize_response
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

  def successful_capture_response
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

  def failed_capture_response
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

  def successful_refund_response
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

  def failed_refund_response
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

  def successful_credit_response
    %(
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <litleOnlineResponse version="9.14" response="0" message="Valid Format">
        <creditResponse id="1" reportGroup="Default Report Group">
          <litleTxnId>908410935514139173</litleTxnId>
          <orderId>1</orderId>
          <response>000</response>
          <responseTime>2020-10-30T19:19:38.935</responseTime>
          <message>Approved</message>
        </creditResponse>
      </litleOnlineResponse>
    )
  end

  def failed_credit_response
    %(
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <litleOnlineResponse version="9.14" response="1" message="Error validating xml data against the schema: cvc-minLength-valid: Value '1234567890' with length = '10' is not facet-valid with respect to minLength '13' for type 'ccAccountNumberType'."/>
    )
  end

  def successful_void_of_auth_response
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

  def successful_void_of_other_things_response
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

  def successful_void_of_echeck_response
    %(
      <litleOnlineResponse version='9.12' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <echeckVoidResponse id='' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>986272331806746000</litleTxnId>
          <response>000</response>
          <responseTime>2018-01-09T14:20:00</responseTime>
          <message>Approved</message>
          <postDate>2018-01-09</postDate>
        </echeckVoidResponse>
      </litleOnlineResponse>
    )
  end

  def failed_void_of_authorization_response
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

  def failed_void_of_other_things_response
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

  def successful_store_response
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

  def successful_store_paypage_response
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

  def failed_store_response
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

  def unsuccessful_xml_schema_validation_response
    %(
    <litleOnlineResponse version='8.29' xmlns='http://www.litle.com/schema'
                     response='1'
                     message='Error validating xml data against the schema on line 8\nthe length of the value is 10, but the required minimum is 13.'/>

    )
  end

  def pre_scrub
    <<-REQUEST
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
    REQUEST
  end

  def post_scrub
    <<-REQUEST
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
    REQUEST
  end
end
