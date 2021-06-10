require 'test_helper'
require 'nokogiri'

class CyberSourceTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.mode = :test

    @gateway = CyberSourceGateway.new(
      login: 'l',
      password: 'p'
    )

    @amount = 100
    @customer_ip = '127.0.0.1'
    @credit_card = credit_card('4111111111111111', brand: 'visa')
    @master_credit_card = credit_card('4111111111111111', brand: 'master')
    @elo_credit_card = credit_card('5067310000000010', brand: 'elo')
    @declined_card = credit_card('801111111111111', brand: 'visa')
    @check = check()

    @options = {
      ip: @customer_ip,
      order_id: '1000',
      line_items: [
        {
          declared_value: @amount,
          quantity: 2,
          code: 'default',
          description: 'Giant Walrus',
          sku: 'WA323232323232323'
        },
        {
          declared_value: @amount,
          quantity: 2,
          description: 'Marble Snowcone',
          sku: 'FAKE1232132113123'
        }
      ],
      currency: 'USD'
    }

    @subscription_options = {
      order_id: generate_unique_id,
      credit_card: @credit_card,
      setup_fee: 100,
      subscription: {
        frequency: 'weekly',
        start_date: Date.today.next_week,
        occurrences: 4,
        automatic_renew: true,
        amount: 100
      }
    }

    @issuer_additional_data = 'PR25000000000011111111111112222222sk111111111111111111111111111'
    + '1111111115555555222233101abcdefghijkl7777777777777777777777777promotionCde'
  end

  def test_successful_credit_card_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert_equal "#{@options[:order_id]};#{response.params['requestID']};#{response.params['requestToken']};purchase;100;USD;", response.authorization
    assert response.test?
  end

  def test_successful_credit_card_purchase_with_elo
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @elo_credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert_equal "#{@options[:order_id]};#{response.params['requestID']};#{response.params['requestToken']};purchase;100;USD;", response.authorization
    assert response.test?
  end

  def test_purchase_includes_customer_ip
    customer_ip_regexp = /<ipAddress>#{@customer_ip}<\//
    @gateway.expects(:ssl_post).
      with(anything, regexp_matches(customer_ip_regexp), anything).
      returns('')
    @gateway.expects(:parse).returns({})
    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_purchase_includes_issuer_additional_data
    stub_comms do
      @gateway.purchase(100, @credit_card, order_id: '1', issuer_additional_data: @issuer_additional_data)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<issuer>\s+<additionalData>#{@issuer_additional_data}<\/additionalData>\s+<\/issuer>/m, data)
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_includes_mdd_fields
    stub_comms do
      @gateway.purchase(100, @credit_card, order_id: '1', mdd_field_2: 'CustomValue2', mdd_field_3: 'CustomValue3')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<mddField id=\"2\">CustomValue2</m, data)
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_includes_reconciliation_id
    stub_comms do
      @gateway.purchase(100, @credit_card, order_id: '1', reconciliation_id: '181537')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<reconciliationID>181537<\/reconciliationID>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_merchant_description
    stub_comms do
      @gateway.authorize(100, @credit_card, merchant_descriptor_name: 'Test Name', merchant_descriptor_address1: '123 Main Dr', merchant_descriptor_locality: 'Durham')
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<merchantDescriptor>.*<name>Test Name</name>.*</merchantDescriptor>)m, data)
      assert_match(%r(<merchantDescriptor>.*<address1>123 Main Dr</address1>.*</merchantDescriptor>)m, data)
      assert_match(%r(<merchantDescriptor>.*<locality>Durham</locality>.*</merchantDescriptor>)m, data)
    end.respond_with(successful_purchase_response)
  end

  def test_allows_nil_values_in_billing_address
    billing_address = {
      address1: '123 Fourth St',
      city: 'Fiveton',
      state: '',
      country: 'CA'
    }

    stub_comms do
      @gateway.authorize(100, @credit_card, billing_address: billing_address)
    end.check_request do |_endpoint, data, _headers|
      assert_nil billing_address[:zip]
      assert_nil billing_address[:phone]
      assert_match(%r(<billTo>.*<street1>123 Fourth St</street1>.*</billTo>)m, data)
      assert_match(%r(<billTo>.*<city>Fiveton</city>.*</billTo>)m, data)
      assert_match(%r(<billTo>.*<state>NC</state>.*</billTo>)m, data)
      assert_match(%r(<billTo>.*<postalCode>00000</postalCode>.*</billTo>)m, data)
      assert_match(%r(<billTo>.*<country>CA</country>.*</billTo>)m, data)
    end.respond_with(successful_purchase_response)
  end

  def test_uses_names_from_billing_address_if_present
    name = 'Wesley Crusher'

    stub_comms do
      @gateway.authorize(100, @credit_card, billing_address: { name: name })
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<billTo>.*<firstName>Wesley</firstName>.*</billTo>)m, data)
      assert_match(%r(<billTo>.*<lastName>Crusher</lastName>.*</billTo>)m, data)
    end.respond_with(successful_purchase_response)
  end

  def test_uses_names_from_shipping_address_if_present
    name = 'Wesley Crusher'

    stub_comms do
      @gateway.authorize(100, @credit_card, shipping_address: { name: name })
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<shipTo>.*<firstName>Wesley</firstName>.*</shipTo>)m, data)
      assert_match(%r(<shipTo>.*<lastName>Crusher</lastName>.*</shipTo>)m, data)
    end.respond_with(successful_purchase_response)
  end

  def test_uses_names_from_the_payment_method
    stub_comms do
      @gateway.authorize(100, @credit_card)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<shipTo>.*<firstName>#{@credit_card.first_name}</firstName>.*</shipTo>)m, data)
      assert_match(%r(<shipTo>.*<lastName>#{@credit_card.last_name}</lastName>.*</shipTo>)m, data)
      assert_match(%r(<billTo>.*<firstName>#{@credit_card.first_name}</firstName>.*</billTo>)m, data)
      assert_match(%r(<billTo>.*<lastName>#{@credit_card.last_name}</lastName>.*</billTo>)m, data)
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_includes_merchant_descriptor
    stub_comms do
      @gateway.purchase(100, @credit_card, merchant_descriptor: 'Spreedly')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<merchantDescriptor>Spreedly<\/merchantDescriptor>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_authorize_includes_issuer_additional_data
    stub_comms do
      @gateway.authorize(100, @credit_card, order_id: '1', issuer_additional_data: @issuer_additional_data)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<issuer>\s+<additionalData>#{@issuer_additional_data}<\/additionalData>\s+<\/issuer>/m, data)
    end.respond_with(successful_authorization_response)
  end

  def test_authorize_includes_mdd_fields
    stub_comms do
      @gateway.authorize(100, @credit_card, order_id: '1', mdd_field_2: 'CustomValue2', mdd_field_3: 'CustomValue3')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<mddField id=\"2\">CustomValue2</m, data)
    end.respond_with(successful_authorization_response)
  end

  def test_authorize_includes_reconciliation_id
    stub_comms do
      @gateway.authorize(100, @credit_card, order_id: '1', reconciliation_id: '181537')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<reconciliationID>181537<\/reconciliationID>/, data)
    end.respond_with(successful_authorization_response)
  end

  def test_authorize_includes_commerce_indicator
    stub_comms do
      @gateway.authorize(100, @credit_card, commerce_indicator: 'internet')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<commerceIndicator>internet<\/commerceIndicator>/m, data)
    end.respond_with(successful_authorization_response)
  end

  def test_authorize_includes_installment_data
    stub_comms do
      @gateway.authorize(100, @credit_card, order_id: '1', installment_total_count: 5, installment_plan_type: 1, first_installment_date: '300101')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<installment>\s+<totalCount>5<\/totalCount>\s+<planType>1<\/planType>\s+<firstInstallmentDate>300101<\/firstInstallmentDate>\s+<\/installment>/, data)
    end.respond_with(successful_authorization_response)
  end

  def test_authorize_includes_merchant_tax_id_in_billing_address_but_not_shipping_address
    stub_comms do
      @gateway.authorize(100, @credit_card, order_id: '1', merchant_tax_id: '123')
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<billTo>.*<merchantTaxID>123</merchantTaxID>.*</billTo>)m, data)
      assert_not_match(%r(<shipTo>.*<merchantTaxID>123</merchantTaxID>.*</shipTo>)m, data)
    end.respond_with(successful_authorization_response)
  end

  def test_authorize_includes_sales_slip_number
    stub_comms do
      @gateway.authorize(100, @credit_card, order_id: '1', sales_slip_number: '123')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<salesSlipNumber>123<\/salesSlipNumber>/, data)
    end.respond_with(successful_authorization_response)
  end

  def test_authorize_includes_airline_agent_code
    stub_comms do
      @gateway.authorize(100, @credit_card, order_id: '1', airline_agent_code: '7Q')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<airlineData>\s+<agentCode>7Q<\/agentCode>\s+<\/airlineData>/, data)
    end.respond_with(successful_authorization_response)
  end

  def test_successful_check_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @check, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert_equal "#{@options[:order_id]};#{response.params['requestID']};#{response.params['requestToken']};purchase;100;USD;", response.authorization
    assert response.test?
  end

  def test_successful_pinless_debit_card_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(pinless_debit_card: true))
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert_equal "#{@options[:order_id]};#{response.params['requestID']};#{response.params['requestToken']};purchase;100;USD;", response.authorization
    assert response.test?
  end

  def test_successful_credit_cart_purchase_single_request_ignore_avs
    @gateway.expects(:ssl_post).with do |_host, request_body|
      assert_match %r'<ignoreAVSResult>true</ignoreAVSResult>', request_body
      assert_not_match %r'<ignoreCVResult>', request_body
      true
    end.returns(successful_purchase_response)

    options = @options.merge(ignore_avs: true)
    assert response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_successful_credit_cart_purchase_single_request_without_ignore_avs
    @gateway.expects(:ssl_post).with do |_host, request_body|
      assert_not_match %r'<ignoreAVSResult>', request_body
      assert_not_match %r'<ignoreCVResult>', request_body
      true
    end.returns(successful_purchase_response)

    # globally ignored AVS for gateway instance:
    @gateway.options[:ignore_avs] = true

    options = @options.merge(ignore_avs: false)
    assert response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_successful_credit_cart_purchase_single_request_ignore_ccv
    @gateway.expects(:ssl_post).with do |_host, request_body|
      assert_not_match %r'<ignoreAVSResult>', request_body
      assert_match %r'<ignoreCVResult>true</ignoreCVResult>', request_body
      true
    end.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(
                                                                 ignore_cvv: true
                                                               ))
    assert_success response
  end

  def test_successful_credit_cart_purchase_single_request_without_ignore_ccv
    @gateway.expects(:ssl_post).with do |_host, request_body|
      assert_not_match %r'<ignoreAVSResult>', request_body
      assert_not_match %r'<ignoreCVResult>', request_body
      true
    end.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(
                                                                 ignore_cvv: false
                                                               ))
    assert_success response
  end

  def test_successful_reference_purchase
    @gateway.stubs(:ssl_post).returns(successful_create_subscription_response, successful_purchase_response)

    assert_success(response = @gateway.store(@credit_card, @subscription_options))
    assert_success(@gateway.purchase(@amount, response.authorization, @options))
    assert response.test?
  end

  def test_unsuccessful_authorization
    @gateway.expects(:ssl_post).returns(unsuccessful_authorization_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    refute_equal 'Successful transaction', response.message
    assert_instance_of Response, response
    assert_failure response
  end

  def test_unsuccessful_authorization_with_reply
    @gateway.expects(:ssl_post).returns(unsuccessful_authorization_response_with_reply)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    refute_equal 'Successful transaction', response.message
    assert_equal '481', response.params['reasonCode']
    assert_instance_of Response, response
    assert_failure response
  end

  def test_successful_auth_request
    @gateway.stubs(:ssl_post).returns(successful_authorization_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal Response, response.class
    assert response.success?
    assert response.test?
  end

  def test_successful_auth_with_elo_request
    @gateway.stubs(:ssl_post).returns(successful_authorization_response)
    assert response = @gateway.authorize(@amount, @elo_credit_card, @options)
    assert_equal Response, response.class
    assert response.success?
    assert response.test?
  end

  def test_successful_credit_card_tax_request
    @gateway.stubs(:ssl_post).returns(successful_tax_response)
    assert response = @gateway.calculate_tax(@credit_card, @options)
    assert_equal Response, response.class
    assert response.success?
    assert response.test?
  end

  def test_successful_credit_card_capture_request
    @gateway.stubs(:ssl_post).returns(successful_authorization_response, successful_capture_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert response.success?
    assert response.test?
    assert response_capture = @gateway.capture(@amount, response.authorization)
    assert response_capture.success?
    assert response_capture.test?
  end

  def test_capture_includes_local_tax_amount
    stub_comms do
      @gateway.capture(100, '1842651133440156177166', local_tax_amount: '0.17')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<otherTax>\s+<localTaxAmount>0.17<\/localTaxAmount>\s+<\/otherTax>/, data)
    end.respond_with(successful_capture_response)
  end

  def test_capture_includes_national_tax_amount
    stub_comms do
      @gateway.capture(100, '1842651133440156177166', national_tax_amount: '0.05')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<otherTax>\s+<nationalTaxAmount>0.05<\/nationalTaxAmount>\s+<\/otherTax>/, data)
    end.respond_with(successful_capture_response)
  end

  def test_successful_credit_card_capture_with_elo_request
    @gateway.stubs(:ssl_post).returns(successful_authorization_response, successful_capture_response)
    assert response = @gateway.authorize(@amount, @elo_credit_card, @options)
    assert response.success?
    assert response.test?
    assert response_capture = @gateway.capture(@amount, response.authorization)
    assert response_capture.success?
    assert response_capture.test?
  end

  def test_capture_includes_mdd_fields
    stub_comms do
      @gateway.capture(100, '1846925324700976124593', order_id: '1', mdd_field_2: 'CustomValue2', mdd_field_3: 'CustomValue3')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<mddField id=\"2\">CustomValue2</m, data)
    end.respond_with(successful_capture_response)
  end

  def test_successful_credit_card_purchase_request
    @gateway.stubs(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert response.success?
    assert response.test?
  end

  def test_successful_credit_card_purchase_with_elo_request
    @gateway.stubs(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.purchase(@amount, @elo_credit_card, @options)
    assert response.success?
    assert response.test?
  end

  def test_successful_check_purchase_request
    @gateway.stubs(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.purchase(@amount, @check, @options)
    assert response.success?
    assert response.test?
  end

  def test_requires_error_on_tax_calculation_without_line_items
    assert_raise(ArgumentError) { @gateway.calculate_tax(@credit_card, @options.delete_if { |key, _val| key == :line_items }) }
  end

  def test_default_currency
    assert_equal 'USD', CyberSourceGateway.default_currency
  end

  def test_successful_credit_card_store_request
    @gateway.stubs(:ssl_post).returns(successful_create_subscription_response)
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?
  end

  def test_successful_credit_card_update_request
    @gateway.stubs(:ssl_post).returns(successful_create_subscription_response, successful_update_subscription_response)
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?
    assert response = @gateway.update(response.authorization, @credit_card, @subscription_options)
    assert response.success?
    assert response.test?
  end

  def test_successful_credit_card_unstore_request
    @gateway.stubs(:ssl_post).returns(successful_create_subscription_response, successful_delete_subscription_response)
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?
    assert response = @gateway.unstore(response.authorization, order_id: generate_unique_id)
    assert response.success?
    assert response.test?
  end

  def test_successful_credit_card_retrieve_request
    @gateway.stubs(:ssl_post).returns(successful_create_subscription_response, successful_retrieve_subscription_response)
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?
    assert response = @gateway.retrieve(response.authorization, order_id: generate_unique_id)
    assert response.success?
    assert response.test?
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Y', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end

  def test_successful_refund_request
    @gateway.stubs(:ssl_post).returns(successful_capture_response, successful_refund_response)
    assert_success(response = @gateway.purchase(@amount, @credit_card, @options))

    assert_success(@gateway.refund(@amount, response.authorization))
  end

  def test_successful_refund_with_elo_request
    @gateway.stubs(:ssl_post).returns(successful_capture_response, successful_refund_response)
    assert_success(response = @gateway.purchase(@amount, @elo_credit_card, @options))

    assert_success(@gateway.refund(@amount, response.authorization))
  end

  def test_successful_credit_to_card_request
    @gateway.stubs(:ssl_post).returns(successful_card_credit_response)

    assert_success(@gateway.credit(@amount, @credit_card, @options))
  end

  def test_authorization_under_review_request
    @gateway.stubs(:ssl_post).returns(authorization_review_response)

    assert_failure(response = @gateway.authorize(@amount, @credit_card, @options))
    assert response.fraud_review?
    assert_equal(response.authorization, "#{@options[:order_id]};#{response.params['requestID']};#{response.params['requestToken']};authorize;100;USD;")
  end

  def test_successful_credit_to_subscription_request
    @gateway.stubs(:ssl_post).returns(successful_create_subscription_response, successful_subscription_credit_response)

    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?
    assert_success(@gateway.credit(@amount, response.authorization, @options))
  end

  def test_credit_includes_merchant_descriptor
    stub_comms do
      @gateway.credit(@amount, @credit_card, merchant_descriptor: 'Spreedly')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<merchantDescriptor>Spreedly<\/merchantDescriptor>/, data)
    end.respond_with(successful_card_credit_response)
  end

  def test_credit_includes_issuer_additional_data
    stub_comms do
      @gateway.credit(@amount, @credit_card, issuer_additional_data: @issuer_additional_data)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<issuer>\s+<additionalData>#{@issuer_additional_data}<\/additionalData>\s+<\/issuer>/m, data)
    end.respond_with(successful_card_credit_response)
  end

  def test_credit_includes_mdd_fields
    stub_comms do
      @gateway.credit(@amount, @credit_card, mdd_field_2: 'CustomValue2', mdd_field_3: 'CustomValue3')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<mddField id=\"2\">CustomValue2</m, data)
    end.respond_with(successful_card_credit_response)
  end

  def test_successful_void_purchase_request
    purchase = '1000;1842651133440156177166;AP4JY+Or4xRonEAOERAyMzQzOTEzMEM0MFZaNUZCBgDH3fgJ8AEGAMfd+AnwAwzRpAAA7RT/;purchase;100;USD;'

    stub_comms do
      @gateway.void(purchase, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<voidService run=\"true\"), data)
    end.respond_with(successful_void_response)
  end

  def test_successful_void_capture_request
    capture = '1000;1842651133440156177166;AP4JY+Or4xRonEAOERAyMzQzOTEzMEM0MFZaNUZCBgDH3fgJ8AEGAMfd+AnwAwzRpAAA7RT/;capture;100;USD;'

    stub_comms do
      @gateway.void(capture, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<voidService run=\"true\"), data)
    end.respond_with(successful_void_response)
  end

  def test_successful_void_authorization_request
    authorization = '1000;1842651133440156177166;AP4JY+Or4xRonEAOERAyMzQzOTEzMEM0MFZaNUZCBgDH3fgJ8AEGAMfd+AnwAwzRpAAA7RT/;authorize;100;USD;'

    stub_comms do
      @gateway.void(authorization, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r(<ccAuthReversalService run=\"true\"), data)
    end.respond_with(successful_auth_reversal_response)
  end

  def test_successful_void_with_issuer_additional_data
    authorization = '1000;1842651133440156177166;AP4JY+Or4xRonEAOERAyMzQzOTEzMEM0MFZaNUZCBgDH3fgJ8AEGAMfd+AnwAwzRpAAA7RT/;authorize;100;USD;'

    stub_comms do
      @gateway.void(authorization, issuer_additional_data: @issuer_additional_data)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<issuer>\s+<additionalData>#{@issuer_additional_data}<\/additionalData>\s+<\/issuer>/m, data)
    end.respond_with(successful_void_response)
  end

  def test_void_includes_mdd_fields
    authorization = '1000;1842651133440156177166;AP4JY+Or4xRonEAOERAyMzQzOTEzMEM0MFZaNUZCBgDH3fgJ8AEGAMfd+AnwAwzRpAAA7RT/;authorize;100;USD;'

    stub_comms do
      @gateway.void(authorization, mdd_field_2: 'CustomValue2', mdd_field_3: 'CustomValue3')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<mddField id=\"2\">CustomValue2</m, data)
    end.respond_with(successful_void_response)
  end

  def test_successful_void_authorization_with_elo_request
    @gateway.stubs(:ssl_post).returns(successful_authorization_response, successful_void_response)
    assert response = @gateway.authorize(@amount, @elo_credit_card, @options)
    assert response.success?
    assert response.test?
    assert response_void = @gateway.void(response.authorization, @options)
    assert response_void.success?
  end

  def test_validate_pinless_debit_card_request
    @gateway.stubs(:ssl_post).returns(successful_validate_pinless_debit_card)
    assert response = @gateway.validate_pinless_debit_card(@credit_card, @options)
    assert response.success?
    assert_success(@gateway.void(response.authorization, @options))
  end

  def test_validate_add_subscription_amount
    stub_comms do
      @gateway.store(@credit_card, @subscription_options)
    end.check_request do |_endpoint, data, _headers|
      assert_match %r(<amount>1.00<\/amount>), data
    end.respond_with(successful_update_subscription_response)
  end

  def test_successful_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorization_response)
    assert_success response
  end

  def test_successful_verify_with_elo
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@elo_credit_card, @options)
    end.respond_with(successful_authorization_response)
    assert_success response
  end

  def test_unsuccessful_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(unsuccessful_authorization_response)
    assert_failure response
    assert_equal 'Invalid account number', response.message
  end

  def test_successful_auth_with_network_tokenization_for_visa
    credit_card = network_tokenization_credit_card('4111111111111111',
      brand: 'visa',
      transaction_id: '123',
      eci: '05',
      payment_cryptogram: '111111111100cryptogram')

    response = stub_comms do
      @gateway.authorize(@amount, credit_card, @options)
    end.check_request do |_endpoint, body, _headers|
      assert_xml_valid_to_xsd(body)
      assert_match %r'<ccAuthService run=\"true\">\n  <cavv>111111111100cryptogram</cavv>\n  <commerceIndicator>vbv</commerceIndicator>\n  <xid>111111111100cryptogram</xid>\n</ccAuthService>\n<paymentNetworkToken>\n  <transactionType>1</transactionType>\n</paymentNetworkToken>', body
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_network_tokenization_for_visa
    credit_card = network_tokenization_credit_card('4111111111111111',
      brand: 'visa',
      transaction_id: '123',
      eci: '05',
      payment_cryptogram: '111111111100cryptogram')

    response = stub_comms do
      @gateway.purchase(@amount, credit_card, @options)
    end.check_request do |_endpoint, body, _headers|
      assert_xml_valid_to_xsd(body)
      assert_match %r'<ccAuthService run="true">.+?<ccCaptureService run="true">'m, body
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_auth_with_network_tokenization_for_mastercard
    @gateway.expects(:ssl_post).with do |_host, request_body|
      assert_xml_valid_to_xsd(request_body)
      assert_match %r'<ucaf>\n  <authenticationData>111111111100cryptogram</authenticationData>\n  <collectionIndicator>2</collectionIndicator>\n</ucaf>\n<ccAuthService run=\"true\">\n  <commerceIndicator>spa</commerceIndicator>\n</ccAuthService>\n<paymentNetworkToken>\n  <transactionType>1</transactionType>\n</paymentNetworkToken>', request_body
      true
    end.returns(successful_purchase_response)

    credit_card = network_tokenization_credit_card('5555555555554444',
      brand: 'master',
      transaction_id: '123',
      eci: '05',
      payment_cryptogram: '111111111100cryptogram')

    assert response = @gateway.authorize(@amount, credit_card, @options)
    assert_success response
  end

  def test_successful_auth_with_network_tokenization_for_amex
    @gateway.expects(:ssl_post).with do |_host, request_body|
      assert_xml_valid_to_xsd(request_body)
      assert_match %r'<ccAuthService run=\"true\">\n  <cavv>MTExMTExMTExMTAwY3J5cHRvZ3I=\n</cavv>\n  <commerceIndicator>aesk</commerceIndicator>\n  <xid>YW0=\n</xid>\n</ccAuthService>\n<paymentNetworkToken>\n  <transactionType>1</transactionType>\n</paymentNetworkToken>', request_body
      true
    end.returns(successful_purchase_response)

    credit_card = network_tokenization_credit_card('378282246310005',
      brand: 'american_express',
      transaction_id: '123',
      eci: '05',
      payment_cryptogram: Base64.encode64('111111111100cryptogram'))

    assert response = @gateway.authorize(@amount, credit_card, @options)
    assert_success response
  end

  def test_cof_first
    @options[:stored_credential] = {
      initiator: 'cardholder',
      reason_type: '',
      initial_transaction: true,
      network_transaction_id: ''
    }
    @options[:commerce_indicator] = 'internet'
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/\<subsequentAuthFirst\>true/, data)
      assert_not_match(/\<subsequentAuthStoredCredential\>true/, data)
      assert_not_match(/\<subsequentAuth\>/, data)
      assert_not_match(/\<subsequentAuthTransactionID\>/, data)
      assert_match(/\<commerceIndicator\>internet/, data)
    end.respond_with(successful_authorization_response)
    assert response.success?
  end

  def test_cof_cit_auth
    @options[:stored_credential] = {
      initiator: 'cardholder',
      reason_type: 'unscheduled',
      initial_transaction: false,
      network_transaction_id: ''
    }
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_not_match(/\<subsequentAuthFirst\>/, data)
      assert_match(/\<subsequentAuthStoredCredential\>/, data)
      assert_not_match(/\<subsequentAuth\>/, data)
      assert_not_match(/\<subsequentAuthTransactionID\>/, data)
    end.respond_with(successful_authorization_response)
    assert response.success?
  end

  def test_cof_unscheduled_mit_auth
    @options[:stored_credential] = {
      initiator: 'merchant',
      reason_type: 'unscheduled',
      initial_transaction: false,
      network_transaction_id: '016150703802094'
    }
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_not_match(/\<subsequentAuthFirst\>/, data)
      assert_match(/\<subsequentAuthStoredCredential\>true/, data)
      assert_match(/\<subsequentAuth\>true/, data)
      assert_match(/\<subsequentAuthTransactionID\>016150703802094/, data)
    end.respond_with(successful_authorization_response)
    assert response.success?
  end

  def test_cof_installment_mit_auth
    @options[:stored_credential] = {
      initiator: 'merchant',
      reason_type: 'installment',
      initial_transaction: false,
      network_transaction_id: '016150703802094'
    }
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_not_match(/\<subsequentAuthFirst\>/, data)
      assert_not_match(/\<subsequentAuthStoredCredential\>/, data)
      assert_match(/\<subsequentAuth\>true/, data)
      assert_match(/\<subsequentAuthTransactionID\>016150703802094/, data)
      assert_match(/\<commerceIndicator\>install/, data)
    end.respond_with(successful_authorization_response)
    assert response.success?
  end

  def test_cof_recurring_mit_auth
    @options[:stored_credential] = {
      initiator: 'merchant',
      reason_type: 'recurring',
      initial_transaction: false,
      network_transaction_id: '016150703802094'
    }
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_not_match(/\<subsequentAuthFirst\>/, data)
      assert_not_match(/\<subsequentAuthStoredCredential\>/, data)
      assert_match(/\<subsequentAuth\>true/, data)
      assert_match(/\<subsequentAuthTransactionID\>016150703802094/, data)
      assert_match(/\<commerceIndicator\>recurring/, data)
    end.respond_with(successful_authorization_response)
    assert response.success?
  end

  def test_cof_recurring_mit_purchase
    @options[:stored_credential] = {
      initiator: 'merchant',
      reason_type: 'recurring',
      initial_transaction: false,
      network_transaction_id: '016150703802094'
    }
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_not_match(/\<subsequentAuthFirst\>/, data)
      assert_not_match(/\<subsequentAuthStoredCredential\>/, data)
      assert_match(/\<subsequentAuth\>true/, data)
      assert_match(/\<subsequentAuthTransactionID\>016150703802094/, data)
      assert_match(/\<commerceIndicator\>recurring/, data)
    end.respond_with(successful_purchase_response)
    assert response.success?
  end

  def test_cof_first_with_overrides
    @options[:stored_credential] = {
      initiator: 'cardholder',
      reason_type: '',
      initial_transaction: true,
      network_transaction_id: ''
    }
    @options[:stored_credential_overrides] = {
      subsequent_auth: 'true',
      subsequent_auth_first: 'false',
      subsequent_auth_stored_credential: 'true',
      subsequent_auth_transaction_id: '54321'
    }
    @options[:commerce_indicator] = 'internet'
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/\<subsequentAuthFirst\>false/, data)
      assert_match(/\<subsequentAuthStoredCredential\>true/, data)
      assert_match(/\<subsequentAuth\>true/, data)
      assert_match(/\<subsequentAuthTransactionID\>54321/, data)
      assert_match(/\<commerceIndicator\>internet/, data)
    end.respond_with(successful_authorization_response)
    assert response.success?
  end

  def test_nonfractional_currency_handling
    @gateway.expects(:ssl_post).with do |_host, request_body|
      assert_match %r(<grandTotalAmount>1</grandTotalAmount>), request_body
      assert_match %r(<currency>JPY</currency>), request_body
      true
    end.returns(successful_nonfractional_authorization_response)

    assert response = @gateway.authorize(100, @credit_card, @options.merge(currency: 'JPY'))
    assert_success response
  end

  def test_malformed_xml_handling
    @gateway.expects(:ssl_post).returns(malformed_xml_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r(Missing end tag for), response.message
    assert response.test?
  end

  def test_3ds_enroll_response
    purchase = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(payer_auth_enroll_service: true))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/\<payerAuthEnrollService run=\"true\"\/\>/, data)
    end.respond_with(threedeesecure_purchase_response)

    assert_failure purchase
    assert_equal 'YTJycDdLR3RIVnpmMXNFejJyazA=', purchase.params['xid']
    assert_equal 'eNpVUe9PwjAQ/d6/ghA/r2tBYMvRBEUFFEKQEP1Yu1Om7gfdJoy/3nZsgk2a3Lveu757B+utRhw/oyo0CphjlskPbIXBsC25TvuPD/lkc3xn2d2R6y+3LWA5WuFOwA/qLExiwRzX4UAbSEwLrbYyzgVItbuZLkS353HWA1pDAhHq6Vgw3ule9/pAT5BALCMUqnwznZJCKwRaZQiopIhzXYpB1wXaAAKF/hbbPE8zn9L9fu9cUB2VREBtAQF6FrQsbJSZOQ9hIF7Xs1KNg6dVZzXdxGk0f1nc4+eslMfREKitIBDIHAV3WZ+Z2+Ku3/F8bjRXeQIysmrEFeOOa0yoIYHUfjQ6Icbt02XGTFRojbFqRmoQATykSYymxlD+YjPDWfntxBqrcusg8wbmWGcrXNFD4w3z2IkfVkZRy6H13mi9YhP9W/0vhyyqPw==', purchase.params['paReq']
    assert_equal 'https://0eafstag.cardinalcommerce.com/EAFService/jsp/v1/redirect', purchase.params['acsURL']
  end

  def test_3ds_validate_response
    validation = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(payer_auth_validate_service: true, pares: 'ABC123'))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/\<payerAuthValidateService run=\"true\"\>/, data)
      assert_match(/\<signedPARes\>ABC123\<\/signedPARes\>/, data)
    end.respond_with(successful_threedeesecure_validate_response)

    assert_success validation
  end

  def test_adds_3ds_brand_based_commerce_indicator
    %w(visa maestro master american_express jcb discover diners_club).each do |brand|
      @credit_card.brand = brand

      stub_comms do
        @gateway.purchase(@amount, @credit_card, @options.merge(three_d_secure: { cavv: 'anything but empty' }))
      end.check_request do |_endpoint, data, _headers|
        assert_match(/commerceIndicator\>#{CyberSourceGateway::ECI_BRAND_MAPPING[brand.to_sym]}</, data)
      end.respond_with(successful_purchase_response)
    end
  end

  def test_adds_3ds2_fields_via_normalized_hash
    version = '2.0'
    eci = '05'
    cavv = '637574652070757070792026206b697474656e73'
    cavv_algorithm = 2
    ds_transaction_id = '97267598-FAE6-48F2-8083-C23433990FBC'
    commerce_indicator = 'commerce_indicator'
    authentication_response_status = 'Y'
    enrolled = 'Y'
    options_with_normalized_3ds = @options.merge(
      three_d_secure: {
        version: version,
        eci: eci,
        cavv: cavv,
        ds_transaction_id: ds_transaction_id,
        cavv_algorithm: cavv_algorithm,
        enrolled: enrolled,
        authentication_response_status: authentication_response_status
      },
      commerce_indicator: commerce_indicator
    )

    stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_normalized_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<eciRaw\>#{eci}/, data)
      assert_match(/<cavv\>#{cavv}/, data)
      assert_match(/<paSpecificationVersion\>#{version}/, data)
      assert_match(/<directoryServerTransactionID\>#{ds_transaction_id}/, data)
      assert_match(/<paresStatus\>#{authentication_response_status}/, data)
      assert_match(/<cavvAlgorithm\>#{cavv_algorithm}/, data)
      assert_match(/<commerceIndicator\>#{commerce_indicator}/, data)
      assert_match(/<veresEnrolled\>#{enrolled}/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_does_not_add_3ds2_fields_via_normalized_hash_when_cavv_and_commerce_indicator_absent
    options = options_with_normalized_3ds(cavv: nil, commerce_indicator: nil)
    stub_comms do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_, data, _|
      assert_not_match(/<eciRaw\>#{options[:three_d_secure][:eci]}</, data)
      assert_not_match(/<cavv\>#{options[:three_d_secure][:cavv]}</, data)
      assert_not_match(/<paSpecificationVersion\>#{options[:three_d_secure][:version]}</, data)
      assert_not_match(/<directoryServerTransactionID\>#{options[:three_d_secure][:ds_transaction_id]}</, data)
      assert_not_match(/<paresStatus\>#{options[:three_d_secure][:authentication_response_status]}</, data)
      assert_not_match(/<cavvAlgorithm\>#{options[:three_d_secure][:cavv_algorithm]}</, data)
      assert_not_match(/<veresEnrolled\>#{options[:three_d_secure][:enrolled]}</, data)
      assert_not_match(/<commerceIndicator\>#{options[:commerce_indicator]}</, data)
    end.respond_with(successful_purchase_response)
  end

  def test_adds_3ds2_fields_via_normalized_hash_when_cavv_and_commerce_indicator_absent_and_commerce_indicator_not_inferred
    @credit_card.brand = supported_cc_brand_without_inferred_commerce_indicator
    assert_not_nil @credit_card.brand

    options = options_with_normalized_3ds(cavv: nil, commerce_indicator: nil)
    stub_comms do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_, data, _|
      assert_match(/<eciRaw\>#{options[:three_d_secure][:eci]}</, data)
      assert_match(/<paSpecificationVersion\>#{options[:three_d_secure][:version]}</, data)
      assert_match(/<directoryServerTransactionID\>#{options[:three_d_secure][:ds_transaction_id]}</, data)
      assert_match(/<paresStatus\>#{options[:three_d_secure][:authentication_response_status]}</, data)
      assert_match(/<cavvAlgorithm\>#{options[:three_d_secure][:cavv_algorithm]}</, data)
      assert_match(/<veresEnrolled\>#{options[:three_d_secure][:enrolled]}</, data)
    end.respond_with(successful_purchase_response)
  end

  def test_adds_3ds2_fields_via_normalized_hash_when_cavv_absent_and_commerce_indicator_present
    options = options_with_normalized_3ds(cavv: nil)
    stub_comms do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_, data, _|
      assert_match(/<eciRaw\>#{options[:three_d_secure][:eci]}</, data)
      assert_match(/<paSpecificationVersion\>#{options[:three_d_secure][:version]}</, data)
      assert_match(/<directoryServerTransactionID\>#{options[:three_d_secure][:ds_transaction_id]}</, data)
      assert_match(/<paresStatus\>#{options[:three_d_secure][:authentication_response_status]}</, data)
      assert_match(/<cavvAlgorithm\>#{options[:three_d_secure][:cavv_algorithm]}</, data)
      assert_match(/<veresEnrolled\>#{options[:three_d_secure][:enrolled]}</, data)
      assert_match(/<commerceIndicator\>#{options[:commerce_indicator]}</, data)
    end.respond_with(successful_purchase_response)
  end

  def test_adds_3ds2_fields_via_normalized_hash_when_cavv_present_and_commerce_indicator_absent
    options = options_with_normalized_3ds(commerce_indicator: nil)
    stub_comms do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_, data, _|
      assert_match(/<eciRaw\>#{options[:three_d_secure][:eci]}</, data)
      assert_match(/<cavv\>#{options[:three_d_secure][:cavv]}</, data)
      assert_match(/<paSpecificationVersion\>#{options[:three_d_secure][:version]}</, data)
      assert_match(/<directoryServerTransactionID\>#{options[:three_d_secure][:ds_transaction_id]}</, data)
      assert_match(/<paresStatus\>#{options[:three_d_secure][:authentication_response_status]}</, data)
      assert_match(/<cavvAlgorithm\>#{options[:three_d_secure][:cavv_algorithm]}</, data)
      assert_match(/<veresEnrolled\>#{options[:three_d_secure][:enrolled]}</, data)
    end.respond_with(successful_purchase_response)
  end

  def test_adds_mastercard_3ds2_fields_via_normalized_hash
    version = '2.0'
    eci = '05'
    cavv = '637574652070757070792026206b697474656e73'
    cavv_algorithm = 1
    ds_transaction_id = '97267598-FAE6-48F2-8083-C23433990FBC'
    commerce_indicator = 'commerce_indicator'
    collection_indicator = 2
    options_with_normalized_3ds = @options.merge(
      three_d_secure: {
        version: version,
        eci: eci,
        cavv: cavv,
        ds_transaction_id: ds_transaction_id,
        cavv_algorithm: cavv_algorithm
      },
      commerce_indicator: commerce_indicator,
      collection_indicator: collection_indicator
    )

    stub_comms do
      @gateway.purchase(@amount, @master_credit_card, options_with_normalized_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<eciRaw\>#{eci}/, data)
      assert_match(/<authenticationData\>#{cavv}/, data)
      assert_match(/<paSpecificationVersion\>#{version}/, data)
      assert_match(/<directoryServerTransactionID\>#{ds_transaction_id}/, data)
      assert_match(/<cavvAlgorithm\>#{cavv_algorithm}/, data)
      assert_match(/<commerceIndicator\>#{commerce_indicator}/, data)
      assert_match(/<collectionIndicator\>#{collection_indicator}/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_adds_mastercard_3ds2_default_collection_indicator
    options_with_normalized_3ds = @options.merge(
      three_d_secure: {
        version: '2.0',
        eci: '05',
        cavv: '637574652070757070792026206b697474656e73',
        ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC',
        cavv_algorithm: 'vbv'
      }
    )

    stub_comms do
      @gateway.purchase(@amount, @master_credit_card, options_with_normalized_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<collectionIndicator\>2/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_send_xid_for_3ds_1_regardless_of_cc_brand
    options_with_normalized_3ds = @options.merge(
      three_d_secure: {
        eci: '05',
        cavv: '637574652070757070792026206b697474656e73',
        xid: 'this-is-an-xid',
        ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC',
        cavv_algorithm: 'vbv'
      }
    )

    stub_comms do
      @gateway.purchase(@amount, @elo_credit_card, options_with_normalized_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<xid\>this-is-an-xid/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_dont_send_cavv_as_xid_in_3ds2_for_mastercard
    options_with_normalized_3ds = @options.merge(
      three_d_secure: {
        version: '2.0',
        eci: '05',
        cavv: '637574652070757070792026206b697474656e73',
        xid: 'this-is-an-xid',
        ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC',
        cavv_algorithm: 'vbv'
      }
    )

    stub_comms do
      @gateway.purchase(@amount, @master_credit_card, options_with_normalized_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<xid\>this-is-an-xid/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_adds_cavv_as_xid_for_3ds2
    cavv = '637574652070757070792026206b697474656e73'

    options_with_normalized_3ds = @options.merge(
      three_d_secure: {
        version: '2.0',
        eci: '05',
        cavv: cavv,
        ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC',
        cavv_algorithm: 'vbv'
      }
    )

    stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_normalized_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<xid\>#{cavv}/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_does_not_add_cavv_as_xid_if_xid_is_present
    options_with_normalized_3ds = @options.merge(
      three_d_secure: {
        version: '2.0',
        eci: '05',
        cavv: '637574652070757070792026206b697474656e73',
        xid: 'this-is-an-xid',
        ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC',
        cavv_algorithm: 'vbv'
      }
    )

    stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_normalized_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<xid\>this-is-an-xid/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_scrub
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_supports_scrubbing?
    assert @gateway.supports_scrubbing?
  end

  def test_supports_network_tokenization
    assert_instance_of TrueClass, @gateway.supports_network_tokenization?
  end

  def test_does_not_throw_on_invalid_xml
    raw_response = mock
    raw_response.expects(:body).returns(invalid_xml_response)
    exception = ActiveMerchant::ResponseError.new(raw_response)
    @gateway.expects(:ssl_post).raises(exception)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_address_email_has_a_default_when_email_option_is_empty
    stub_comms do
      @gateway.authorize(100, @credit_card, email: '')
    end.check_request do |_endpoint, data, _headers|
      assert_match('<email>null@cybersource.com</email>', data)
    end.respond_with(successful_capture_response)
  end

  def test_country_code_sent_as_default_when_submitted_as_empty_string
    stub_comms do
      @gateway.authorize(100, @credit_card, billing_address: { country: '' })
    end.check_request do |_endpoint, data, _headers|
      assert_match('<country>US</country>', data)
    end.respond_with(successful_capture_response)
  end

  def test_default_address_does_not_override_when_hash_keys_are_strings
    stub_comms do
      @gateway.authorize(100, @credit_card, billing_address: {
        'address1' => '221B Baker Street',
        'city' => 'London',
        'zip' => 'NW16XE',
        'country' => 'GB'
      })
    end.check_request do |_endpoint, data, _headers|
      assert_match('<street1>221B Baker Street</street1>', data)
      assert_match('<city>London</city>', data)
      assert_match('<postalCode>NW16XE</postalCode>', data)
      assert_match('<country>GB</country>', data)
    end.respond_with(successful_capture_response)
  end

  def test_adds_application_id_as_partner_solution_id
    partner_id = 'partner_id'
    CyberSourceGateway.application_id = partner_id

    stub_comms do
      @gateway.authorize(100, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match("<partnerSolutionID>#{partner_id}</partnerSolutionID>", data)
    end.respond_with(successful_capture_response)
  ensure
    CyberSourceGateway.application_id = nil
  end

  def test_partner_solution_id_position_follows_schema
    partner_id = 'partner_id'
    CyberSourceGateway.application_id = partner_id

    @options[:stored_credential] = {
      initiator: 'cardholder',
      reason_type: '',
      initial_transaction: true,
      network_transaction_id: ''
    }
    @options[:commerce_indicator] = 'internet'

    stub_comms do
      @gateway.authorize(100, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match("<subsequentAuth/>\n<partnerSolutionID>#{partner_id}</partnerSolutionID>\n<subsequentAuthFirst>true</subsequentAuthFirst>\n<subsequentAuthTransactionID/>\n<subsequentAuthStoredCredential/>", data)
    end.respond_with(successful_capture_response)
  ensure
    CyberSourceGateway.application_id = nil
  end

  def test_missing_field
    @gateway.expects(:ssl_post).returns(missing_field_response)

    response = @gateway.purchase(@amount, credit_card, @options)

    assert_failure response
    assert_equal 'c:billTo/c:country', response.params['missingField']
  end

  def test_invalid_field
    @gateway.expects(:ssl_post).returns(invalid_field_response)

    response = @gateway.purchase(@amount, credit_card, @options)

    assert_failure response
    assert_equal 'c:billTo/c:postalCode', response.params['invalidField']
  end

  private

  def options_with_normalized_3ds(
    cavv: '637574652070757070792026206b697474656e73',
    commerce_indicator: 'commerce_indicator'
  )
    xid = 'Y2FyZGluYWxjb21tZXJjZWF1dGg='
    authentication_response_status = 'Y'
    cavv_algorithm = 2
    collection_indicator = 2
    ds_transaction_id = '97267598-FAE6-48F2-8083-C23433990FBC'
    eci = '05'
    enrolled = 'Y'
    version = '2.0'
    @options.merge(
      three_d_secure: {
        version: version,
        eci: eci,
        xid: xid,
        cavv: cavv,
        ds_transaction_id: ds_transaction_id,
        cavv_algorithm: cavv_algorithm,
        enrolled: enrolled,
        authentication_response_status: authentication_response_status
      },
      commerce_indicator: commerce_indicator,
      collection_indicator: collection_indicator
    ).compact
  end

  def supported_cc_brand_without_inferred_commerce_indicator
    (ActiveMerchant::Billing::CyberSourceGateway.supported_cardtypes -
      ActiveMerchant::Billing::CyberSourceGateway::ECI_BRAND_MAPPING.keys).first
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
    opening connection to ics2wstest.ic3.com:443...
    opened
    starting SSL for ics2wstest.ic3.com:443...
    SSL established
    <- "POST /commerce/1.x/transactionProcessor HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: ics2wstest.ic3.com\r\nContent-Length: 2459\r\n\r\n"
    <- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">\n  <s:Header>\n    <wsse:Security s:mustUnderstand=\"1\" xmlns:wsse=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd\">\n      <wsse:UsernameToken>\n        <wsse:Username>test</wsse:Username>\n        <wsse:Password Type=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText\">DT3MZm8t8BsDZC9ZoKl592lvlRbQCcEXmEcYlh3gZObo6zTLQdf2m5klbqXlTq31iTJ5/Ctl/Z5LFE60GFnWGR8Cn5GeXuToZNbMHAvZKZ3sw9tC3Hf4U3Dj8XS2EI4OBvA1jcw38hd3VEm0ZZCAQEDZCC+AnM2ya9417zqynYjwgSyPOfh6CfMlSJKTgxQJLot7jFxYNvM/s9yBZoh37wJZUXdZ9Bf/CH6O3tKzafbyfn5rK25+GeYN9koih4O8c+PLQepzj5miiR7bikFzgEnsVs6LaZdLM8Sx/XVXk+60h02lg/a6KdS3kmUvnTGOihg5JUnl2JucBpH/P4aQYZ==</wsse:Password>\n      </wsse:UsernameToken>\n    </wsse:Security>\n  </s:Header>\n  <s:Body xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">\n    <requestMessage xmlns=\"urn:schemas-cybersource-com:transaction-data-1.109\">\n      <merchantID>test</merchantID>\n      <merchantReferenceCode>734dda9bb6446f2f2638ab7faf34682f</merchantReferenceCode>\n      <clientLibrary>Ruby Active Merchant</clientLibrary>\n      <clientLibraryVersion>1.50.0</clientLibraryVersion>\n      <clientEnvironment>x86_64-darwin14.0</clientEnvironment>\n<billTo>\n  <firstName>Longbob</firstName>\n  <lastName>Longsen</lastName>\n  <street1>456 My Street</street1>\n  <street2>Apt 1</street2>\n  <city>Ottawa</city>\n  <state>NC</state>\n  <postalCode>K1C2N6</postalCode>\n  <country>US</country>\n  <company>Widgets Inc</company>\n  <phoneNumber>(555)555-5555</phoneNumber>\n  <email>someguy1232@fakeemail.net</email>\n</billTo>\n<shipTo>\n  <firstName>Longbob</firstName>\n  <lastName>Longsen</lastName>\n  <street1/>\n  <city/>\n  <state/>\n  <postalCode/>\n  <country/>\n  <email>someguy1232@fakeemail.net</email>\n</shipTo>\n<purchaseTotals>\n  <currency>USD</currency>\n  <grandTotalAmount>1.00</grandTotalAmount>\n</purchaseTotals>\n<card>\n  <accountNumber>4111111111111111</accountNumber>\n  <expirationMonth>09</expirationMonth>\n  <expirationYear>2016</expirationYear>\n  <cvNumber>123</cvNumber>\n  <cardType>001</cardType>\n</card>\n<ccAuthService run=\"true\"/>\n<ccCaptureService run=\"true\"/>\n<businessRules>\n  <ignoreAVSResult>true</ignoreAVSResult>\n  <ignoreCVResult>true</ignoreCVResult>\n</businessRules>\n    </requestMessage>\n  </s:Body>\n</s:Envelope>\n"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Server: Apache-Coyote/1.1\r\n"
    -> "X-OPNET-Transaction-Trace: pid=18901,requestid=08985faa-d84a-4200-af8a-1d0a4d50f391\r\n"
    -> "Set-Cookie: _op_aixPageId=a_233cede6-657e-481e-977d-a4a886dafd37; Path=/\r\n"
    -> "Content-Type: text/xml\r\n"
    -> "Content-Length: 1572\r\n"
    -> "Date: Fri, 05 Jun 2015 13:01:57 GMT\r\n"
    -> "Connection: close\r\n"
    -> "\r\n"
    reading 1572 bytes...
    -> "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">\n<soap:Header>\n<wsse:Security xmlns:wsse=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd\"><wsu:Timestamp xmlns:wsu=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd\" wsu:Id=\"Timestamp-513448318\"><wsu:Created>2015-06-05T13:01:57.974Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c=\"urn:schemas-cybersource-com:transaction-data-1.109\"><c:merchantReferenceCode>734dda9bb6446f2f2638ab7faf34682f</c:merchantReferenceCode><c:requestID>4335093172165000001515</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>Ahj//wSR1gMBn41YRu/WIkGLlo3asGzCbBky4VOjHT9/xXHSYBT9/xXHSbSA+RQkhk0ky3SA3+mwMCcjrAYDPxqwjd+sKWXL</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccAuthReply><c:reasonCode>100</c:reasonCode><c:amount>1.00</c:amount><c:authorizationCode>888888</c:authorizationCode><c:avsCode>X</c:avsCode><c:avsCodeRaw>I1</c:avsCodeRaw><c:cvCode/><c:authorizedDateTime>2015-06-05T13:01:57Z</c:authorizedDateTime><c:processorResponse>100</c:processorResponse><c:reconciliationID>19475060MAIKBSQG</c:reconciliationID></c:ccAuthReply><c:ccCaptureReply><c:reasonCode>100</c:reasonCode><c:requestDateTime>2015-06-05T13:01:57Z</c:requestDateTime><c:amount>1.00</c:amount><c:reconciliationID>19475060MAIKBSQG</c:reconciliationID></c:ccCaptureReply></c:replyMessage></soap:Body></soap:Envelope>"
    read 1572 bytes
    Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
    opening connection to ics2wstest.ic3.com:443...
    opened
    starting SSL for ics2wstest.ic3.com:443...
    SSL established
    <- "POST /commerce/1.x/transactionProcessor HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: ics2wstest.ic3.com\r\nContent-Length: 2459\r\n\r\n"
    <- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">\n  <s:Header>\n    <wsse:Security s:mustUnderstand=\"1\" xmlns:wsse=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd\">\n      <wsse:UsernameToken>\n        <wsse:Username>test</wsse:Username>\n        <wsse:Password Type=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText\">[FILTERED]</wsse:Password>\n      </wsse:UsernameToken>\n    </wsse:Security>\n  </s:Header>\n  <s:Body xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">\n    <requestMessage xmlns=\"urn:schemas-cybersource-com:transaction-data-1.109\">\n      <merchantID>test</merchantID>\n      <merchantReferenceCode>734dda9bb6446f2f2638ab7faf34682f</merchantReferenceCode>\n      <clientLibrary>Ruby Active Merchant</clientLibrary>\n      <clientLibraryVersion>1.50.0</clientLibraryVersion>\n      <clientEnvironment>x86_64-darwin14.0</clientEnvironment>\n<billTo>\n  <firstName>Longbob</firstName>\n  <lastName>Longsen</lastName>\n  <street1>456 My Street</street1>\n  <street2>Apt 1</street2>\n  <city>Ottawa</city>\n  <state>NC</state>\n  <postalCode>K1C2N6</postalCode>\n  <country>US</country>\n  <company>Widgets Inc</company>\n  <phoneNumber>(555)555-5555</phoneNumber>\n  <email>someguy1232@fakeemail.net</email>\n</billTo>\n<shipTo>\n  <firstName>Longbob</firstName>\n  <lastName>Longsen</lastName>\n  <street1/>\n  <city/>\n  <state/>\n  <postalCode/>\n  <country/>\n  <email>someguy1232@fakeemail.net</email>\n</shipTo>\n<purchaseTotals>\n  <currency>USD</currency>\n  <grandTotalAmount>1.00</grandTotalAmount>\n</purchaseTotals>\n<card>\n  <accountNumber>[FILTERED]</accountNumber>\n  <expirationMonth>09</expirationMonth>\n  <expirationYear>2016</expirationYear>\n  <cvNumber>[FILTERED]</cvNumber>\n  <cardType>001</cardType>\n</card>\n<ccAuthService run=\"true\"/>\n<ccCaptureService run=\"true\"/>\n<businessRules>\n  <ignoreAVSResult>true</ignoreAVSResult>\n  <ignoreCVResult>true</ignoreCVResult>\n</businessRules>\n    </requestMessage>\n  </s:Body>\n</s:Envelope>\n"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Server: Apache-Coyote/1.1\r\n"
    -> "X-OPNET-Transaction-Trace: pid=18901,requestid=08985faa-d84a-4200-af8a-1d0a4d50f391\r\n"
    -> "Set-Cookie: _op_aixPageId=a_233cede6-657e-481e-977d-a4a886dafd37; Path=/\r\n"
    -> "Content-Type: text/xml\r\n"
    -> "Content-Length: 1572\r\n"
    -> "Date: Fri, 05 Jun 2015 13:01:57 GMT\r\n"
    -> "Connection: close\r\n"
    -> "\r\n"
    reading 1572 bytes...
    -> "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">\n<soap:Header>\n<wsse:Security xmlns:wsse=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd\"><wsu:Timestamp xmlns:wsu=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd\" wsu:Id=\"Timestamp-513448318\"><wsu:Created>2015-06-05T13:01:57.974Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c=\"urn:schemas-cybersource-com:transaction-data-1.109\"><c:merchantReferenceCode>734dda9bb6446f2f2638ab7faf34682f</c:merchantReferenceCode><c:requestID>4335093172165000001515</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>Ahj//wSR1gMBn41YRu/WIkGLlo3asGzCbBky4VOjHT9/xXHSYBT9/xXHSbSA+RQkhk0ky3SA3+mwMCcjrAYDPxqwjd+sKWXL</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccAuthReply><c:reasonCode>100</c:reasonCode><c:amount>1.00</c:amount><c:authorizationCode>888888</c:authorizationCode><c:avsCode>X</c:avsCode><c:avsCodeRaw>I1</c:avsCodeRaw><c:cvCode/><c:authorizedDateTime>2015-06-05T13:01:57Z</c:authorizedDateTime><c:processorResponse>100</c:processorResponse><c:reconciliationID>19475060MAIKBSQG</c:reconciliationID></c:ccAuthReply><c:ccCaptureReply><c:reasonCode>100</c:reasonCode><c:requestDateTime>2015-06-05T13:01:57Z</c:requestDateTime><c:amount>1.00</c:amount><c:reconciliationID>19475060MAIKBSQG</c:reconciliationID></c:ccCaptureReply></c:replyMessage></soap:Body></soap:Envelope>"
    read 1572 bytes
    Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-2636690"><wsu:Created>2008-01-15T21:42:03.343Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.26"><c:merchantReferenceCode>b0a6cf9aa07f1a8495f89c364bbd6a9a</c:merchantReferenceCode><c:requestID>2004333231260008401927</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>Afvvj7Ke2Fmsbq0wHFE2sM6R4GAptYZ0jwPSA+R9PhkyhFTb0KRjoE4+ynthZrG6tMBwjAtT</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccAuthReply><c:reasonCode>100</c:reasonCode><c:amount>1.00</c:amount><c:authorizationCode>123456</c:authorizationCode><c:avsCode>Y</c:avsCode><c:avsCodeRaw>Y</c:avsCodeRaw><c:cvCode>M</c:cvCode><c:cvCodeRaw>M</c:cvCodeRaw><c:authorizedDateTime>2008-01-15T21:42:03Z</c:authorizedDateTime><c:processorResponse>00</c:processorResponse><c:authFactorCode>U</c:authFactorCode></c:ccAuthReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_authorization_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-32551101"><wsu:Created>2007-07-12T18:31:53.838Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.26"><c:merchantReferenceCode>TEST11111111111</c:merchantReferenceCode><c:requestID>1842651133440156177166</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>AP4JY+Or4xRonEAOERAyMzQzOTEzMEM0MFZaNUZCBgDH3fgJ8AEGAMfd+AnwAwzRpAAA7RT/</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccAuthReply><c:reasonCode>100</c:reasonCode><c:amount>1.00</c:amount><c:authorizationCode>004542</c:authorizationCode><c:avsCode>A</c:avsCode><c:avsCodeRaw>I7</c:avsCodeRaw><c:authorizedDateTime>2007-07-12T18:31:53Z</c:authorizedDateTime><c:processorResponse>100</c:processorResponse><c:reconciliationID>23439130C40VZ2FB</c:reconciliationID></c:ccAuthReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def unsuccessful_authorization_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-28121162"><wsu:Created>2008-01-15T21:50:41.580Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.26"><c:merchantReferenceCode>a1efca956703a2a5037178a8a28f7357</c:merchantReferenceCode><c:requestID>2004338415330008402434</c:requestID><c:decision>REJECT</c:decision><c:reasonCode>231</c:reasonCode><c:requestToken>Afvvj7KfIgU12gooCFE2/DanQIApt+G1OgTSA+R9PTnyhFTb0KRjgFY+ynyIFNdoKKAghwgx</c:requestToken><c:ccAuthReply><c:reasonCode>231</c:reasonCode></c:ccAuthReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def unsuccessful_authorization_response_with_reply
    <<-XML
      <?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Header>
        <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
          <wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-5307043">
            <wsu:Created>2017-05-10T01:15:14.835Z</wsu:Created>
          </wsu:Timestamp></wsse:Security>
        </soap:Header>
        <soap:Body>
          <c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.121">
            <c:merchantReferenceCode>TEST11111111111</c:merchantReferenceCode>
            <c:requestID>1841784762620176127166</c:requestID>
            <c:decision>REJECT</c:decision>
            <c:reasonCode>481</c:reasonCode>
            <c:requestToken>AMYJY9fl62i+vx2OEQYAx9zv/9UBZAAA5h5D</c:requestToken>
            <c:purchaseTotals>
              <c:currency>USD</c:currency>
            </c:purchaseTotals>
            <c:ccAuthReply>
              <c:reasonCode>100</c:reasonCode>
              <c:amount>1186.43</c:amount>
              <c:authorizationCode>123456</c:authorizationCode>
              <c:avsCode>N</c:avsCode>
              <c:avsCodeRaw>N</c:avsCodeRaw>
              <c:cvCode>M</c:cvCode>
              <c:cvCodeRaw>M</c:cvCodeRaw>
              <c:authorizedDateTime>2017-05-10T01:15:14Z</c:authorizedDateTime>
              <c:processorResponse>00</c:processorResponse>
              <c:reconciliationID>013445773WW7EWMB0RYI9</c:reconciliationID>
            </c:ccAuthReply>
            <c:afsReply>
              <c:reasonCode>100</c:reasonCode>
              <c:afsResult>96</c:afsResult>
              <c:hostSeverity>1</c:hostSeverity>
              <c:consumerLocalTime>20:15:14</c:consumerLocalTime>
              <c:afsFactorCode>C^H</c:afsFactorCode>
              <c:internetInfoCode>MM-IPBST</c:internetInfoCode>
              <c:suspiciousInfoCode>MUL-EM</c:suspiciousInfoCode>
              <c:velocityInfoCode>VEL-ADDR^VEL-CC^VEL-NAME</c:velocityInfoCode>
              <c:ipCountry>us</c:ipCountry>
              <c:ipState>nv</c:ipState><c:ipCity>las vegas</c:ipCity>
              <c:ipRoutingMethod>fixed</c:ipRoutingMethod>
              <c:scoreModelUsed>default</c:scoreModelUsed>
              <c:cardBin>540510</c:cardBin>
              <c:binCountry>US</c:binCountry>
              <c:cardAccountType>PURCHASING</c:cardAccountType>
              <c:cardScheme>MASTERCARD CREDIT</c:cardScheme>
              <c:cardIssuer>werewrewrew.</c:cardIssuer>
            </c:afsReply>
            <c:decisionReply><c:casePriority>3</c:casePriority><c:activeProfileReply/></c:decisionReply>
          </c:replyMessage>
        </soap:Body>
      </soap:Envelope>
    XML
  end

  def successful_tax_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-21248497"><wsu:Created>2007-07-11T18:27:56.314Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.26"><c:merchantReferenceCode>TEST11111111111</c:merchantReferenceCode><c:requestID>1841784762620176127166</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>AMYJY9fl62i+vx2OEQYAx9zv/9UBZAAA5h5D</c:requestToken><c:taxReply><c:reasonCode>100</c:reasonCode><c:grandTotalAmount>1.00</c:grandTotalAmount><c:totalCityTaxAmount>0</c:totalCityTaxAmount><c:city>Madison</c:city><c:totalCountyTaxAmount>0</c:totalCountyTaxAmount><c:totalDistrictTaxAmount>0</c:totalDistrictTaxAmount><c:totalStateTaxAmount>0</c:totalStateTaxAmount><c:state>WI</c:state><c:totalTaxAmount>0</c:totalTaxAmount><c:postalCode>53717</c:postalCode><c:item id="0"><c:totalTaxAmount>0</c:totalTaxAmount></c:item></c:taxReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_create_subscription_response
    <<-XML
    <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Header>
    <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-8747786"><wsu:Created>2008-10-14T20:36:38.467Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.32"><c:merchantReferenceCode>949c7098db10a846595ade653f7d259e</c:merchantReferenceCode><c:requestID>2240165983980008402433</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>AhjzbwSP5cIxVhZHObgEUAU2LoPM+TpAfJAwQyXRR8hAdjiAmAAA6QCH</c:requestToken><c:paySubscriptionCreateReply><c:reasonCode>100</c:reasonCode><c:subscriptionID>2240165983980008402433</c:subscriptionID></c:paySubscriptionCreateReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_update_subscription_response
    <<-XML
    <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Header>
    <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-16655014"><wsu:Created>2008-10-15T19:56:27.676Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.32"><c:merchantReferenceCode>3050b9caff6f393730eebe9ccc450230</c:merchantReferenceCode><c:requestID>2241005875510008402434</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>Ahj//wSP5fDQ6axlQ0gIUKsGLNo0at27OvXbxa82EwpWZLlNw4I85tgKbhwR5zb0gPkgYYZLoo+QgOxxDAnH8vhodNYyoaQEAAAA+QPT</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccAuthReply><c:reasonCode>100</c:reasonCode><c:amount>1.00</c:amount><c:authorizationCode>123456</c:authorizationCode><c:avsCode>Y</c:avsCode><c:avsCodeRaw>Y</c:avsCodeRaw><c:cvCode>M</c:cvCode><c:cvCodeRaw>M</c:cvCodeRaw><c:authorizedDateTime>2008-10-15T19:56:27Z</c:authorizedDateTime><c:processorResponse>00</c:processorResponse><c:authFactorCode>U</c:authFactorCode></c:ccAuthReply><c:ccCaptureReply><c:reasonCode>100</c:reasonCode><c:requestDateTime>2008-10-15T19:56:27Z</c:requestDateTime><c:amount>1.00</c:amount><c:reconciliationID>013445773WW7EWMB0RYI9</c:reconciliationID></c:ccCaptureReply><c:paySubscriptionCreateReply><c:reasonCode>100</c:reasonCode><c:subscriptionID>2241005875510008402434</c:subscriptionID></c:paySubscriptionCreateReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_delete_subscription_response
    <<-XML
    <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Header>
    <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-13372098"><wsu:Created>2012-03-24T02:53:45.725Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.63"><c:merchantReferenceCode>12345</c:merchantReferenceCode><c:requestID>3325576256890176056428</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>AhijLwSRaI9Ig/eISVjYKJvvCSakcAQRwyaSZV0SpjMuAAAA+Al1</c:requestToken><c:paySubscriptionDeleteReply><c:reasonCode>100</c:reasonCode><c:subscriptionID>3325576252130176056442</c:subscriptionID></c:paySubscriptionDeleteReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_capture_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"> <soap:Header> <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-6000655"><wsu:Created>2007-07-17T17:15:32.642Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.26"><c:merchantReferenceCode>test1111111111111111</c:merchantReferenceCode><c:requestID>1846925324700976124593</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>AP4JZB883WKS/34BEZAzMTE1OTI5MVQzWE0wQjEzBTUt3wbOAQUy3D7oDgMMmvQAnQgl</c:requestToken><c:purchaseTotals><c:currency>GBP</c:currency></c:purchaseTotals><c:ccCaptureReply><c:reasonCode>100</c:reasonCode><c:requestDateTime>2007-07-17T17:15:32Z</c:requestDateTime><c:amount>1.00</c:amount><c:reconciliationID>31159291T3XM2B13</c:reconciliationID></c:ccCaptureReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_refund_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-5589339"><wsu:Created>2008-01-21T16:00:38.927Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.32"><c:merchantReferenceCode>TEST11111111111</c:merchantReferenceCode><c:requestID>2009312387810008401927</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>Af/vj7OzPmut/eogHFCrBiwYsWTJy1r127CpCn0KdOgyTZnzKwVYCmzPmVgr9ID5H1WGTSTKuj0i30IE4+zsz2d/QNzwBwAACCPA</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccCreditReply><c:reasonCode>100</c:reasonCode><c:requestDateTime>2008-01-21T16:00:38Z</c:requestDateTime><c:amount>1.00</c:amount><c:reconciliationID>010112295WW70TBOPSSP2</c:reconciliationID></c:ccCreditReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_card_credit_response
    <<~XML
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">\n<soap:Header>\n<wsse:Security xmlns:wsse=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd\"><wsu:Timestamp xmlns:wsu=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd\" wsu:Id=\"Timestamp-1360351593\"><wsu:Created>2019-05-16T20:25:05.234Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c=\"urn:schemas-cybersource-com:transaction-data-1.153\"><c:merchantReferenceCode>329b25a4540e05c731a4fb16112e4c72</c:merchantReferenceCode><c:requestID>5580383051126990804008</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>Ahj/7wSTLoNfMt0KyZQoGxDdm1ctGjlmo0/RdCA4BUafouhAdpAfJHYQyaSZbpAdvSeAnJl0GvmW6FZMoUAA/SE0</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccCreditReply><c:reasonCode>100</c:reasonCode><c:requestDateTime>2019-05-16T20:25:05Z</c:requestDateTime><c:amount>1.00</c:amount><c:reconciliationID>73594493</c:reconciliationID></c:ccCreditReply><c:acquirerMerchantNumber>000123456789012</c:acquirerMerchantNumber><c:pos><c:terminalID>01234567</c:terminalID></c:pos></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_subscription_credit_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-5589339"><wsu:Created>2008-01-21T16:00:38.927Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.69"><c:merchantReferenceCode>TEST11111111111</c:merchantReferenceCode><c:requestID>2009312387810008401927</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>Af/vj7OzPmut/eogHFCrBiwYsWTJy1r127CpCn0KdOgyTZnzKwVYCmzPmVgr9ID5H1WGTSTKuj0i30IE4+zsz2d/QNzwBwAACCPA</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccCreditReply><c:reasonCode>100</c:reasonCode><c:requestDateTime>2012-09-28T16:59:25Z</c:requestDateTime><c:amount>1.00</c:amount><c:reconciliationID>010112295WW70TBOPSSP2</c:reconciliationID></c:ccCreditReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_retrieve_subscription_response
    <<-XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-21454119"><wsu:Created>2012-05-15T14:29:52.833Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.69"><c:merchantReferenceCode>0da9f4799515bfbfb85cbf6ab8839cde</c:merchantReferenceCode><c:requestID>3370921927710176056428</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>AhjzbwSRbXng4q9oFCjYIAKb7zXE/n0gAQsQyaSZV0ekrf+AaAAA+Q2H</c:requestToken><c:paySubscriptionRetrieveReply><c:reasonCode>100</c:reasonCode><c:approvalRequired>false</c:approvalRequired><c:automaticRenew>false</c:automaticRenew><c:cardAccountNumber>411111XXXXXX1111</c:cardAccountNumber><c:cardExpirationMonth>09</c:cardExpirationMonth><c:cardExpirationYear>2013</c:cardExpirationYear><c:cardType>001</c:cardType><c:city>Ottawa</c:city><c:companyName>Widgets Inc</c:companyName><c:country>CA</c:country><c:currency>USD</c:currency><c:email>someguy1232@fakeemail.net</c:email><c:endDate>99991231</c:endDate><c:firstName>JIM</c:firstName><c:frequency>on-demand</c:frequency><c:lastName>SMITH</c:lastName><c:paymentMethod>credit card</c:paymentMethod><c:paymentsRemaining>0</c:paymentsRemaining><c:postalCode>K1C2N6</c:postalCode><c:startDate>20120521</c:startDate><c:state>ON</c:state><c:status>CURRENT</c:status><c:street1>1234 My Street</c:street1><c:street2>Apt 1</c:street2><c:subscriptionID>3370921906250176056428</c:subscriptionID><c:totalPayments>0</c:totalPayments></c:paySubscriptionRetrieveReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_validate_pinless_debit_card
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-190204278"><wsu:Created>2013-05-13T13:52:57.159Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.69"><c:merchantReferenceCode>6427013</c:merchantReferenceCode><c:requestID>3684531771310176056442</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>AhijbwSRj3pM2QqPs2j0Ip+xoJXIsAMPYZNJMq6PSbs5ATAA6z42</c:requestToken><c:pinlessDebitValidateReply><c:reasonCode>100</c:reasonCode><c:requestDateTime>2013-05-13T13:52:57Z</c:requestDateTime><c:status>Y</c:status></c:pinlessDebitValidateReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_auth_reversal_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-1818361101"><wsu:Created>2016-07-25T21:10:31.506Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.121"><c:merchantReferenceCode>296805293329eea14917a8d04c63a0c4</c:merchantReferenceCode><c:requestID>4694810311256262804010</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>Ahj//wSR/QMpn9U9RwRUIkG7Nm4cMm7KVRrS4tppCS5TonESgFLhgHRTp0gPkYP4ZNJMt0gO3pPFAnI/oGUyy27D1uIA+xVK</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccAuthReversalReply><c:reasonCode>100</c:reasonCode><c:amount>1.00</c:amount><c:processorResponse>100</c:processorResponse><c:requestDateTime>2016-07-25T21:10:31Z</c:requestDateTime></c:ccAuthReversalReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_void_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-753384332"><wsu:Created>2016-07-25T20:50:50.583Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.121"><c:merchantReferenceCode>bb3b1bb530192c9dd20f121686c91c40</c:merchantReferenceCode><c:requestID>4694798504476543904007</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>Ahj//wSR/QLVu2z/GtIOIkG7Nm4bNW7KPRrRY0mvYS4YB0I7QFLgkgkAA0gAwfwyaSZbpAdvSeeBOR/QLVqII/qE+QAA3yVt</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:voidReply><c:reasonCode>100</c:reasonCode><c:requestDateTime>2016-07-25T20:50:50Z</c:requestDateTime><c:amount>1.00</c:amount><c:currency>usd</c:currency></c:voidReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_nonfractional_authorization_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-32551101"><wsu:Created>2007-07-12T18:31:53.838Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.26"><c:merchantReferenceCode>TEST11111111111</c:merchantReferenceCode><c:requestID>1842651133440156177166</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>AP4JY+Or4xRonEAOERAyMzQzOTEzMEM0MFZaNUZCBgDH3fgJ8AEGAMfd+AnwAwzRpAAA7RT/</c:requestToken><c:purchaseTotals><c:currency>JPY</c:currency></c:purchaseTotals><c:ccAuthReply><c:reasonCode>100</c:reasonCode><c:amount>1</c:amount><c:authorizationCode>004542</c:authorizationCode><c:avsCode>A</c:avsCode><c:avsCodeRaw>I7</c:avsCodeRaw><c:authorizedDateTime>2007-07-12T18:31:53Z</c:authorizedDateTime><c:processorResponse>100</c:processorResponse><c:reconciliationID>23439130C40VZ2FB</c:reconciliationID></c:ccAuthReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def authorization_review_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-32551101"><wsu:Created>2007-07-12T18:31:53.838Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.26"><c:merchantReferenceCode>TEST11111111111</c:merchantReferenceCode><c:requestID>1842651133440156177166</c:requestID><c:decision>REVIEW</c:decision><c:reasonCode>480</c:reasonCode><c:requestToken>AP4JY+Or4xRonEAOERAyMzQzOTEzMEM0MFZaNUZCBgDH3fgJ8AEGAMfd+AnwAwzRpAAA7RT/</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccAuthReply><c:reasonCode>100</c:reasonCode><c:amount>1.00</c:amount><c:authorizationCode>004542</c:authorizationCode><c:avsCode>A</c:avsCode><c:avsCodeRaw>I7</c:avsCodeRaw><c:authorizedDateTime>2007-07-12T18:31:53Z</c:authorizedDateTime><c:processorResponse>100</c:processorResponse><c:reconciliationID>23439130C40VZ2FB</c:reconciliationID></c:ccAuthReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def malformed_xml_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-2636690"><wsu:Created>2008-01-15T21:42:03.343Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.26"><c:merchantReferenceCode>b0a6cf9aa07f1a8495f89c364bbd6a9a</c:merchantReferenceCode><c:requestID>2004333231260008401927</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>Afvvj7Ke2Fmsbq0wHFE2sM6R4GAptYZ0jwPSA+R9PhkyhFTb0KRjoE4+ynthZrG6tMBwjAtT</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccAuthReply><c:reasonCode>100</c:reasonCode><c:amount>1.00</c:amount><c:authorizationCode>123456</c:authorizationCode><c:avsCode>Y</c:avsCode><c:avsCodeRaw>Y</c:avsCodeRaw><c:cvCode>M</c:cvCode><c:cvCodeRaw>M</c:cvCodeRaw><c:authorizedDateTime>2008-01-15T21:42:03Z</c:authorizedDateTime><c:processorResponse>00</c:processorResponse><c:authFactorCode>U</c:authFactorCode><p></c:ccAuthReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def threedeesecure_purchase_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-1347906680"><wsu:Created>2017-10-17T20:39:27.392Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.121"><c:merchantReferenceCode>1a5ba4804da54b384c6e8a2d8057ea99</c:merchantReferenceCode><c:requestID>5082727663166909004012</c:requestID><c:decision>REJECT</c:decision><c:reasonCode>475</c:reasonCode><c:requestToken>AhjzbwSTE4kEGDR65zjsGwFLjtwzsJ0gXLJx6Xb0ky3SA7ek8AYA/A17</c:requestToken><c:payerAuthEnrollReply><c:reasonCode>475</c:reasonCode><c:acsURL>https://0eafstag.cardinalcommerce.com/EAFService/jsp/v1/redirect</c:acsURL><c:paReq>eNpVUe9PwjAQ/d6/ghA/r2tBYMvRBEUFFEKQEP1Yu1Om7gfdJoy/3nZsgk2a3Lveu757B+utRhw/oyo0CphjlskPbIXBsC25TvuPD/lkc3xn2d2R6y+3LWA5WuFOwA/qLExiwRzX4UAbSEwLrbYyzgVItbuZLkS353HWA1pDAhHq6Vgw3ule9/pAT5BALCMUqnwznZJCKwRaZQiopIhzXYpB1wXaAAKF/hbbPE8zn9L9fu9cUB2VREBtAQF6FrQsbJSZOQ9hIF7Xs1KNg6dVZzXdxGk0f1nc4+eslMfREKitIBDIHAV3WZ+Z2+Ku3/F8bjRXeQIysmrEFeOOa0yoIYHUfjQ6Icbt02XGTFRojbFqRmoQATykSYymxlD+YjPDWfntxBqrcusg8wbmWGcrXNFD4w3z2IkfVkZRy6H13mi9YhP9W/0vhyyqPw==</c:paReq><c:proxyPAN>1198888</c:proxyPAN><c:xid>YTJycDdLR3RIVnpmMXNFejJyazA=</c:xid><c:proofXML>&lt;AuthProof&gt;&lt;Time&gt;2017 Oct 17 20:39:27&lt;/Time&gt;&lt;DSUrl&gt;https://csrtestcustomer34.cardinalcommerce.com/merchantacsfrontend/vereq.jsp?acqid=CYBS&lt;/DSUrl&gt;&lt;VEReqProof&gt;&lt;Message id="a2rp7KGtHVzf1sEz2rk0"&gt;&lt;VEReq&gt;&lt;version&gt;1.0.2&lt;/version&gt;&lt;pan&gt;XXXXXXXXXXXX0002&lt;/pan&gt;&lt;Merchant&gt;&lt;acqBIN&gt;469216&lt;/acqBIN&gt;&lt;merID&gt;1234567&lt;/merID&gt;&lt;/Merchant&gt;&lt;Browser&gt;&lt;deviceCategory&gt;0&lt;/deviceCategory&gt;&lt;/Browser&gt;&lt;/VEReq&gt;&lt;/Message&gt;&lt;/VEReqProof&gt;&lt;VEResProof&gt;&lt;Message id="a2rp7KGtHVzf1sEz2rk0"&gt;&lt;VERes&gt;&lt;version&gt;1.0.2&lt;/version&gt;&lt;CH&gt;&lt;enrolled&gt;Y&lt;/enrolled&gt;&lt;acctID&gt;1198888&lt;/acctID&gt;&lt;/CH&gt;&lt;url&gt;https://testcustomer34.cardinalcommerce.com/merchantacsfrontend/pareq.jsp?vaa=b&amp;amp;gold=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA&lt;/url&gt;&lt;protocol&gt;ThreeDSecure&lt;/protocol&gt;&lt;/VERes&gt;&lt;/Message&gt;&lt;/VEResProof&gt;&lt;/AuthProof&gt;</c:proofXML><c:veresEnrolled>Y</c:veresEnrolled><c:authenticationPath>ENROLLED</c:authenticationPath></c:payerAuthEnrollReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def successful_threedeesecure_validate_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-635495097"><wsu:Created>2018-05-01T14:28:36.773Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.121"><c:merchantReferenceCode>23751b5aeb076ea5940c5b656284bf6a</c:merchantReferenceCode><c:requestID>5251849164756591904009</c:requestID><c:decision>ACCEPT</c:decision><c:reasonCode>100</c:reasonCode><c:requestToken>Ahj//wSTHLQMXdtQnQUJGxDds0bNnDRoo0+VcdXMBUafKuOrnpAuWT9zDJpJlukB29J4YBpMctAxd21CdBQkwQ3g</c:requestToken><c:purchaseTotals><c:currency>USD</c:currency></c:purchaseTotals><c:ccAuthReply><c:reasonCode>100</c:reasonCode><c:amount>12.02</c:amount><c:authorizationCode>831000</c:authorizationCode><c:avsCode>Y</c:avsCode><c:avsCodeRaw>Y</c:avsCodeRaw><c:authorizedDateTime>2018-05-01T14:28:36Z</c:authorizedDateTime><c:processorResponse>00</c:processorResponse><c:reconciliationID>ZLIU5GM27GBP</c:reconciliationID><c:authRecord>0110322000000E10000200000000000000120205011428360272225A4C495535474D32374742503833313030303030000159004400103232415050524F56414C0022313457303136313530373033383032303934473036340006564943524120</c:authRecord></c:ccAuthReply><c:ccCaptureReply><c:reasonCode>100</c:reasonCode><c:requestDateTime>2018-05-01T14:28:36Z</c:requestDateTime><c:amount>12.02</c:amount><c:reconciliationID>76466844</c:reconciliationID></c:ccCaptureReply><c:payerAuthValidateReply><c:reasonCode>100</c:reasonCode><c:authenticationResult>0</c:authenticationResult><c:authenticationStatusMessage>Success</c:authenticationStatusMessage><c:cavv>AAABAWFlmQAAAABjRWWZEEFgFz+=</c:cavv><c:cavvAlgorithm>2</c:cavvAlgorithm><c:commerceIndicator>vbv</c:commerceIndicator><c:eci>05</c:eci><c:eciRaw>05</c:eciRaw><c:xid>S2R4eGtHbEZqbnozeGhBRHJ6QzA=</c:xid><c:paresStatus>Y</c:paresStatus></c:payerAuthValidateReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def missing_field_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-2122229692"><wsu:Created>2019-09-05T01:02:20.132Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.155"><c:merchantReferenceCode>9y2A7XGxMSOUqppiEXkiN8T38Jj</c:merchantReferenceCode><c:requestID>5676453399086696204061</c:requestID><c:decision>REJECT</c:decision><c:reasonCode>101</c:reasonCode><c:missingField>c:billTo/c:country</c:missingField><c:requestToken>Ahjz7wSTM7ido1SNM4cdGwFRfPELvH+kE/QkEg+jLpJlXR6RuUgJMmZ3E7RqkaZw46AAniPV</c:requestToken><c:ccAuthReply><c:reasonCode>101</c:reasonCode></c:ccAuthReply></c:replyMessage></soap:Body></soap:Envelope>
    XML
  end

  def invalid_field_response
    <<~XML
      <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header>
      <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Timestamp-1918753692"><wsu:Created>2019-09-05T14:10:46.665Z</wsu:Created></wsu:Timestamp></wsse:Security></soap:Header><soap:Body><c:replyMessage xmlns:c="urn:schemas-cybersource-com:transaction-data-1.155"><c:requestID>5676926465076767004068</c:requestID><c:decision>REJECT</c:decision><c:reasonCode>102</c:reasonCode><c:invalidField>c:billTo/c:postalCode</c:invalidField><c:requestToken>AhjzbwSTM78uTleCsJWkEAJRqivRidukDssiQgRm0ky3SA7oegDUiwLm</c:requestToken></c:replyMessage></soap:Body></soap:Envelope>

    XML
  end

  def invalid_xml_response
    "What's all this then, govna?</p>"
  end

  def assert_xml_valid_to_xsd(data, root_element = '//s:Body/*')
    schema_file = File.open("#{File.dirname(__FILE__)}/../../schema/cyber_source/CyberSourceTransaction_#{CyberSourceGateway::TEST_XSD_VERSION}.xsd")
    doc = Nokogiri::XML(data)
    root = Nokogiri::XML(doc.xpath(root_element).to_s)
    xsd = Nokogiri::XML::Schema(schema_file)
    errors = xsd.validate(root)
    assert_empty errors, "XSD validation errors in the following XML:\n#{root}"
  end
end
