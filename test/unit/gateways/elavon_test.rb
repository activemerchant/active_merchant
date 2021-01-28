require 'test_helper'

class ElavonTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = ElavonGateway.new(
      login: 'login',
      user: 'user',
      password: 'password'
    )

    @multi_currency_gateway = ElavonGateway.new(
      login: 'login',
      user: 'user',
      password: 'password',
      multi_currency: true
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '093840;180820AD3-27AEE6EF-8CA7-4811-8D1F-E420C3B5041E', response.authorization
    assert response.test?
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '259404;150920ED4-3EB7A2DF-A5A7-48E6-97B6-D98A9DC0BD59', response.authorization
    assert_equal 'APPROVAL', response.message
    assert response.test?
  end

  def test_failed_authorization
    @gateway.expects(:ssl_post).returns(failed_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    authorization = '070213;110820ED4-23CA2F2B-A88C-40E1-AC46-9219F800A520'

    assert response = @gateway.capture(@amount, authorization, credit_card: @credit_card)
    assert_instance_of Response, response
    assert_success response

    assert_equal '070213;110820ED4-23CA2F2B-A88C-40E1-AC46-9219F800A520', response.authorization
    assert_equal 'APPROVAL', response.message
    assert response.test?
  end

  def test_successful_capture_with_auth_code
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    authorization = '070213;110820ED4-23CA2F2B-A88C-40E1-AC46-9219F800A520'

    assert response = @gateway.capture(@amount, authorization)
    assert_instance_of Response, response
    assert_success response

    assert_equal '070213;110820ED4-23CA2F2B-A88C-40E1-AC46-9219F800A520', response.authorization
    assert_equal 'APPROVAL', response.message
    assert response.test?
  end

  def test_successful_capture_with_additional_options
    authorization = '070213;110820ED4-23CA2F2B-A88C-40E1-AC46-9219F800A520'
    response = stub_comms do
      @gateway.capture(@amount, authorization, test_mode: true, partial_shipment_flag: true)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<ssl_transaction_type>CCCOMPLETE<\/ssl_transaction_type>/, data)
      assert_match(/<ssl_test_mode>TRUE<\/ssl_test_mode>/, data)
      assert_match(/<ssl_partial_shipment_flag>Y<\/ssl_partial_shipment_flag>/, data)
    end.respond_with(successful_capture_response)

    assert_instance_of Response, response
    assert_success response

    assert_equal '070213;110820ED4-23CA2F2B-A88C-40E1-AC46-9219F800A520', response.authorization
    assert_equal 'APPROVAL', response.message
    assert response.test?
  end

  def test_successful_purchase_with_ip
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(ip: '203.0.113.0'))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/203.0.113.0/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_authorization_with_ip
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(ip: '203.0.113.0'))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<ssl_cardholder_ip>203.0.113.0<\/ssl_cardholder_ip>/, data)
    end.respond_with(successful_authorization_response)

    assert_success response
  end

  def test_successful_purchase_with_dynamic_dba
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(dba: 'MANYMAG*BAKERS MONTHLY'))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<ssl_dynamic_dba>MANYMAG\*BAKERS MONTHLY<\/ssl_dynamic_dba>/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_unscheduled
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(merchant_initiated_unscheduled: 'Y'))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<ssl_merchant_initiated_unscheduled>Y<\/ssl_merchant_initiated_unscheduled>/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_authorization_with_dynamic_dba
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(dba: 'MANYMAG*BAKERS MONTHLY'))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<ssl_dynamic_dba>MANYMAG\*BAKERS MONTHLY<\/ssl_dynamic_dba>/, data)
    end.respond_with(successful_authorization_response)

    assert_success response
  end

  def test_successful_purchase_with_multi_currency
    response = stub_comms(@multi_currency_gateway) do
      @multi_currency_gateway.purchase(@amount, @credit_card, @options.merge(currency: 'JPY'))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<ssl_transaction_currency>JPY<\/ssl_transaction_currency>/, data)
    end.respond_with(successful_purchase_with_multi_currency_response)

    assert_success response
  end

  def test_successful_purchase_without_multi_currency
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(currency: 'EUR', multi_currency: false))
    end.check_request do |_endpoint, data, _headers|
      assert_no_match(/ssl_transaction_currency=EUR/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_authorization_response)
    authorization = '123456INVALID;00000000-0000-0000-0000-00000000000'

    assert response = @gateway.capture(@amount, authorization, credit_card: @credit_card)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert response = @gateway.void('123')
    assert_success response
    assert_equal 'APPROVAL', response.message
  end

  def test_unsuccessful_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    assert response = @gateway.void('123')
    assert_failure response
    assert_equal 'The transaction ID is invalid for this transaction type', response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert response = @gateway.refund(123, '456')
    assert_success response
    assert_equal 'APPROVAL', response.message
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert response = @gateway.refund(123, '456')
    assert_failure response
    assert_equal 'The amount exceeded the original transaction amount. Amount must be equal or lower than the original transaction amount.', response.message
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_verify_response)
    assert_success response
  end

  def test_unsuccessful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_verify_response)
    assert_failure response
    assert_equal 'The Credit Card Number supplied in the authorization request appears to be invalid.', response.message
  end

  def test_invalid_login
    @gateway.expects(:ssl_post).returns(invalid_login_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_equal '4025', response.params['errorCode']
    assert_equal 'The credentials supplied in the authorization request are invalid.', response.message
    assert_failure response
  end

  def test_supported_card_types
    assert_equal %i[visa master american_express discover], ElavonGateway.supported_cardtypes
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'M', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'M', response.cvv_result['code']
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal '4421912014039990', response.params['token']
    assert response.test?
  end

  def test_failed_store
    @gateway.expects(:ssl_post).returns(failed_store_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_successful_update
    @gateway.expects(:ssl_post).returns(successful_update_response)
    token = '7595301425001111'
    assert response = @gateway.update(token, @credit_card, @options)
    assert_success response
    assert response.test?
  end

  def test_failed_update
    @gateway.expects(:ssl_post).returns(failed_update_response)
    token = '7595301425001111'
    assert response = @gateway.update(token, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_stripping_non_word_characters_from_zip
    bad_zip = '99577-0727'
    stripped_zip = '995770727'

    @options[:billing_address][:zip] = bad_zip

    @gateway.expects(:commit).with(includes("<ssl_avs_zip>#{stripped_zip}</ssl_avs_zip>"))

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_zip_codes_with_letters_are_left_intact
    @options[:billing_address][:zip] = '.K1%Z_5E3-'

    @gateway.expects(:commit).with(includes('<ssl_avs_zip>K1Z5E3</ssl_avs_zip>'))

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_strip_ampersands
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(shipping_address: { address1: 'Bats & Cats' }))
    end.check_request do |_endpoint, data, _headers|
      refute_match(/&/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_split_full_network_transaction_id
    oar_data = '010012318808182231420000047554200000000000093840023122123188'
    ps2000_data = 'A8181831435010530042VE'
    network_transaction_id = "#{oar_data}|#{ps2000_data}"
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(stored_credential: { network_transaction_id: network_transaction_id }))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<ssl_oar_data>#{oar_data}<\/ssl_oar_data>/, data)
      assert_match(/<ssl_ps2000_data>#{ps2000_data}<\/ssl_ps2000_data>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_oar_only_network_transaction_id
    oar_data = '010012318808182231420000047554200000000000093840023122123188'
    ps2000_data = nil
    network_transaction_id = "#{oar_data}|#{ps2000_data}"
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(stored_credential: { network_transaction_id: network_transaction_id }))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<ssl_oar_data>#{oar_data}<\/ssl_oar_data>/, data)
      refute_match(/<ssl_ps2000_data>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_ps2000_only_network_transaction_id
    oar_data = nil
    ps2000_data = 'A8181831435010530042VE'
    network_transaction_id = "#{oar_data}|#{ps2000_data}"
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(stored_credential: { network_transaction_id: network_transaction_id }))
    end.check_request do |_endpoint, data, _headers|
      refute_match(/<ssl_oar_data>/, data)
      assert_match(/<ssl_ps2000_data>#{ps2000_data}<\/ssl_ps2000_data>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_oar_transaction_id_without_pipe
    oar_data = '010012318808182231420000047554200000000000093840023122123188'
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(stored_credential: { network_transaction_id: oar_data }))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<ssl_oar_data>#{oar_data}<\/ssl_oar_data>/, data)
      refute_match(/<ssl_ps2000_data>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_ps2000_transaction_id_without_pipe
    ps2000_data = 'A8181831435010530042VE'
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(stored_credential: { network_transaction_id: ps2000_data }))
    end.check_request do |_endpoint, data, _headers|
      refute_match(/<ssl_oar_data>/, data)
      assert_match(/<ssl_ps2000_data>#{ps2000_data}<\/ssl_ps2000_data>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_custom_fields_in_request
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(customer_number: '123', custom_fields: { a_key: 'a value' }))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<ssl_customer_number>123<\/ssl_customer_number>/, data)
      assert_match(/<a_key>a value<\/a_key>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_level_3_fields_in_request
    level_3_data = {
      customer_code: 'bob',
      salestax: '3.45',
      salestax_indicator: 'Y',
      level3_indicator: 'Y',
      ship_to_zip: '12345',
      ship_to_country: 'US',
      shipping_amount: '1234',
      ship_from_postal_code: '54321',
      discount_amount: '5',
      duty_amount: '2',
      national_tax_indicator: '0',
      national_tax_amount: '10',
      order_date: '280810',
      other_tax: '3',
      summary_commodity_code: '123',
      merchant_vat_number: '222',
      customer_vat_number: '333',
      freight_tax_amount: '4',
      vat_invoice_number: '26',
      tracking_number: '45',
      shipping_company: 'UFedzon',
      other_fees: '2',
      line_items: [
        {
          description: 'thing',
          product_code: '23',
          commodity_code: '444',
          quantity: '15',
          unit_of_measure: 'kropogs',
          unit_cost: '4.5',
          discount_indicator: 'Y',
          tax_indicator: 'Y',
          discount_amount: '1',
          tax_rate: '8.25',
          tax_amount: '12',
          tax_type: 'state',
          extended_total: '500',
          total: '525',
          alternative_tax: '111'
        },
        {
          description: 'thing2',
          product_code: '23',
          commodity_code: '444',
          quantity: '15',
          unit_of_measure: 'kropogs',
          unit_cost: '4.5',
          discount_indicator: 'Y',
          tax_indicator: 'Y',
          discount_amount: '1',
          tax_rate: '8.25',
          tax_amount: '12',
          tax_type: 'state',
          extended_total: '500',
          total: '525',
          alternative_tax: '111'
        }
      ]
    }

    options = @options.merge(level_3_data: level_3_data)
    stub_comms do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<ssl_customer_code>bob/, data)
      assert_match(/<ssl_salestax>3.45/, data)
      assert_match(/<ssl_salestax_indicator>Y/, data)
      assert_match(/<ssl_level3_indicator>Y/, data)
      assert_match(/<ssl_ship_to_zip>12345/, data)
      assert_match(/<ssl_ship_to_country>US/, data)
      assert_match(/<ssl_shipping_amount>1234/, data)
      assert_match(/<ssl_ship_from_postal_code>54321/, data)
      assert_match(/<ssl_discount_amount>5/, data)
      assert_match(/<ssl_duty_amount>2/, data)
      assert_match(/<ssl_national_tax_indicator>0/, data)
      assert_match(/<ssl_national_tax_amount>10/, data)
      assert_match(/<ssl_order_date>280810/, data)
      assert_match(/<ssl_other_tax>3/, data)
      assert_match(/<ssl_summary_commodity_code>123/, data)
      assert_match(/<ssl_merchant_vat_number>222/, data)
      assert_match(/<ssl_customer_vat_number>333/, data)
      assert_match(/<ssl_freight_tax_amount>4/, data)
      assert_match(/<ssl_vat_invoice_number>26/, data)
      assert_match(/<ssl_tracking_number>45/, data)
      assert_match(/<ssl_shipping_company>UFedzon/, data)
      assert_match(/<ssl_other_fees>2/, data)
      assert_match(/<ssl_line_Item_description>/, data)
      assert_match(/<ssl_line_Item_product_code>/, data)
      assert_match(/<ssl_line_Item_commodity_code>/, data)
      assert_match(/<ssl_line_Item_quantity>/, data)
      assert_match(/<ssl_line_Item_unit_of_measure>/, data)
      assert_match(/<ssl_line_Item_unit_cost>/, data)
      assert_match(/<ssl_line_Item_discount_indicator>/, data)
      assert_match(/<ssl_line_Item_tax_indicator>/, data)
      assert_match(/<ssl_line_Item_discount_amount>/, data)
      assert_match(/<ssl_line_Item_tax_rate>/, data)
      assert_match(/<ssl_line_Item_tax_amount>/, data)
      assert_match(/<ssl_line_Item_tax_type>/, data)
      assert_match(/<ssl_line_Item_extended_total>/, data)
      assert_match(/<ssl_line_Item_total>/, data)
      assert_match(/<ssl_line_Item_alternative_tax>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_shipping_address_in_request
    shipping_address = {
      address1: '733 Foster St.',
      city: 'Durham',
      state: 'NC',
      phone: '8887277750',
      country: 'USA',
      zip: '27701'
    }
    options = @options.merge(shipping_address: shipping_address)
    stub_comms do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<ssl_ship_to_address1>733 Foster St./, data)
      assert_match(/<ssl_ship_to_city>Durham/, data)
      assert_match(/<ssl_ship_to_state>NC/, data)
      assert_match(/<ssl_ship_to_phone>8887277750/, data)
      assert_match(/<ssl_ship_to_country>USA/, data)
      assert_match(/<ssl_ship_to_zip>27701/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_transcript_scrubbing
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrub), post_scrub
  end

  private

  def successful_purchase_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
      <txn>
        <ssl_issuer_response>00</ssl_issuer_response>
        <ssl_last_name>Longsen</ssl_last_name>
        <ssl_company>Widgets Inc</ssl_company>
        <ssl_phone>(555)555-5555</ssl_phone>
        <ssl_card_number>41**********9990</ssl_card_number>
        <ssl_departure_date></ssl_departure_date>
        <ssl_oar_data>010012318808182231420000047554200000000000093840023122123188</ssl_oar_data>
        <ssl_result>0</ssl_result>
        <ssl_txn_id>180820AD3-27AEE6EF-8CA7-4811-8D1F-E420C3B5041E</ssl_txn_id>
        <ssl_avs_response>M</ssl_avs_response>
        <ssl_approval_code>093840</ssl_approval_code>
        <ssl_email>paul@domain.com</ssl_email>
        <ssl_amount>100.00</ssl_amount>
        <ssl_avs_zip>K1C2N6</ssl_avs_zip>
        <ssl_txn_time>08/18/2020 06:31:42 PM</ssl_txn_time>
        <ssl_exp_date>0921</ssl_exp_date>
        <ssl_card_short_description>VISA</ssl_card_short_description>
        <ssl_completion_date></ssl_completion_date>
        <ssl_address2>Apt 1</ssl_address2>
        <ssl_country>CA</ssl_country>
        <ssl_card_type>CREDITCARD</ssl_card_type>
        <ssl_transaction_type>AUTHONLY</ssl_transaction_type>
        <ssl_salestax></ssl_salestax>
        <ssl_avs_address>456 My Street</ssl_avs_address>
        <ssl_account_balance>0.00</ssl_account_balance>
        <ssl_ps2000_data>A8181831435010530042VE</ssl_ps2000_data>
        <ssl_state>ON</ssl_state>
        <ssl_city>Ottawa</ssl_city>
        <ssl_result_message>APPROVAL</ssl_result_message>
        <ssl_first_name>Longbob</ssl_first_name>
        <ssl_invoice_number></ssl_invoice_number>
        <ssl_cvv2_response>M</ssl_cvv2_response>
        <ssl_partner_app_id>VM</ssl_partner_app_id>
      </txn>
    XML
  end

  def successful_purchase_with_multi_currency_response
    <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <txn>
        <ssl_issuer_response>00</ssl_issuer_response>
        <ssl_issue_points></ssl_issue_points>
        <ssl_card_number>41**********9990</ssl_card_number>
        <ssl_departure_date></ssl_departure_date>
        <ssl_oar_data>010012316708182238060000047554200000000000093864023122123167</ssl_oar_data>
        <ssl_result>0</ssl_result>
        <ssl_txn_id>180820ED3-1DD371B9-64DF-4902-B377-EBD095E6DAF0</ssl_txn_id>
        <ssl_loyalty_program></ssl_loyalty_program>
        <ssl_avs_response>M</ssl_avs_response>
        <ssl_approval_code>093864</ssl_approval_code>
        <ssl_account_status></ssl_account_status>
        <ssl_amount>100</ssl_amount>
        <ssl_transaction_currency>JPY</ssl_transaction_currency>
        <ssl_txn_time>08/18/2020 06:38:06 PM</ssl_txn_time>
        <ssl_promo_code></ssl_promo_code>
        <ssl_exp_date>0921</ssl_exp_date>
        <ssl_card_short_description>VISA</ssl_card_short_description>
        <ssl_completion_date></ssl_completion_date>
        <ssl_card_type>CREDITCARD</ssl_card_type>
        <ssl_access_code></ssl_access_code>
        <ssl_transaction_type>SALE</ssl_transaction_type>
        <ssl_loyalty_account_balance></ssl_loyalty_account_balance>
        <ssl_salestax>0.00</ssl_salestax>
        <ssl_enrollment></ssl_enrollment>
        <ssl_account_balance>0.00</ssl_account_balance>
        <ssl_ps2000_data>A8181838065010780213VE</ssl_ps2000_data>
        <ssl_result_message>APPROVAL</ssl_result_message>
        <ssl_invoice_number></ssl_invoice_number>
        <ssl_cvv2_response></ssl_cvv2_response>
        <ssl_tender_amount></ssl_tender_amount>
        <ssl_partner_app_id>VM</ssl_partner_app_id>
      </txn>
    XML
  end

  def successful_refund_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <txn>
      <ssl_issuer_response>00</ssl_issuer_response>
      <ssl_last_name>Longsen</ssl_last_name>
      <ssl_company>Widgets Inc</ssl_company>
      <ssl_phone>(555)555-5555    </ssl_phone>
      <ssl_card_number>41**********9990</ssl_card_number>
      <ssl_departure_date></ssl_departure_date>
      <ssl_result>0</ssl_result>
      <ssl_txn_id>180820AD3-4BACDE38-63F3-427D-BFC1-1B3EB046056B</ssl_txn_id>
      <ssl_avs_response></ssl_avs_response>
      <ssl_approval_code>094012</ssl_approval_code>
      <ssl_email>paul@domain.com</ssl_email>
      <ssl_amount>100.00</ssl_amount>
      <ssl_avs_zip>K1C2N6</ssl_avs_zip>
      <ssl_txn_time>08/18/2020 07:04:49 PM</ssl_txn_time>
      <ssl_exp_date>0921</ssl_exp_date>
      <ssl_card_short_description>VISA</ssl_card_short_description>
      <ssl_completion_date></ssl_completion_date>
      <ssl_address2>Apt 1</ssl_address2>
      <ssl_customer_code></ssl_customer_code>
      <ssl_country>CA</ssl_country>
      <ssl_card_type>CREDITCARD</ssl_card_type>
      <ssl_transaction_type>RETURN</ssl_transaction_type>
      <ssl_salestax></ssl_salestax>
      <ssl_avs_address>456 My Street</ssl_avs_address>
      <ssl_account_balance>0.00</ssl_account_balance>
      <ssl_state>ON</ssl_state>
      <ssl_city>Ottawa</ssl_city>
      <ssl_result_message>APPROVAL</ssl_result_message>
      <ssl_first_name>Longbob</ssl_first_name>
      <ssl_invoice_number></ssl_invoice_number>
      <ssl_cvv2_response></ssl_cvv2_response>
      <ssl_partner_app_id>VM</ssl_partner_app_id>
    </txn>
    XML
  end

  def successful_void_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <txn>
      <ssl_last_name>Longsen</ssl_last_name>
      <ssl_service_fee_amount></ssl_service_fee_amount>
      <ssl_company>Widgets Inc</ssl_company>
      <ssl_phone>(555)555-5555</ssl_phone>
      <ssl_card_number>41**********9990</ssl_card_number>
      <ssl_result>0</ssl_result>
      <ssl_txn_id>180820AD3-2E02E02D-A1FB-4926-A957-3930D3F7B869</ssl_txn_id>
      <ssl_email>paul@domain.com</ssl_email>
      <ssl_amount>100.00</ssl_amount>
      <ssl_avs_zip>K1C2N6</ssl_avs_zip>
      <ssl_txn_time>08/18/2020 06:56:27 PM</ssl_txn_time>
      <ssl_exp_date>0921</ssl_exp_date>
      <ssl_card_short_description>VISA</ssl_card_short_description>
      <ssl_address2>Apt 1</ssl_address2>
      <ssl_credit_surcharge_amount></ssl_credit_surcharge_amount>
      <ssl_country>CA</ssl_country>
      <ssl_card_type>CREDITCARD</ssl_card_type>
      <ssl_transaction_type>DELETE</ssl_transaction_type>
      <ssl_salestax></ssl_salestax>
      <ssl_avs_address>456 My Street</ssl_avs_address>
      <ssl_state>ON</ssl_state>
      <ssl_city>Ottawa</ssl_city>
      <ssl_result_message>APPROVAL</ssl_result_message>
      <ssl_first_name>Longbob</ssl_first_name>
      <ssl_invoice_number></ssl_invoice_number>
      <ssl_partner_app_id>VM</ssl_partner_app_id>
    </txn>
    XML
  end

  def successful_verify_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <txn>
      <ssl_issuer_response>85</ssl_issuer_response>
      <ssl_transaction_type>CARDVERIFICATION</ssl_transaction_type>
      <ssl_card_number>41**********9990</ssl_card_number>
      <ssl_oar_data>010012309508182257450000047554200000000000093964023122123095</ssl_oar_data>
      <ssl_result>0</ssl_result>
      <ssl_txn_id>180820ED4-85DA9146-51AB-4FEC-8004-91C607047E5C</ssl_txn_id>
      <ssl_avs_response>M</ssl_avs_response>
      <ssl_approval_code>093964</ssl_approval_code>
      <ssl_avs_address>456 My Street</ssl_avs_address>
      <ssl_avs_zip>K1C2N6</ssl_avs_zip>
      <ssl_txn_time>08/18/2020 06:57:45 PM</ssl_txn_time>
      <ssl_account_balance>0.00</ssl_account_balance>
      <ssl_ps2000_data>A8181857455011610042VE</ssl_ps2000_data>
      <ssl_exp_date>0921</ssl_exp_date>
      <ssl_result_message>APPROVAL</ssl_result_message>
      <ssl_card_short_description>VISA</ssl_card_short_description>
      <ssl_card_type>CREDITCARD</ssl_card_type>
      <ssl_cvv2_response>M</ssl_cvv2_response>
      <ssl_partner_app_id>VM</ssl_partner_app_id>
    </txn>
    XML
  end

  def failed_purchase_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <txn>
      <errorCode>5000</errorCode>
      <errorName>Credit Card Number Invalid</errorName>
      <errorMessage>The Credit Card Number supplied in the authorization request appears to be invalid.</errorMessage>
    </txn>
    XML
  end

  def failed_refund_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <txn>
      <errorCode>5091</errorCode>
      <errorName>Invalid amount</errorName>
      <errorMessage>The amount exceeded the original transaction amount. Amount must be equal or lower than the original transaction amount.</errorMessage>
    </txn>
    XML
  end

  def failed_void_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <txn>
      <errorCode>5040</errorCode>
      <errorName>Invalid Transaction ID</errorName>
      <errorMessage>The transaction ID is invalid for this transaction type</errorMessage>
    </txn>
    XML
  end

  def failed_verify_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <txn>
      <errorCode>5000</errorCode>
      <errorName>Credit Card Number Invalid</errorName>
      <errorMessage>The Credit Card Number supplied in the authorization request appears to be invalid.</errorMessage>
    </txn>
    XML
  end

  def invalid_login_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <txn>
      <errorCode>4025</errorCode>
      <errorName>Invalid Credentials</errorName>
      <errorMessage>The credentials supplied in the authorization request are invalid.</errorMessage>
    </txn>
    XML
  end

  def successful_authorization_response
    <<-XML
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <txn>
      <ssl_issuer_response>00</ssl_issuer_response>
      <ssl_transaction_type>AUTHONLY</ssl_transaction_type>
      <ssl_card_number>41**********9990</ssl_card_number>
      <ssl_departure_date></ssl_departure_date>
      <ssl_oar_data>010012312309152159540000047554200000000000259404025921123123</ssl_oar_data>
      <ssl_result>0</ssl_result>
      <ssl_txn_id>150920ED4-3EB7A2DF-A5A7-48E6-97B6-D98A9DC0BD59</ssl_txn_id>
      <ssl_avs_response>M</ssl_avs_response>
      <ssl_approval_code>259404</ssl_approval_code>
      <ssl_salestax></ssl_salestax>
      <ssl_amount>100.00</ssl_amount>
      <ssl_txn_time>09/15/2020 05:59:54 PM</ssl_txn_time>
      <ssl_account_balance>0.00</ssl_account_balance>
      <ssl_ps2000_data>A9151759546571260030VE</ssl_ps2000_data>
      <ssl_exp_date>0921</ssl_exp_date>
      <ssl_result_message>APPROVAL</ssl_result_message>
      <ssl_card_short_description>VISA</ssl_card_short_description>
      <ssl_completion_date></ssl_completion_date>
      <ssl_eci_ind>3</ssl_eci_ind>
      <ssl_card_type>CREDITCARD</ssl_card_type>
      <ssl_invoice_number></ssl_invoice_number>
      <ssl_cvv2_response>M</ssl_cvv2_response>
      <ssl_partner_app_id>01</ssl_partner_app_id>
    </txn>
    XML
  end

  def failed_authorization_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <txn>
      <errorCode>5000</errorCode>
      <errorName>Credit Card Number Invalid</errorName>
      <errorMessage>The Credit Card Number supplied in the authorization request appears to be invalid.</errorMessage>
    </txn>
    XML
  end

  def successful_capture_response
    <<~XML
      <txn>
        <ssl_last_name>Longsen</ssl_last_name>
        <ssl_company>Widgets Inc</ssl_company>
        <ssl_phone>(555)555-5555</ssl_phone>
        <ssl_card_number>41**********9990</ssl_card_number>
        <ssl_departure_date></ssl_departure_date>
        <ssl_result>0</ssl_result>
        <ssl_txn_id>110820ED4-23CA2F2B-A88C-40E1-AC46-9219F800A520</ssl_txn_id>
        <ssl_avs_response></ssl_avs_response>
        <ssl_approval_code>070213</ssl_approval_code>
        <ssl_email>paul@domain.com</ssl_email>
        <ssl_amount>100.00</ssl_amount>
        <ssl_avs_zip>K1C2N6</ssl_avs_zip>
        <ssl_txn_time>08/11/2020 10:08:14 PM</ssl_txn_time>
        <ssl_exp_date>0921</ssl_exp_date>
        <ssl_card_short_description>VISA</ssl_card_short_description>
        <ssl_completion_date></ssl_completion_date>
        <ssl_address2>Apt 1</ssl_address2>
        <ssl_country>CA</ssl_country>
        <ssl_card_type>CREDITCARD</ssl_card_type>
        <ssl_transaction_type>FORCE</ssl_transaction_type>
        <ssl_salestax></ssl_salestax>
        <ssl_avs_address>456 My Street</ssl_avs_address>
        <ssl_account_balance>0.00</ssl_account_balance>
        <ssl_state>ON</ssl_state>
        <ssl_city>Ottawa</ssl_city>
        <ssl_result_message>APPROVAL</ssl_result_message>
        <ssl_first_name>Longbob</ssl_first_name>
        <ssl_invoice_number></ssl_invoice_number>
        <ssl_cvv2_response></ssl_cvv2_response>
        <ssl_partner_app_id>VM</ssl_partner_app_id>
      </txn>
    XML
  end

  def failed_capture_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <txn>
      <errorCode>5004</errorCode>
      <errorName>Invalid Approval Code</errorName>
      <errorMessage>The FORCE Approval Code supplied in the authorization request appears to be invalid or blank.  The FORCE Approval Code must be 6 or less alphanumeric characters.</errorMessage>
    </txn>
    XML
  end

  def successful_store_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <txn>
      <ssl_last_name>Longsen</ssl_last_name>
      <ssl_company>Widgets Inc</ssl_company>
      <ssl_phone>(555)555-5555</ssl_phone>
      <ssl_card_number>41**********9990</ssl_card_number>
      <ssl_result>0</ssl_result>
      <ssl_txn_id></ssl_txn_id>
      <ssl_avs_response></ssl_avs_response>
      <ssl_approval_code></ssl_approval_code>
      <ssl_email>paul@domain.com</ssl_email>
      <ssl_avs_zip>K1C2N6</ssl_avs_zip>
      <ssl_txn_time>08/18/2020 07:01:16 PM</ssl_txn_time>
      <ssl_exp_date>0921</ssl_exp_date>
      <ssl_card_short_description>VISA</ssl_card_short_description>
      <ssl_address2>Apt 1</ssl_address2>
      <ssl_token_response>SUCCESS</ssl_token_response>
      <ssl_country>CA</ssl_country>
      <ssl_card_type>CREDITCARD</ssl_card_type>
      <ssl_transaction_type>GETTOKEN</ssl_transaction_type>
      <ssl_salestax></ssl_salestax>
      <ssl_avs_address>456 My Street</ssl_avs_address>
      <ssl_customer_id></ssl_customer_id>
      <ssl_account_balance>0.00</ssl_account_balance>
      <ssl_state>ON</ssl_state>
      <ssl_city>Ottawa</ssl_city>
      <ssl_result_message></ssl_result_message>
      <ssl_first_name>Longbob</ssl_first_name>
      <ssl_invoice_number></ssl_invoice_number>
      <ssl_cvv2_response></ssl_cvv2_response>
      <ssl_token>4421912014039990</ssl_token>
      <ssl_add_token_response>Card Updated</ssl_add_token_response>
    </txn>
    XML
  end

  def failed_store_response
    <<-XML
      <?xml version=\"1.0\" encoding=\"UTF-8\"?>
      <txn>
        <errorCode>5000</errorCode>
        <errorName>Credit Card Number Invalid</errorName>
        <errorMessage>The Credit Card Number supplied in the authorization request appears to be invalid.</errorMessage>
      </txn>
    XML
  end

  def successful_update_response
    <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <txn>
        <ssl_token>4421912014039990</ssl_token>
        <ssl_card_type>VISA</ssl_card_type>
        <ssl_card_number>************9990</ssl_card_number>
        <ssl_exp_date>1021</ssl_exp_date>
        <ssl_company>Widgets Inc</ssl_company>
        <ssl_customer_id></ssl_customer_id>
        <ssl_first_name>Longbob</ssl_first_name>
        <ssl_last_name>Longsen</ssl_last_name>
        <ssl_avs_address>456 My Street</ssl_avs_address>
        <ssl_address2>Apt 1</ssl_address2>
        <ssl_city>Ottawa</ssl_city>
        <ssl_state>ON</ssl_state>
        <ssl_avs_zip>K1C2N6</ssl_avs_zip>
        <ssl_country>CA</ssl_country>
        <ssl_phone>(555)555-5555</ssl_phone>
        <ssl_email>paul@domain.com</ssl_email>
        <ssl_description></ssl_description>
        <ssl_user_id>webpage</ssl_user_id>
        <ssl_token_response>SUCCESS</ssl_token_response>
        <ssl_result>0</ssl_result>
      </txn>
    XML
  end

  def failed_update_response
    <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <txn>
        <ssl_token>4421912014039990</ssl_token>
        <ssl_card_type>VISA</ssl_card_type>
        <ssl_card_number>************9990</ssl_card_number>
        <ssl_exp_date>1021</ssl_exp_date>
        <ssl_company>Widgets Inc</ssl_company>
        <ssl_customer_id></ssl_customer_id>
        <ssl_first_name>Longbob</ssl_first_name>
        <ssl_last_name>Longsen</ssl_last_name>
        <ssl_avs_address>456 My Street</ssl_avs_address>
        <ssl_address2>Apt 1</ssl_address2>
        <ssl_city>Ottawa</ssl_city>
        <ssl_state>ON</ssl_state>
        <ssl_avs_zip>K1C2N6</ssl_avs_zip>
        <ssl_country>CA</ssl_country>
        <ssl_phone>(555)555-5555</ssl_phone>
        <ssl_email>paul@domain.com</ssl_email>
        <ssl_description></ssl_description>
        <ssl_user_id>apiuser</ssl_user_id>
        <ssl_token_response>Failed</ssl_token_response>
        <ssl_result>1</ssl_result>
      </txn>
    XML
  end

  def pre_scrub
    %q{
opening connection to api.demo.convergepay.com:443...
opened
starting SSL for api.demo.convergepay.com:443...
SSL established
<- "POST /VirtualMerchantDemo/processxml.do HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept: application/xml\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: api.demo.convergepay.com\r\nContent-Length: 1026\r\n\r\n"
<- "xmldata=<txn>\n  <ssl_merchant_id>2020701</ssl_merchant_id>\n  <ssl_user_id>apiuser</ssl_user_id>\n  <ssl_pin>ULV2VQJXA5UR19KFXZ8TUWEFWMFY5MYXJVVOS8JN69EWV8XTN8Y0HYCR8B11DIUU</ssl_pin>\n  <ssl_transaction_type>CCSALE</ssl_transaction_type>\n  <ssl_amount>100</ssl_amount>\n  <ssl_card_number>4124939999999990</ssl_card_number>\n  <ssl_exp_date>0921</ssl_exp_date>\n  <ssl_cvv2cvc2>123</ssl_cvv2cvc2>\n  <ssl_cvv2cvc2_indicator>1</ssl_cvv2cvc2_indicator>\n  <ssl_first_name>Longbob</ssl_first_name>\n  <ssl_last_name>Longsen</ssl_last_name>\n  <ssl_invoice_number/>\n  <ssl_description>Test Transaction</ssl_description>\n  <ssl_avs_address>456 My Street</ssl_avs_address>\n  <ssl_address2>Apt 1</ssl_address2>\n  <ssl_avs_zip>K1C2N6</ssl_avs_zip>\n  <ssl_city>Ottawa</ssl_city>\n  <ssl_state>ON</ssl_state>\n  <ssl_company>Widgets Inc</ssl_company>\n  <ssl_phone>(555)555-5555</ssl_phone>\n  <ssl_country>CA</ssl_country>\n  <ssl_email>paul@domain.com</ssl_email>\n  <ssl_merchant_initiated_unscheduled>N</ssl_merchant_initiated_unscheduled>\n</txn>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Tue, 15 Sep 2020 23:09:31 GMT\r\n"
-> "Server: Apache\r\n"
-> "X-Frame-Options: SAMEORIGIN\r\n"
-> "Strict-Transport-Security: max-age=31536000; includeSubDomains; preload\r\n"
-> "Expires: 0\r\n"
-> "Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\r\n"
-> "AuthApproved: true\r\n"
-> "Pragma: no-cache\r\n"
-> "X-Frame-Options: SAMEORIGIN\r\n"
-> "Content-Security-Policy: frame-ancestors 'self'\r\n"
-> "Content-Disposition: inline; filename=response.xml\r\n"
-> "CPID: ED4-dff741a6-df1a-463c-920e-2e4842eda7bf\r\n"
-> "AuthResponse: AA\r\n"
-> "Content-Type: text/xml\r\n"
-> "Set-Cookie: JSESSIONID=UtM16S1VJSFsHChVlcYvM0cGVDWHMW1XD0vZ5T47.svplknxcnvrgdapp02; path=/VirtualMerchantDemo; secure; HttpOnly\r\n"
-> "Connection: close\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "\r\n"
-> "44b\r\n"
reading 1099 bytes...
-> "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<txn><ssl_issuer_response>00</ssl_issuer_response><ssl_transaction_type>SALE</ssl_transaction_type><ssl_card_number>41**********9990</ssl_card_number><ssl_departure_date></ssl_departure_date><ssl_oar_data>010012344309152309280000047554200000000000259849025923123443</ssl_oar_data><ssl_result>0</ssl_result><ssl_txn_id>150920ED4-48E1CA31-F2C5-411B-9543-AEA81EFB81B9</ssl_txn_id><ssl_avs_response>M</ssl_avs_response><ssl_approval_code>259849</ssl_approval_code><ssl_salestax></ssl_salestax><ssl_amount>100.00</ssl_amount><ssl_txn_time>09/15/2020 07:09:28 PM</ssl_txn_time><ssl_account_balance>0.00</ssl_account_balance><ssl_ps2000_data>A9151909286574590030VE</ssl_ps2000_data><ssl_exp_date>0921</ssl_exp_date><ssl_result_message>APPROVAL</ssl_result_message><ssl_card_short_description>VISA</ssl_card_short_description><ssl_completion_date></ssl_completion_date><ssl_eci_ind>3</ssl_eci_ind><ssl_card_type>CREDITCARD</ssl_card_type><ssl_invoice_number></ssl_invoice_number><ssl_cvv2_response>M</ssl_cvv2_response><ssl_partner_app_id>01</ssl_partner_app_id></txn>"
read 1099 bytes
reading 2 bytes...
-> "\r\n"
read 2 bytes
-> "0\r\n"
-> "\r\n"
Conn close
  }
  end

  def post_scrub
    %q{
opening connection to api.demo.convergepay.com:443...
opened
starting SSL for api.demo.convergepay.com:443...
SSL established
<- "POST /VirtualMerchantDemo/processxml.do HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept: application/xml\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: api.demo.convergepay.com\r\nContent-Length: 1026\r\n\r\n"
<- "xmldata=<txn>\n  <ssl_merchant_id>2020701</ssl_merchant_id>\n  <ssl_user_id>apiuser</ssl_user_id>\n  <ssl_pin>[FILTERED]</ssl_pin>\n  <ssl_transaction_type>CCSALE</ssl_transaction_type>\n  <ssl_amount>100</ssl_amount>\n  <ssl_card_number>[FILTERED]</ssl_card_number>\n  <ssl_exp_date>0921</ssl_exp_date>\n  <ssl_cvv2cvc2>[FILTERED]</ssl_cvv2cvc2>\n  <ssl_cvv2cvc2_indicator>1</ssl_cvv2cvc2_indicator>\n  <ssl_first_name>Longbob</ssl_first_name>\n  <ssl_last_name>Longsen</ssl_last_name>\n  <ssl_invoice_number/>\n  <ssl_description>Test Transaction</ssl_description>\n  <ssl_avs_address>456 My Street</ssl_avs_address>\n  <ssl_address2>Apt 1</ssl_address2>\n  <ssl_avs_zip>K1C2N6</ssl_avs_zip>\n  <ssl_city>Ottawa</ssl_city>\n  <ssl_state>ON</ssl_state>\n  <ssl_company>Widgets Inc</ssl_company>\n  <ssl_phone>(555)555-5555</ssl_phone>\n  <ssl_country>CA</ssl_country>\n  <ssl_email>paul@domain.com</ssl_email>\n  <ssl_merchant_initiated_unscheduled>N</ssl_merchant_initiated_unscheduled>\n</txn>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Tue, 15 Sep 2020 23:09:31 GMT\r\n"
-> "Server: Apache\r\n"
-> "X-Frame-Options: SAMEORIGIN\r\n"
-> "Strict-Transport-Security: max-age=31536000; includeSubDomains; preload\r\n"
-> "Expires: 0\r\n"
-> "Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\r\n"
-> "AuthApproved: true\r\n"
-> "Pragma: no-cache\r\n"
-> "X-Frame-Options: SAMEORIGIN\r\n"
-> "Content-Security-Policy: frame-ancestors 'self'\r\n"
-> "Content-Disposition: inline; filename=response.xml\r\n"
-> "CPID: ED4-dff741a6-df1a-463c-920e-2e4842eda7bf\r\n"
-> "AuthResponse: AA\r\n"
-> "Content-Type: text/xml\r\n"
-> "Set-Cookie: JSESSIONID=UtM16S1VJSFsHChVlcYvM0cGVDWHMW1XD0vZ5T47.svplknxcnvrgdapp02; path=/VirtualMerchantDemo; secure; HttpOnly\r\n"
-> "Connection: close\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "\r\n"
-> "44b\r\n"
reading 1099 bytes...
-> "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<txn><ssl_issuer_response>00</ssl_issuer_response><ssl_transaction_type>SALE</ssl_transaction_type><ssl_card_number>[FILTERED]</ssl_card_number><ssl_departure_date></ssl_departure_date><ssl_oar_data>010012344309152309280000047554200000000000259849025923123443</ssl_oar_data><ssl_result>0</ssl_result><ssl_txn_id>150920ED4-48E1CA31-F2C5-411B-9543-AEA81EFB81B9</ssl_txn_id><ssl_avs_response>M</ssl_avs_response><ssl_approval_code>259849</ssl_approval_code><ssl_salestax></ssl_salestax><ssl_amount>100.00</ssl_amount><ssl_txn_time>09/15/2020 07:09:28 PM</ssl_txn_time><ssl_account_balance>0.00</ssl_account_balance><ssl_ps2000_data>A9151909286574590030VE</ssl_ps2000_data><ssl_exp_date>0921</ssl_exp_date><ssl_result_message>APPROVAL</ssl_result_message><ssl_card_short_description>VISA</ssl_card_short_description><ssl_completion_date></ssl_completion_date><ssl_eci_ind>3</ssl_eci_ind><ssl_card_type>CREDITCARD</ssl_card_type><ssl_invoice_number></ssl_invoice_number><ssl_cvv2_response>M</ssl_cvv2_response><ssl_partner_app_id>01</ssl_partner_app_id></txn>"
read 1099 bytes
reading 2 bytes...
-> "\r\n"
read 2 bytes
-> "0\r\n"
-> "\r\n"
Conn close
  }
  end
end
