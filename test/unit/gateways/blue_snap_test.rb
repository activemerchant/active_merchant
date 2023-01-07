# coding: utf-8

require 'test_helper'

class BlueSnapCurrencyDocMock
  attr_accessor :received_amount

  def currency(currency); end

  def amount(amount)
    @received_amount = amount
  end
end

class BlueSnapTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = BlueSnapGateway.new(api_username: 'login', api_password: 'password')
    @credit_card = credit_card
    @check = check
    @amount = 100

    # BlueSnap may require support contact to activate fraud checking on sandbox accounts.
    # Specific merchant-configurable thresholds were set and are reflected in the
    # recorded responses:
    # Order Total Amount Decline Threshold = 3728
    # Payment Country Decline List = Brazil
    @fraudulent_amount = 3729
    @fraudulent_card = credit_card('4007702835532454')

    @options = { order_id: '1', personal_identification_number: 'CNPJ' }
    @options_3ds2 = @options.merge(
      three_d_secure: {
        eci: '05',
        cavv: 'AAABAWFlmQAAAABjRWWZEEFgFz+A',
        xid: 'MGpHWm5ZWVpKclo0aUk0VmltVDA=',
        ds_transaction_id: 'jhg34-sdgds87-sdg87-sdfg7',
        version: '2.2.0'
      }
    )
    @valid_check_options = {
      billing_address: {
        address1: '123 Street',
        address2: 'Apt 1',
        city: 'Happy City',
        state: 'CA',
        zip: '94901'
      },
      authorized_by_shopper: true
    }
    @option_fraud_info = @options.merge(
      transaction_fraud_info: {
        fraud_session_id: 'fbcc094208f54c0e974d56875c73af7a'
      }
    )
  end

  def test_successful_purchase
    @gateway.expects(:raw_ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '1012082839', response.authorization
  end

  def test_successful_purchase_with_shipping_contact_info
    more_options = @options.merge({
      shipping_address: {
        address1: '123 Main St',
        adress2: 'Apt B',
        city: 'Springfield',
        state: 'NC',
        country: 'US',
        zip: '27701'
      }
    })
    response = stub_comms(@gateway, :raw_ssl_request) do
      @gateway.purchase(@amount, @credit_card, more_options)
    end.check_request do |_method, _url, data|
      assert_match(/shipping-contact-info/, data)
      assert_match(/<address1>123 Main St/, data)
      assert_match(/<city>Springfield/, data)
      assert_match(/<state>NC/, data)
      assert_match(/<country>US/, data)
      assert_match(/<zip>27701/, data)
    end.respond_with(successful_purchase_response_with_metadata)

    assert_success response
    assert_equal '1012082839', response.authorization
  end

  def test_successful_purchase_with_card_holder_info
    more_options = @options.merge({
      billing_address: {
        address1: '123 Street',
        address2: 'Apt 1',
        city: 'Happy City',
        state: 'CA',
        zip: '94901'
      },
      phone_number: '555 888 0000'
    })
    response = stub_comms(@gateway, :raw_ssl_request) do
      @gateway.purchase(@amount, @credit_card, more_options)
    end.check_request do |_method, _url, data|
      assert_match(/card-holder-info/, data)
      assert_match(/<address>123 Street/, data)
      assert_match(/<address2>Apt 1/, data)
      assert_match(/<phone>555 888 0000/, data)
    end.respond_with(successful_purchase_response_with_metadata)

    assert_success response
    assert_equal '1012082839', response.authorization
  end

  def test_successful_purchase_with_metadata
    # description option should become meta-data field

    more_options = @options.merge({
      order_id: '1',
      ip: '127.0.0.1',
      email: 'joe@example.com',
      transaction_meta_data: [
        {
          meta_key: 'stateTaxAmount',
          meta_value: '20.00',
          meta_description: 'State Tax Amount'
        },
        {
          meta_key: 'cityTaxAmount',
          meta_value: 10.00,
          meta_description: 'City Tax Amount'
        },
        {
          meta_key: 'websiteInfo',
          meta_value: 'www.info.com',
          meta_description: 'Website'
        }
      ],
      description: 'Legacy Product Desc',
      soft_descriptor: 'OnCardStatement',
      personal_identification_number: 'CNPJ'
    })

    response = stub_comms(@gateway, :raw_ssl_request) do
      @gateway.purchase(@amount, @credit_card, more_options)
    end.check_request do |_method, _url, data|
      assert_match(/transaction-meta-data/, data)
      assert_match(/<meta-value>Legacy Product Desc<\/meta-value>/, data)
      assert_match(/<meta-key>description<\/meta-key>/, data)
      assert_match(/<meta-key>cityTaxAmount<\/meta-key>/, data)
      assert_match(/<meta-key>stateTaxAmount<\/meta-key>/, data)
      assert_match(/<meta-key>websiteInfo<\/meta-key>/, data)
    end.respond_with(successful_purchase_response_with_metadata)

    assert_success response
    assert_equal '1012082839', response.authorization

    assert_equal 4, response.params['transaction-meta-data'].length

    response.params['transaction-meta-data'].each { |m|
      assert_true m['meta-key'].length > 0
      assert_true m['meta-value'].length > 0
      assert_true m['meta-description'].length > 0

      case m['meta-key']
      when 'description'
        assert_equal 'Product ABC', m['meta-value']
        assert_equal 'Product Description', m['meta-description']
      when 'cityTaxAmount'
        assert_equal '10.00', m['meta-value']
        assert_equal 'City Tax Amount', m['meta-description']
      when 'stateTaxAmount'
        assert_equal '20.00', m['meta-value']
        assert_equal 'State Tax Amount', m['meta-description']
      end
    }
  end

  def test_successful_purchase_with_metadata_empty
    more_options = @options.merge({
      order_id: '1',
      ip: '127.0.0.1',
      email: 'joe@example.com',
      transaction_meta_data: [],
      soft_descriptor: 'OnCardStatement',
      personal_identification_number: 'CNPJ'
    })

    response = stub_comms(@gateway, :raw_ssl_request) do
      @gateway.purchase(@amount, @credit_card, more_options)
    end.check_request do |_method, _url, data|
      assert_not_match(/transaction-meta-data/, data)
      assert_not_match(/meta-key/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_nil response.params['transaction-meta-data']
  end

  def test_successful_purchase_with_metadata_nil
    more_options = @options.merge({
      order_id: '1',
      ip: '127.0.0.1',
      email: 'joe@example.com',
      transaction_meta_data: nil,
      soft_descriptor: 'OnCardStatement',
      personal_identification_number: 'CNPJ'
    })

    response = stub_comms(@gateway, :raw_ssl_request) do
      @gateway.purchase(@amount, @credit_card, more_options)
    end.check_request do |_method, _url, data|
      assert_not_match(/transaction-meta-data/, data)
      assert_not_match(/meta-key/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_nil response.params['transaction-meta-data']
  end

  def test_successful_purchase_with_unused_state_code
    unrecognized_state_code_options = {
      billing_address: {
        city: 'Dresden',
        state: 'Sachsen',
        country: 'DE',
        zip: '01069'
      }
    }

    @gateway.expects(:raw_ssl_request).returns(successful_stateless_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, unrecognized_state_code_options)
    assert_success response
    assert_equal '1021645629', response.authorization
    assert_not_includes(response.params, 'state')
  end

  def test_successful_purchase_with_fraud_info
    fraud_info = @option_fraud_info.merge({ ip: '123.12.134.1' })
    response = stub_comms(@gateway, :raw_ssl_request) do
      @gateway.purchase(@amount, @credit_card, fraud_info)
    end.check_request do |_method, _url, data|
      assert_match(/<fraud-session-id>fbcc094208f54c0e974d56875c73af7a<\/fraud-session-id>/, data)
      assert_match(/<shopper-ip-address>123.12.134.1<\/shopper-ip-address>/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal '1012082839', response.authorization
  end

  def test_successful_echeck_purchase
    @gateway.expects(:raw_ssl_request).returns(successful_echeck_purchase_response)

    response = @gateway.purchase(@amount, @check, @options.merge(@valid_check_options))
    assert_success response
    assert_equal '1019803029', response.authorization
  end

  def test_successful_purchase_with_3ds_auth
    response = stub_comms(@gateway, :raw_ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options_3ds2)
    end.check_request do |_method, _url, data|
      assert_match(/<three-d-secure>/, data)
      assert_match(/<eci>#{Regexp.quote(@options_3ds2[:three_d_secure][:eci])}<\/eci>/, data)
      assert_match(/<cavv>#{Regexp.quote(@options_3ds2[:three_d_secure][:cavv])}<\/cavv>/, data)
      assert_match(/<xid>#{Regexp.quote(@options_3ds2[:three_d_secure][:xid])}<\/xid>/, data)
      assert_match(/<three-d-secure-version>#{Regexp.quote(@options_3ds2[:three_d_secure][:version])}<\/three-d-secure-version>/, data)
      assert_match(/<ds-transaction-id>#{Regexp.quote(@options_3ds2[:three_d_secure][:ds_transaction_id])}<\/ds-transaction-id>/, data)
    end.respond_with(successful_purchase_with_3ds_auth_response)

    assert_success response
    assert_equal '1024951831', response.authorization
    assert_equal '019082915501456', response.params['original-network-transaction-id']
    assert_equal '019082915501456', response.params['network-transaction-id']
  end

  def test_successful_purchase_with_cit_stored_credential_fields
    cit_stored_credentials = {
      initiator: 'cardholder',
      network_transaction_id: 'ABC123'
    }
    stub_comms(@gateway, :raw_ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options_3ds2.merge({ stored_credential: cit_stored_credentials }))
    end.check_request do |_method, _url, data|
      assert_match '<transaction-initiator>SHOPPER</transaction-initiator>', data
      assert_match '<original-network-transaction-id>ABC123</original-network-transaction-id>', data
    end.respond_with(successful_purchase_with_3ds_auth_response)
  end

  def test_successful_purchase_with_mit_stored_credential_fields
    cit_stored_credentials = {
      initiator: 'merchant',
      network_transaction_id: 'QER100'
    }
    stub_comms(@gateway, :raw_ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options_3ds2.merge({ stored_credential: cit_stored_credentials }))
    end.check_request do |_method, _url, data|
      assert_match '<transaction-initiator>MERCHANT</transaction-initiator>', data
      assert_match '<original-network-transaction-id>QER100</original-network-transaction-id>', data
    end.respond_with(successful_purchase_with_3ds_auth_response)
  end

  def test_does_not_send_3ds_auth_when_empty
    stub_comms(@gateway, :raw_ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, _url, data|
      assert_not_match(/<three-d-secure>/, data)
      assert_not_match(/<eci>/, data)
      assert_not_match(/<cavv>/, data)
      assert_not_match(/<xid>/, data)
      assert_not_match(/<three-d-secure-version>/, data)
      assert_not_match(/<ds-transaction-id>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_failed_purchase
    @gateway.expects(:raw_ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '14002', response.error_code
  end

  def test_failed_echeck_purchase
    @gateway.expects(:raw_ssl_request).returns(failed_echeck_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '16004', response.error_code
  end

  def test_successful_authorize
    response = stub_comms(@gateway, :raw_ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_type, _endpoint, data, _headers|
      assert_match '<store-card>false</store-card>', data
      assert_match '<personal-identification-number>CNPJ</personal-identification-number>', data
    end.respond_with(successful_authorize_response)
    assert_success response
    assert_equal '1012082893', response.authorization
  end

  def test_successful_authorize_with_3ds_auth
    response = stub_comms(@gateway, :raw_ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options_3ds2)
    end.check_request do |_type, _endpoint, data, _headers|
      assert_match(/<three-d-secure>/, data)
      assert_match(/<eci>#{Regexp.quote(@options_3ds2[:three_d_secure][:eci])}<\/eci>/, data)
      assert_match(/<cavv>#{Regexp.quote(@options_3ds2[:three_d_secure][:cavv])}<\/cavv>/, data)
      assert_match(/<xid>#{Regexp.quote(@options_3ds2[:three_d_secure][:xid])}<\/xid>/, data)
      assert_match(/<three-d-secure-version>#{Regexp.quote(@options_3ds2[:three_d_secure][:version])}<\/three-d-secure-version>/, data)
      assert_match(/<ds-transaction-id>#{Regexp.quote(@options_3ds2[:three_d_secure][:ds_transaction_id])}<\/ds-transaction-id>/, data)
    end.respond_with(successful_authorize_with_3ds_auth_response)

    assert_success response
    assert_equal '1024951833', response.authorization
    assert_equal 'MCC8929120829', response.params['original-network-transaction-id']
    assert_equal 'MCC8929120829', response.params['network-transaction-id']
  end

  def test_failed_authorize
    @gateway.expects(:raw_ssl_request).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '14002', response.error_code
  end

  def test_successful_capture
    response = stub_comms(@gateway, :raw_ssl_request) do
      @gateway.capture(@amount, @credit_card, @options)
    end.check_request do |_method, _url, data|
      assert_not_match(/<amount>1.00<\/amount>/, data)
      assert_not_match(/<currency>USD<\/currency>/, data)
    end.respond_with(successful_capture_response)

    assert_success response
    assert_equal '1012082881', response.authorization
  end

  def test_successful_partial_capture
    response = stub_comms(@gateway, :raw_ssl_request) do
      @gateway.capture(@amount, @credit_card, @options.merge(include_capture_amount: true))
    end.check_request do |_method, _url, data|
      assert_match(/<amount>1.00<\/amount>/, data)
      assert_match(/<currency>USD<\/currency>/, data)
    end.respond_with(successful_capture_response)

    assert_success response
    assert_equal '1012082881', response.authorization
  end

  def test_failed_capture
    @gateway.expects(:raw_ssl_request).returns(failed_capture_response)

    response = @gateway.capture(@amount, 'Authorization')
    assert_failure response
    assert_equal '20008', response.error_code
  end

  def test_successful_refund
    options = {
      reason: 'Refund for order #1992',
      cancel_subscription: 'false',
      tax_amount: 0.05,
      transaction_meta_data: [
        {
          meta_key: 'refundedItems',
          meta_value: '1552,8832',
          meta_description: 'Refunded Items',
          meta_is_visible: 'false'
        },
        {
          meta_key: 'Number2',
          meta_value: 'KTD',
          meta_description: 'Metadata 2',
          meta_is_visible: 'true'
        }
      ]
    }
    transaction_id = '1286'
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.refund(@amount, transaction_id, options)
    end.check_request do |_action, endpoint, data, _headers|
      doc = REXML::Document.new(data)

      assert_includes endpoint, "/refund/#{transaction_id}"
      assert_match(/<amount>1.00<\/amount>/, data)
      assert_match(/<tax-amount>0.05<\/tax-amount>/, data)
      assert_match(/<cancel-subscription>false<\/cancel-subscription>/, data)
      assert_match(/<reason>Refund for order #1992<\/reason>/, data)
      assert_match(/<meta-key>refundedItems<\/meta-key>/, data)
      assert_match(/<meta-value>KTD<\/meta-value>/, data)
      assert_match(/<meta-description>Metadata 2<\/meta-description>/, data)
      transaction_meta_data = doc.root.elements['transaction-meta-data'].elements.to_a
      transaction_meta_data.each_with_index do |item, index|
        assert_match item.elements['meta-key'].text, options[:transaction_meta_data][index][:meta_key]
        assert_match item.elements['meta-value'].text, options[:transaction_meta_data][index][:meta_value]
        assert_match item.elements['meta-description'].text, options[:transaction_meta_data][index][:meta_description]
        assert_match item.elements['is-visible'].text, options[:transaction_meta_data][index][:meta_is_visible]
      end
    end.respond_with(successful_refund_without_merchant_transaction_id_response)
    assert_success response
    assert_equal '1061398943', response.authorization
  end

  def test_successful_refund_with_merchant_id
    merchant_transaction_id = '12678'
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.refund(@amount, '', @options.merge({ merchant_transaction_id: merchant_transaction_id }))
    end.check_request do |_action, endpoint, _data, _headers|
      assert_includes endpoint, "/refund/merchant/#{merchant_transaction_id}"
    end.respond_with(successful_refund_response)
    assert_success response
    assert_equal '1012082907', response.authorization
  end

  def test_failed_refund
    @gateway.expects(:raw_ssl_request).returns(failed_refund_response)

    response = @gateway.refund(@amount, 'Authorization')
    assert_failure response
    assert_equal '20008', response.error_code
  end

  def test_successful_void
    @gateway.expects(:raw_ssl_request).returns(successful_void_response)

    response = @gateway.void('Authorization')
    assert_success response
    assert_equal '1012082919', response.authorization
  end

  def test_failed_void
    @gateway.expects(:raw_ssl_request).returns(failed_void_response)

    response = @gateway.void('Authorization')
    assert_failure response
    assert_equal '20008', response.error_code
  end

  def test_successful_verify
    @gateway.expects(:raw_ssl_request).returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal '1012082929', response.authorization
  end

  def test_failed_verify
    @gateway.expects(:raw_ssl_request).returns(failed_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal '14002', response.error_code
  end

  def test_successful_store
    @gateway.expects(:raw_ssl_request).returns(successful_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal '20936441', response.authorization
  end

  def test_successful_echeck_store
    @gateway.expects(:raw_ssl_request).returns(successful_echeck_store_response)

    response = @gateway.store(@check, @options)
    assert_success response
    assert_equal '23844081|check', response.authorization
  end

  def test_failed_store
    @gateway.expects(:raw_ssl_request).returns(failed_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_failure response
    assert_equal '14002', response.error_code
  end

  def test_failed_echeck_store
    @gateway.expects(:raw_ssl_request).returns(failed_echeck_store_response)

    response = @gateway.store(@check, @options)
    assert_failure response
    assert_equal '10001', response.error_code
  end

  def test_currency_added_correctly
    stub_comms(@gateway, :raw_ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge(currency: 'CAD'))
    end.check_request do |_method, _url, data|
      assert_match(/<currency>CAD<\/currency>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_verify_good_credentials
    @gateway.expects(:raw_ssl_request).returns(credentials_are_legit_response)
    assert @gateway.verify_credentials
  end

  def test_verify_bad_credentials
    @gateway.expects(:raw_ssl_request).returns(credentials_are_bogus_response)
    assert !@gateway.verify_credentials
  end

  def test_failed_forbidden_response
    @gateway.expects(:raw_ssl_request).returns(forbidden_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '<xml>You are not authorized to perform this request due to inappropriate role permissions.</xml>', response.message
  end

  def test_failed_rate_limit_response
    @gateway.expects(:raw_ssl_request).returns(rate_limit_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '<xml>Client request rate is too high</xml>', response.message
  end

  def test_does_not_send_level_3_when_empty
    response = stub_comms(@gateway, :raw_ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_type, _endpoint, data, _headers|
      assert_not_match(/level-3-data/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_fraud_response_handling
    @gateway.expects(:raw_ssl_request).returns(fraudulent_purchase_response)

    response = @gateway.purchase(@fraudulent_amount, @credit_card, @options)
    assert_failure response
    assert_match(/fraud-reference-id/, response.message)
    assert_match(/fraud-event/, response.message)
  end

  def test_fraud_response_handling_multiple_triggers
    @gateway.expects(:raw_ssl_request).returns(fraudulent_purchase_response_multiple_triggers)

    response = @gateway.purchase(@fraudulent_amount, @fraudulent_card, @options)
    assert_failure response
    assert_match(/orderTotalDecline/, response.message)
    assert_match(/blacklistPaymentCountryDecline/, response.message)
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_echeck_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed_echeck), post_scrubbed_echeck
  end

  def test_localizes_currencies
    amount = 1234

    # Check a 2 decimal place currency
    assert_equal '12.34', check_amount_registered(amount, 'USD')

    # Check all 0 decimal currencies
    ActiveMerchant::Billing::BlueSnapGateway.currencies_without_fractions.each do |currency|
      assert_equal '12', check_amount_registered(amount, currency)
    end

    # Check all 3 decimal currencies
    ActiveMerchant::Billing::BlueSnapGateway.currencies_with_three_decimal_places.each do |currency|
      assert_equal '1.234', check_amount_registered(amount, currency)
    end
  end

  def test_optional_idempotency_key_header
    stub_comms(@gateway, :raw_ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge({ idempotency_key: 'test123' }))
    end.check_request do |_method, _url, _data, headers|
      assert_equal 'test123', headers['Idempotency-Key']
    end.respond_with(successful_authorize_response)
  end

  private

  def check_amount_registered(amount, currency)
    doc = BlueSnapCurrencyDocMock.new
    options = @options.merge(currency: currency)
    @gateway.send(:add_amount, doc, amount, options)

    doc.received_amount
  end

  def pre_scrubbed
    %q{
        opening connection to sandbox.bluesnap.com:443...
        starting SSL for sandbox.bluesnap.com:443...
        <- "POST /services/2/transactions HTTP/1.1\r\nContent-Type: application/xml\r\nAuthorization: Basic QVBJXzE0NjExNzM3MTY2NTc2NzM0MDQyMzpuZll3VHg4ZkZBdkpxQlhjeHF3Qzg=\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.bluesnap.com\r\nContent-Length: 683\r\n\r\n"
        <- "<card-transaction xmlns=\"http://ws.plimus.com\">\n  <card-transaction-type>AUTH_CAPTURE</card-transaction-type>\n  <recurring-transaction>RECURRING</recurring-transaction>\n  <amount>1.00</amount>\n  <currency>USD</currency>\n  <card-holder-info>\n    <first-name>Longbob</first-name>\n    <last-name>Longsen</last-name>\n    <country>CA</country>\n    <state>ON</state>\n    <city>Ottawa</city>\n    <zip>K1C2N6</zip>\n  </card-holder-info>\n  <transaction-fraud-info/>\n  <credit-card>\n    <card-number>4263982640269299</card-number>\n    <security-code>123</security-code>\n    <expiration-month>9</expiration-month>\n    <expiration-year>2017</expiration-year>\n  </credit-card>\n</card-transaction>"
        -> "HTTP/1.1 200 OK\r\n"
        -> "Set-Cookie: JSESSIONID=156258FCEC747EFAEA6FE909FDF0004A; Path=/services/; Secure; HttpOnly\r\n"
        -> "Content-Encoding: gzip\r\n"
        -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03mS]\x8F\xDA0\x10|\xCF\xAF@\xA9\xD47c\xA0\x1F:Z\xE3\x13\xCD\xD1\x16\xF5\xC4U\x81\xF4\xB52\xB1\xE1,%v\xE4u\xB8K"
        Conn close
    }
  end

  def pre_scrubbed_echeck
    %q{
        opening connection to sandbox.bluesnap.com:443...
        opened
        starting SSL for sandbox.bluesnap.com:443...
        SSL established
        <- "POST /services/2/alt-transactions HTTP/1.1\r\nContent-Type: application/xml\r\nAuthorization: Basic QVBJXzE0NjExNzM3MTY2NTc2NzM0MDQyMzpuZll3VHg4ZkZBdkpxQlhjeHF3Qzg=\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: sandbox.bluesnap.com\r\nContent-Length: 973\r\n\r\n"
        <- "<alt-transaction xmlns=\"http://ws.plimus.com\">\n  <amount>1.00</amount>\n  <currency>USD</currency>\n  <payer-info>\n    <first-name>Jim</first-name>\n    <last-name>Smith</last-name>\n    <state>CA</state>\n    <city>Happy City</city>\n    <zip>94901</zip>\n    <company-name>Jim Smith</company-name>\n  </payer-info>\n  <ecp-transaction>\n    <account-number>15378535</account-number>\n    <routing-number>244183602</routing-number>\n    <account-type>CORPORATE_CHECKING</account-type>\n  </ecp-transaction>\n  <authorized-by-shopper>true</authorized-by-shopper>\n  <transaction-fraud-info/>\n  </alt-transaction>"
        -> "HTTP/1.1 200 200\r\n"
        -> "Set-Cookie: JSESSIONID=65D503B9785EA6641D4757EA568A6532; Path=/services; Secure; HttpOnly\r\n"
        -> "Connection: close\r\n"
    }
  end

  def post_scrubbed
    %q{
        opening connection to sandbox.bluesnap.com:443...
        starting SSL for sandbox.bluesnap.com:443...
        <- "POST /services/2/transactions HTTP/1.1\r\nContent-Type: application/xml\r\nAuthorization: Basic [FILTERED]=\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.bluesnap.com\r\nContent-Length: 683\r\n\r\n"
        <- "<card-transaction xmlns=\"http://ws.plimus.com\">\n  <card-transaction-type>AUTH_CAPTURE</card-transaction-type>\n  <recurring-transaction>RECURRING</recurring-transaction>\n  <amount>1.00</amount>\n  <currency>USD</currency>\n  <card-holder-info>\n    <first-name>Longbob</first-name>\n    <last-name>Longsen</last-name>\n    <country>CA</country>\n    <state>ON</state>\n    <city>Ottawa</city>\n    <zip>K1C2N6</zip>\n  </card-holder-info>\n  <transaction-fraud-info/>\n  <credit-card>\n    <card-number>[FILTERED]</card-number>\n    <security-code>[FILTERED]</security-code>\n    <expiration-month>9</expiration-month>\n    <expiration-year>2017</expiration-year>\n  </credit-card>\n</card-transaction>"
        -> "HTTP/1.1 200 OK\r\n"
        -> "Set-Cookie: JSESSIONID=156258FCEC747EFAEA6FE909FDF0004A; Path=/services/; Secure; HttpOnly\r\n"
        -> "Content-Encoding: gzip\r\n"
        -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03mS]\x8F\xDA0\x10|\xCF\xAF@\xA9\xD47c\xA0\x1F:Z\xE3\x13\xCD\xD1\x16\xF5\xC4U\x81\xF4\xB52\xB1\xE1,%v\xE4u\xB8K"
        Conn close
    }
  end

  def post_scrubbed_echeck
    %q{
        opening connection to sandbox.bluesnap.com:443...
        opened
        starting SSL for sandbox.bluesnap.com:443...
        SSL established
        <- "POST /services/2/alt-transactions HTTP/1.1\r\nContent-Type: application/xml\r\nAuthorization: Basic [FILTERED]=\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: sandbox.bluesnap.com\r\nContent-Length: 973\r\n\r\n"
        <- "<alt-transaction xmlns=\"http://ws.plimus.com\">\n  <amount>1.00</amount>\n  <currency>USD</currency>\n  <payer-info>\n    <first-name>Jim</first-name>\n    <last-name>Smith</last-name>\n    <state>CA</state>\n    <city>Happy City</city>\n    <zip>94901</zip>\n    <company-name>Jim Smith</company-name>\n  </payer-info>\n  <ecp-transaction>\n    <account-number>[FILTERED]</account-number>\n    <routing-number>[FILTERED]</routing-number>\n    <account-type>CORPORATE_CHECKING</account-type>\n  </ecp-transaction>\n  <authorized-by-shopper>true</authorized-by-shopper>\n  <transaction-fraud-info/>\n  </alt-transaction>"
        -> "HTTP/1.1 200 200\r\n"
        -> "Set-Cookie: JSESSIONID=65D503B9785EA6641D4757EA568A6532; Path=/services; Secure; HttpOnly\r\n"
        -> "Connection: close\r\n"
    }
  end

  def successful_purchase_response
    MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <card-transaction xmlns="http://ws.plimus.com">
      <card-transaction-type>AUTH_CAPTURE</card-transaction-type>
      <transaction-id>1012082839</transaction-id>
      <recurring-transaction>ECOMMERCE</recurring-transaction>
      <soft-descriptor>BLS*Spreedly</soft-descriptor>
      <amount>1.00</amount>
      <currency>USD</currency>
      <card-holder-info>
          <first-name>Longbob</first-name>
          <last-name>Longsen</last-name>
          <country>CA</country>
          <state>ON</state>
          <city>Ottawa</city>
          <zip>K1C2N6</zip>
          <personal-identification-number>CNPJ</personal-identification-number>
      </card-holder-info>
      <credit-card>
          <card-last-four-digits>9299</card-last-four-digits>
          <card-type>VISA</card-type>
          <card-sub-type>CREDIT</card-sub-type>
      </credit-card>
      <processing-info>
          <processing-status>success</processing-status>
          <cvv-response-code>ND</cvv-response-code>
          <avs-response-code-zip>U</avs-response-code-zip>
          <avs-response-code-address>U</avs-response-code-address>
          <avs-response-code-name>U</avs-response-code-name>
      </processing-info>
      </card-transaction>
    XML
  end

  def successful_purchase_response_with_metadata
    MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <card-transaction xmlns="http://ws.plimus.com">
      <card-transaction-type>AUTH_CAPTURE</card-transaction-type>
      <transaction-id>1012082839</transaction-id>
      <recurring-transaction>ECOMMERCE</recurring-transaction>
      <soft-descriptor>BLS*Spreedly</soft-descriptor>
      <amount>1.00</amount>
      <currency>USD</currency>
      <card-holder-info>
          <first-name>Longbob</first-name>
          <last-name>Longsen</last-name>
          <country>CA</country>
          <state>ON</state>
          <city>Ottawa</city>
          <zip>K1C2N6</zip>
          <personal-identification-number>CNPJ</personal-identification-number>
      </card-holder-info>
      <credit-card>
          <card-last-four-digits>9299</card-last-four-digits>
          <card-type>VISA</card-type>
          <card-sub-type>CREDIT</card-sub-type>
      </credit-card>
      <transaction-meta-data>
        <meta-data>
            <meta-key>stateTaxAmount</meta-key>
            <meta-value>20.00</meta-value>
            <meta-description>State Tax Amount</meta-description>
        </meta-data>
        <meta-data>
            <meta-key>cityTaxAmount</meta-key>
            <meta-value>10.00</meta-value>
            <meta-description>City Tax Amount</meta-description>
        </meta-data>
        <meta-data>
            <meta-key>shippingAmount</meta-key>
            <meta-value>150.00</meta-value>
            <meta-description>Shipping Amount</meta-description>
        </meta-data>
        <meta-data>
            <meta-key>websiteInfo</meta-key>
            <meta-value>www.info.com</meta-value>
            <meta-description>Website</meta-description>
        </meta-data>
      </transaction-meta-data>
      <processing-info>
          <processing-status>success</processing-status>
          <cvv-response-code>ND</cvv-response-code>
          <avs-response-code-zip>U</avs-response-code-zip>
          <avs-response-code-address>U</avs-response-code-address>
          <avs-response-code-name>U</avs-response-code-name>
      </processing-info>
      </card-transaction>
    XML
  end

  def successful_purchase_with_3ds_auth_response
    MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <card-transaction xmlns="http://ws.plimus.com">
        <card-transaction-type>AUTH_CAPTURE</card-transaction-type>
        <transaction-id>1024951831</transaction-id>
        <recurring-transaction>ECOMMERCE</recurring-transaction>
        <soft-descriptor>BLS&#x2a;Spreedly</soft-descriptor>
        <amount>1.00</amount>
        <usd-amount>1.00</usd-amount>
        <currency>USD</currency>
        <avs-response-code>N</avs-response-code>
        <card-holder-info>
          <first-name>Longbob</first-name>
          <last-name>Longsen</last-name>
          <country>CA</country>
          <state>ON</state>
          <city>Ottawa</city>
          <zip>K1C2N6</zip>
        </card-holder-info>
        <vaulted-shopper-id>25105083</vaulted-shopper-id>
        <credit-card>
          <card-last-four-digits>1091</card-last-four-digits>
          <card-type>VISA</card-type>
          <card-sub-type>CREDIT</card-sub-type>
          <bin-category>CONSUMER</bin-category>
          <card-regulated>N</card-regulated>
          <issuing-country-code>us</issuing-country-code>
        </credit-card>
        <network-transaction-info>
          <original-network-transaction-id>019082915501456</original-network-transaction-id>
          <network-transaction-id>019082915501456</network-transaction-id>
        </network-transaction-info>
        <processing-info>
          <processing-status>success</processing-status>
          <cvv-response-code>NR</cvv-response-code>
          <avs-response-code-zip>N</avs-response-code-zip>
          <avs-response-code-address>N</avs-response-code-address>
          <avs-response-code-name>U</avs-response-code-name>
          <network-transaction-id>019082915501456</network-transaction-id>
        </processing-info>
      </card-transaction>
    XML
  end

  def successful_echeck_purchase_response
    MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <alt-transaction xmlns="http://ws.plimus.com">
        <transaction-id>1019803029</transaction-id>
        <amount>1.00</amount>
        <currency>USD</currency>
        <payer-info>
          <first-name>Jim</first-name>
          <last-name>Smith</last-name>
          <state>CA</state>
          <city>Happy City</city>
          <zip>94901</zip>
          <company-name>Jim Smith</company-name>
        </payer-info>
        <ecp-transaction>
          <account-number>15378535</account-number>
          <routing-number>244183602</routing-number>
          <account-type>CORPORATE_CHECKING</account-type>
        </ecp-transaction>
        <processing-info>
          <processing-status>PENDING</processing-status>
        </processing-info>
      </alt-transaction>
    XML
  end

  def successful_stateless_purchase_response
    MockResponse.succeeded <<-XML
      <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
      <card-transaction xmlns=\"http://ws.plimus.com\">
      <card-transaction-type>AUTH_CAPTURE</card-transaction-type>
      <transaction-id>1021645629</transaction-id>
      <recurring-transaction>ECOMMERCE</recurring-transaction>
      <soft-descriptor>BLS&#x2a;Spreedly</soft-descriptor>
      <amount>1.00</amount>
      <usd-amount>1.00</usd-amount>
      <currency>USD</currency>
      <card-holder-info>
          <first-name>Longbob</first-name>
          <last-name>Longsen</last-name>
          <country>DE</country>
          <city>Dresden</city>
          <zip>01069</zip>
      </card-holder-info>
      <vaulted-shopper-id>24449087</vaulted-shopper-id>
      <credit-card>
          <card-last-four-digits>9299</card-last-four-digits>
          <card-type>VISA</card-type>
          <card-sub-type>CREDIT</card-sub-type>
          <card-category>PLATINUM</card-category>
          <bin-category>CONSUMER</bin-category>
          <card-regulated>N</card-regulated>
          <issuing-bank>ALLIED IRISH BANKS PLC</issuing-bank>
          <issuing-country-code>ie</issuing-country-code>
      </credit-card>
      <processing-info>
      <processing-status>success</processing-status>
          <cvv-response-code>ND</cvv-response-code>
          <avs-response-code-zip>U</avs-response-code-zip>
          <avs-response-code-address>U</avs-response-code-address>
          <avs-response-code-name>U</avs-response-code-name>
      </processing-info>
      </card-transaction>
    XML
  end

  def failed_purchase_response
    body = <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <messages xmlns="http://ws.plimus.com">
        <message>
          <error-name>INCORRECT_INFORMATION</error-name>
          <code>14002</code>
          <description>Transaction failed  because of payment processing failure.: 430285 - Authorization has failed for this transaction. Please try again or contact your bank for assistance</description>
        </message>
      </messages>
    XML

    MockResponse.failed(body, 400)
  end

  def failed_echeck_purchase_response
    body = <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <messages xmlns="http://ws.plimus.com">
        <message>
          <error-name>PAYMENT_NOT_AUTHORIZED_BY_SHOPPER</error-name>
          <code>16004</code>
          <description>The payment was not authorized by shopper. Missing/Invalid 'authorized-by-shopper' element.</description>
        </message>
      </messages>
    XML

    MockResponse.failed(body, 400)
  end

  def successful_authorize_response
    MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <card-transaction xmlns="http://ws.plimus.com">
      <card-transaction-type>AUTH_ONLY</card-transaction-type>
      <transaction-id>1012082893</transaction-id>
      <recurring-transaction>ECOMMERCE</recurring-transaction>
      <soft-descriptor>BLS*Spreedly</soft-descriptor>
      <amount>1.00</amount>
      <currency>USD</currency>
      <card-holder-info>
          <first-name>Longbob</first-name>
          <last-name>Longsen</last-name>
          <country>CA</country>
          <state>ON</state>
          <city>Ottawa</city>
          <zip>K1C2N6</zip>
          <personal-identification-number>CNPJ</personal-identification-number>
      </card-holder-info>
      <credit-card>
          <card-last-four-digits>9299</card-last-four-digits>
          <card-type>VISA</card-type>
          <card-sub-type>CREDIT</card-sub-type>
      </credit-card>
      <processing-info>
          <processing-status>success</processing-status>
          <cvv-response-code>ND</cvv-response-code>
          <avs-response-code-zip>U</avs-response-code-zip>
          <avs-response-code-address>U</avs-response-code-address>
          <avs-response-code-name>U</avs-response-code-name>
      </processing-info>
      </card-transaction>
    XML
  end

  def successful_authorize_with_3ds_auth_response
    MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <card-transaction xmlns="http://ws.plimus.com">
        <card-transaction-type>AUTH_ONLY</card-transaction-type>
        <transaction-id>1024951833</transaction-id>
        <recurring-transaction>ECOMMERCE</recurring-transaction>
        <soft-descriptor>BLS&#x2a;Spreedly</soft-descriptor>
        <amount>1.00</amount>
        <usd-amount>1.00</usd-amount>
        <currency>USD</currency>
        <avs-response-code>S</avs-response-code>
        <card-holder-info>
          <first-name>Longbob</first-name>
          <last-name>Longsen</last-name>
          <country>CA</country>
          <state>ON</state>
          <city>Ottawa</city>
          <zip>K1C2N6</zip>
        </card-holder-info>
        <vaulted-shopper-id>25105085</vaulted-shopper-id>
        <credit-card>
          <card-last-four-digits>1096</card-last-four-digits>
          <card-type>MASTERCARD</card-type>
          <card-sub-type>CREDIT</card-sub-type>
          <card-category>STANDARD</card-category>
          <bin-category>CONSUMER</bin-category>
          <card-regulated>N</card-regulated>
          <issuing-bank>PUBLIC BANK BERHAD</issuing-bank>
          <issuing-country-code>my</issuing-country-code>
        </credit-card>
        <network-transaction-info>
          <original-network-transaction-id>MCC8929120829</original-network-transaction-id>
          <network-transaction-id>MCC8929120829</network-transaction-id>
        </network-transaction-info>
        <processing-info>
          <processing-status>success</processing-status>
          <cvv-response-code>NC</cvv-response-code>
          <avs-response-code-zip>U</avs-response-code-zip>
          <avs-response-code-address>U</avs-response-code-address>
          <avs-response-code-name>U</avs-response-code-name>
          <network-transaction-id>MCC8929120829</network-transaction-id>
        </processing-info>
      </card-transaction>
    XML
  end

  def failed_authorize_response
    body = <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <messages xmlns="http://ws.plimus.com">
      <message>
          <error-name>INCORRECT_INFORMATION</error-name>
          <code>14002</code>
          <description>Transaction failed  because of payment processing failure.: 430285 - Authorization has failed for this transaction. Please try again or contact your bank for assistance</description>
      </message>
      </messages>
    XML
    MockResponse.failed(body, 400)
  end

  def successful_capture_response
    MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <card-transaction xmlns="http://ws.plimus.com">
      <card-transaction-type>CAPTURE</card-transaction-type>
      <transaction-id>1012082881</transaction-id>
      <recurring-transaction>ECOMMERCE</recurring-transaction>
      <soft-descriptor>BLS*Spreedly</soft-descriptor>
      <amount>1.00</amount>
      <currency>USD</currency>
      <card-holder-info>
          <first-name>Longbob</first-name>
          <last-name>Longsen</last-name>
          <country>ca</country>
          <state>ON</state>
          <city>Ottawa</city>
          <zip>K1C2N6</zip>
          <personal-identification-number>CNPJ</personal-identification-number>
      </card-holder-info>
      <credit-card>
          <card-last-four-digits>9299</card-last-four-digits>
          <card-type>VISA</card-type>
          <card-sub-type>CREDIT</card-sub-type>
      </credit-card>
      <processing-info>
          <processing-status>SUCCESS</processing-status>
          <cvv-response-code>ND</cvv-response-code>
          <avs-response-code-zip>U</avs-response-code-zip>
          <avs-response-code-address>U</avs-response-code-address>
          <avs-response-code-name>U</avs-response-code-name>
      </processing-info>
      </card-transaction>
    XML
  end

  def failed_capture_response
    body = <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <messages xmlns="http://ws.plimus.com">
      <message>
          <error-name>TRANSACTION_ID_REQUIRED</error-name>
          <code>20008</code>
          <description>Transaction operation cannot be completed due to missing transaction ID parameter.</description>
      </message>
      </messages>
    XML
    MockResponse.failed(body, 400)
  end

  def successful_refund_response
    MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <card-transaction xmlns="http://ws.plimus.com">
         <card-transaction-type>REFUND</card-transaction-type>
         <transaction-id>1012082907</transaction-id>
         <recurring-transaction>ECOMMERCE</recurring-transaction>
         <soft-descriptor>BLS*Spreedly</soft-descriptor>
         <amount>1.00</amount>
         <currency>USD</currency>
         <card-holder-info>
            <first-name>Longbob</first-name>
            <last-name>Longsen</last-name>
            <country>ca</country>
            <state>ON</state>
            <city>Ottawa</city>
            <zip>K1C2N6</zip>
            <personal-identification-number>CNPJ</personal-identification-number>
         </card-holder-info>
         <credit-card>
            <card-last-four-digits>9299</card-last-four-digits>
            <card-type>VISA</card-type>
            <card-sub-type>CREDIT</card-sub-type>
         </credit-card>
         <processing-info>
            <processing-status>SUCCESS</processing-status>
            <cvv-response-code>ND</cvv-response-code>
            <avs-response-code-zip>U</avs-response-code-zip>
            <avs-response-code-address>U</avs-response-code-address>
            <avs-response-code-name>U</avs-response-code-name>
         </processing-info>
      </card-transaction>
    XML
  end

  def failed_refund_response
    body = <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <messages xmlns="http://ws.plimus.com">
         <message>
            <error-name>TRANSACTION_ID_REQUIRED</error-name>
            <code>20008</code>
            <description>Transaction operation cannot be completed due to missing transaction ID parameter.</description>
         </message>
      </messages>
    XML
    MockResponse.failed(body, 400)
  end

  def successful_refund_without_merchant_transaction_id_response
    MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <refund xmlns="http://ws.plimus.com">
        <refund-transaction-id>1061398943</refund-transaction-id>
        <amount>1.00</amount>
        <tax-amount>0.05</tax-amount>
        <transaction-meta-data>
          <meta-data>
            <meta-key>refundedItems</meta-key>
            <meta-value>1552,8832</meta-value>
            <meta-description>Refunded Items</meta-description>
            <is-visible>false</is-visible>
          </meta-data>
          <meta-data>
            <meta-key>Number2</meta-key>
            <meta-value>KTD</meta-value>
            <meta-description>Metadata 2</meta-description>
            <is-visible>true</is-visible>
          </meta-data>
        </transaction-meta-data>
        <reason>Refund for order #1992</reason>
      </refund>
    XML
  end

  def successful_void_response
    MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <card-transaction xmlns="http://ws.plimus.com">
         <card-transaction-type>AUTH_REVERSAL</card-transaction-type>
         <transaction-id>1012082919</transaction-id>
         <recurring-transaction>ECOMMERCE</recurring-transaction>
         <soft-descriptor>BLS*Spreedly</soft-descriptor>
         <amount>1.00</amount>
         <currency>USD</currency>
         <card-holder-info>
            <first-name>Longbob</first-name>
            <last-name>Longsen</last-name>
            <country>ca</country>
            <state>ON</state>
            <city>Ottawa</city>
            <zip>K1C2N6</zip>
            <personal-identification-number>CNPJ</personal-identification-number>
         </card-holder-info>
         <credit-card>
            <card-last-four-digits>9299</card-last-four-digits>
            <card-type>VISA</card-type>
            <card-sub-type>CREDIT</card-sub-type>
         </credit-card>
         <processing-info>
            <processing-status>SUCCESS</processing-status>
            <cvv-response-code>ND</cvv-response-code>
            <avs-response-code-zip>U</avs-response-code-zip>
            <avs-response-code-address>U</avs-response-code-address>
            <avs-response-code-name>U</avs-response-code-name>
         </processing-info>
      </card-transaction>
    XML
  end

  def failed_void_response
    body = <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <messages xmlns="http://ws.plimus.com">
        <message>
          <error-name>TRANSACTION_ID_REQUIRED</error-name>
          <code>20008</code>
          <description>Transaction operation cannot be completed due to missing transaction ID parameter.</description>
        </message>
      </messages>
    XML
    MockResponse.failed(body, 400)
  end

  def successful_verify_response
    MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <card-transaction xmlns="http://ws.plimus.com">
        <card-transaction-type>AUTH_ONLY</card-transaction-type>
        <transaction-id>1012082929</transaction-id>
        <recurring-transaction>ECOMMERCE</recurring-transaction>
        <soft-descriptor>Spreedly</soft-descriptor>
        <amount>0.00</amount>
        <currency>USD</currency>
        <card-holder-info>
          <first-name>Longbob</first-name>
          <last-name>Longsen</last-name>
          <country>CA</country>
          <state>ON</state>
          <city>Ottawa</city>
          <zip>K1C2N6</zip>
          <personal-identification-number>CNPJ</personal-identification-number>
        </card-holder-info>
        <credit-card>
          <card-last-four-digits>9299</card-last-four-digits>
          <card-type>VISA</card-type>
          <card-sub-type>CREDIT</card-sub-type>
        </credit-card>
        <processing-info>
          <processing-status>success</processing-status>
          <cvv-response-code>ND</cvv-response-code>
          <avs-response-code-zip>U</avs-response-code-zip>
          <avs-response-code-address>U</avs-response-code-address>
          <avs-response-code-name>U</avs-response-code-name>
        </processing-info>
      </card-transaction>
    XML
  end

  def failed_verify_response
    body = <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <messages xmlns="http://ws.plimus.com">
        <message>
          <error-name>INCORRECT_INFORMATION</error-name>
          <code>14002</code>
          <description>Transaction failed  because of payment processing failure.: 430285 - Authorization has failed for this transaction. Please try again or contact your bank for assistance</description>
        </message>
      </messages>
    XML
    MockResponse.failed(body, 400)
  end

  def successful_store_response
    response = MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <vaulted-shopper xmlns="http://ws.plimus.com">
        <first-name>Longbob</first-name>
        <last-name>Longsen</last-name>
        <country>ca</country>
        <state>ON</state>
        <city>Ottawa</city>
        <zip>K1C2N6</zip>
        <personal-identification-number>CNPJ</personal-identification-number>
        <shopper-currency>USD</shopper-currency>
        <payment-sources>
          <credit-card-info>
            <billing-contact-info>
              <first-name>Longbob</first-name>
              <last-name>Longsen</last-name>
              <city />
            </billing-contact-info>
            <credit-card>
              <card-last-four-digits>9299</card-last-four-digits>
              <card-type>VISA</card-type>
              <card-sub-type>CREDIT</card-sub-type>
            </credit-card>
            <processing-info>
              <cvv-response-code>ND</cvv-response-code>
              <avs-response-code-zip>U</avs-response-code-zip>
              <avs-response-code-address>U</avs-response-code-address>
              <avs-response-code-name>U</avs-response-code-name>
            </processing-info>
          </credit-card-info>
        </payment-sources>
      </vaulted-shopper>
    XML

    response.headers = { 'content-location' => 'https://sandbox.bluesnap.com/services/2/vaulted-shoppers/20936441' }
    response
  end

  def successful_echeck_store_response
    response = MockResponse.succeeded <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <vaulted-shopper xmlns="http://ws.plimus.com">
        <vaulted-shopper-id>23844081</vaulted-shopper-id>
        <first-name>Jim</first-name>
        <last-name>Smith</last-name>
        <city>Happy City</city>
        <zip>94901</zip>
        <company-name>Jim Smith</company-name>
        <shopper-currency>USD</shopper-currency>
        <payment-sources>
          <ecp-info>
            <billing-contact-info>
              <first-name>Jim</first-name>
              <last-name>Smith</last-name>
              <city></city>
              <company-name>Jim Smith</company-name>
            </billing-contact-info>
            <ecp>
              <account-number>15378535</account-number>
              <routing-number>244183602</routing-number>
              <account-type>CORPORATE_CHECKING</account-type>
            </ecp>
          </ecp-info>
        </payment-sources>
      </vaulted-shopper>
    XML

    response.headers = { 'content-location' => 'https://sandbox.bluesnap.com/services/2/vaulted-shoppers/23844081' }
    response
  end

  def failed_store_response
    body =  <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <messages xmlns="http://ws.plimus.com">
        <message>
          <error-name>INCORRECT_INFORMATION</error-name>
          <code>14002</code>
          <description>Transaction failed  because of payment processing failure.: 430285 - Authorization has failed for this transaction. Please try again or contact your bank for assistance</description>
        </message>
      </messages>
    XML
    MockResponse.failed(body, 400)
  end

  def failed_echeck_store_response
    body =  <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <messages xmlns="http://ws.plimus.com">
        <message>
          <error-name>VALIDATION_GENERAL_FAILURE</error-name>
          <code>10001</code>
          <description>ECP data validity check failed</description>
        </message>
      </messages>
    XML
    MockResponse.failed(body, 400)
  end

  def forbidden_response
    MockResponse.new(403, '<xml>You are not authorized to perform this request due to inappropriate role permissions.</xml>')
  end

  def rate_limit_response
    MockResponse.new(429, '<xml>Client request rate is too high</xml>')
  end

  def fraudulent_purchase_response
    body = <<-XML
      <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <messages xmlns=\"http://ws.plimus.com\">
          <message>
            <error-name>FRAUD_DETECTED</error-name>
            <code>15011</code>
            <description>The request cannot be fulfilled for the current shopper. Please contact BlueSnap support for further details.</description>
            <fraud-events>
              <fraud-reference-id>6270209</fraud-reference-id>
              <fraud-event>
                <fraud-event-code>orderTotalDecline</fraud-event-code>
                <fraud-event-decision>D</fraud-event-decision>
                <fraud-event-expression>3729 &gt; 3728</fraud-event-expression>
              </fraud-event>
            </fraud-events>
          </message>
        </messages>
    XML
    MockResponse.new(400, body)
  end

  def fraudulent_purchase_response_multiple_triggers
    body = <<-XML
      <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <messages xmlns=\"http://ws.plimus.com\">
          <message>
            <error-name>FRAUD_DETECTED</error-name>
            <code>15011</code>
            <description>The request cannot be fulfilled for the current shopper. Please contact BlueSnap support for further details.</description>
            <fraud-events>
              <fraud-reference-id>6270189</fraud-reference-id>
              <fraud-event>
                <fraud-event-code>blacklistPaymentCountryDecline</fraud-event-code>
                <fraud-event-decision>D</fraud-event-decision>
                <fraud-event-expression>BR is in list: [BR]</fraud-event-expression>
              </fraud-event>
              <fraud-event>
                <fraud-event-code>orderTotalDecline</fraud-event-code>
                <fraud-event-decision>D</fraud-event-decision>
                <fraud-event-expression>3729 &gt; 3728</fraud-event-expression>
              </fraud-event>
            </fraud-events>
          </message>
        </messages>
    XML
    MockResponse.new(400, body)
  end

  def credentials_are_legit_response
    MockResponse.new(400, '<xml>Server Error</xml>')
  end

  def credentials_are_bogus_response
    MockResponse.new(401, %{<!DOCTYPE html><html lang="en"><head><title>HTTP Status 401 – Unauthorized</title><style type="text/css">h1 {font-family:Tahoma,Arial,sans-serif;color:white;background-color:#525D76;font-size:22px;} h2 {font-family:Tahoma,Arial,sans-serif;color:white;background-color:#525D76;font-size:16px;} h3 {font-family:Tahoma,Arial,sans-serif;color:white;background-color:#525D76;font-size:14px;} body {font-family:Tahoma,Arial,sans-serif;color:black;background-color:white;} b {font-family:Tahoma,Arial,sans-serif;color:white;background-color:#525D76;} p {font-family:Tahoma,Arial,sans-serif;background:white;color:black;font-size:12px;} a {color:black;} a.name {color:black;} .line {height:1px;background-color:#525D76;border:none;}</style></head><body><h1>HTTP Status 401 – Unauthorized</h1><hr class="line" /><p><b>Type</b> Status Report</p><p><b>Message</b> Bad credentials</p><p><b>Description</b> The request has not been applied because it lacks valid authentication credentials for the target resource.</p><hr class="line" /><h3>Apache Tomcat Version X</h3></body></html>})
  end
end
