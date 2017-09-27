require 'test_helper'

class AuthorizeNetTest < Test::Unit::TestCase
  include CommStub

  BAD_TRACK_DATA = '%B378282246310005LONGSONLONGBOB1705101130504392?'
  TRACK1_DATA = '%B378282246310005^LONGSON/LONGBOB^1705101130504392?'
  TRACK2_DATA = ';4111111111111111=1803101000020000831?'

  def setup
    @gateway = AuthorizeNetGateway.new(
      login: 'X',
      password: 'Y'
    )

    @amount = 100
    @credit_card = credit_card
    @check = check
    @apple_pay_payment_token = ActiveMerchant::Billing::ApplePayPaymentToken.new(
      {data: 'encoded_payment_data'},
      payment_instrument_name: 'SomeBank Visa',
      payment_network: 'Visa',
      transaction_identifier: 'transaction123'
    )

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }

    @additional_options = {
      line_items: [
        {
          item_id: "1",
          name: "mug",
          description: "coffee",
          quantity: "100",
          unit_price: "10"
        },
        {
          item_id: "2",
          name: "vase",
          description: "floral",
          quantity: "200",
          unit_price: "20"
        }
      ]
    }
  end

  def test_add_swipe_data_with_bad_data
    @credit_card.track_data = BAD_TRACK_DATA
    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_nil doc.at_xpath('//track1')
        assert_nil doc.at_xpath('//track2')
        assert_equal "1.00", doc.at_xpath("//transactionRequest/amount").content
      end
    end.respond_with(successful_purchase_response)
  end

  def test_add_swipe_data_with_track_1
    @credit_card.track_data = TRACK1_DATA
    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal '%B378282246310005^LONGSON/LONGBOB^1705101130504392?', doc.at_xpath('//track1').content
        assert_nil doc.at_xpath('//track2')
        assert_equal "1.00", doc.at_xpath("//transactionRequest/amount").content
      end
    end.respond_with(successful_purchase_response)
  end

  def test_add_swipe_data_with_track_2
    @credit_card.track_data = TRACK2_DATA
    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_nil doc.at_xpath('//track1')
        assert_equal ';4111111111111111=1803101000020000831?', doc.at_xpath('//track2').content
        assert_equal "1.00", doc.at_xpath("//transactionRequest/amount").content
      end
    end.respond_with(successful_purchase_response)
  end

  def test_retail_market_type_device_type_included_in_swipe_transactions_with_valid_track_data
    [BAD_TRACK_DATA, nil].each do |track|
      @credit_card.track_data = track
      stub_comms do
        @gateway.purchase(@amount, @credit_card)
      end.check_request do |endpoint, data, headers|
        parse(data) do |doc|
          assert_nil doc.at_xpath('//retail')
        end
      end.respond_with(successful_purchase_response)
    end

    [TRACK1_DATA, TRACK2_DATA].each do |track|
      @credit_card.track_data = track
      stub_comms do
        @gateway.purchase(@amount, @credit_card)
      end.check_request do |endpoint, data, headers|
        parse(data) do |doc|
          assert_not_nil doc.at_xpath('//retail')
          assert_equal "2", doc.at_xpath('//retail/marketType').content
          assert_equal "7", doc.at_xpath('//retail/deviceType').content
        end
      end.respond_with(successful_purchase_response)
    end
  end

  def test_device_type_used_from_options_if_included_with_valid_track_data
    [TRACK1_DATA, TRACK2_DATA].each do |track|
      @credit_card.track_data = track
      stub_comms do
        @gateway.purchase(@amount, @credit_card, {device_type: 1})
      end.check_request do |endpoint, data, headers|
        parse(data) do |doc|
          assert_not_nil doc.at_xpath('//retail')
          assert_equal "2", doc.at_xpath('//retail/marketType').content
          assert_equal "1", doc.at_xpath('//retail/deviceType').content
        end
      end.respond_with(successful_purchase_response)
    end
  end

  def test_market_type_not_included_for_apple_pay_or_echeck
    [@check, @apple_pay_payment_token].each do |payment|
      stub_comms do
        @gateway.purchase(@amount, payment)
      end.check_request do |endpoint, data, headers|
        parse(data) do |doc|
          assert_nil doc.at_xpath('//retail')
        end
      end.respond_with(successful_purchase_response)
    end
  end

  def test_moto_market_type_included_when_card_is_entered_manually
    @credit_card.manual_entry = true
    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_not_nil doc.at_xpath('//retail')
        assert_equal "1", doc.at_xpath('//retail/marketType').content
      end
    end.respond_with(successful_purchase_response)
  end

  def test_market_type_can_be_specified
    stub_comms do
      @gateway.purchase(@amount, @credit_card, market_type: 0)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal "0", doc.at_xpath('//retail/marketType').content
      end
    end.respond_with(successful_purchase_response)
  end

  def test_successful_echeck_authorization
    response = stub_comms do
      @gateway.authorize(@amount, @check)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_not_nil doc.at_xpath("//payment/bankAccount")
        assert_equal "244183602", doc.at_xpath("//routingNumber").content
        assert_equal "15378535", doc.at_xpath("//accountNumber").content
        assert_equal "Bank of Elbonia", doc.at_xpath("//bankName").content
        assert_equal "Jim Smith", doc.at_xpath("//nameOnAccount").content
        assert_equal "1", doc.at_xpath("//checkNumber").content
        assert_equal "1.00", doc.at_xpath("//transactionRequest/amount").content
      end
    end.respond_with(successful_authorize_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '508141794', response.authorization.split('#')[0]
  end

  def test_successful_echeck_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @check)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_not_nil doc.at_xpath("//payment/bankAccount")
        assert_equal "244183602", doc.at_xpath("//routingNumber").content
        assert_equal "15378535", doc.at_xpath("//accountNumber").content
        assert_equal "Bank of Elbonia", doc.at_xpath("//bankName").content
        assert_equal "Jim Smith", doc.at_xpath("//nameOnAccount").content
        assert_equal "1", doc.at_xpath("//checkNumber").content
        assert_equal "1.00", doc.at_xpath("//transactionRequest/amount").content
      end
    end.respond_with(successful_purchase_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '508141795', response.authorization.split('#')[0]
  end

  def test_echeck_passing_recurring_flag
    response = stub_comms do
      @gateway.purchase(@amount, @check, recurring: true)
    end.check_request do |endpoint, data, headers|
      assert_equal settings_from_doc(parse(data))["recurringBilling"], "true"
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_failed_echeck_authorization
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @check)
    assert_failure response
  end

  def test_successful_apple_pay_authorization
    response = stub_comms do
      @gateway.authorize(@amount, @apple_pay_payment_token)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal @gateway.class::APPLE_PAY_DATA_DESCRIPTOR, doc.at_xpath("//opaqueData/dataDescriptor").content
        assert_equal Base64.strict_encode64(@apple_pay_payment_token.payment_data.to_json), doc.at_xpath("//opaqueData/dataValue").content
      end
    end.respond_with(successful_authorize_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '508141794', response.authorization.split('#')[0]
  end

  def test_successful_apple_pay_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @apple_pay_payment_token)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal @gateway.class::APPLE_PAY_DATA_DESCRIPTOR, doc.at_xpath("//opaqueData/dataDescriptor").content
        assert_equal Base64.strict_encode64(@apple_pay_payment_token.payment_data.to_json), doc.at_xpath("//opaqueData/dataValue").content
      end
    end.respond_with(successful_purchase_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '508141795', response.authorization.split('#')[0]
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card)
    assert_success response

    assert_equal 'M', response.cvv_result['code']
    assert_equal 'CVV matches', response.cvv_result['message']

    assert_equal '508141794', response.authorization.split('#')[0]
    assert response.test?
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_success response

    assert_equal '508141795', response.authorization.split('#')[0]
    assert response.test?
    assert_equal 'Y', response.avs_result['code']
    assert response.avs_result['street_match']
    assert response.avs_result['postal_match']
    assert_equal 'Street address and 5-digit postal code match.', response.avs_result['message']
    assert_equal 'P', response.cvv_result['code']
    assert_equal 'CVV not processed', response.cvv_result['message']
  end

  def test_successful_purchase_with_utf_character
    stub_comms do
      @gateway.purchase(@amount, credit_card('4000100011112224', last_name: 'Wåhlin'))
    end.check_request do |endpoint, data, headers|
      assert_match(/Wåhlin/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passes_partial_auth
    stub_comms do
      @gateway.purchase(@amount, credit_card, disable_partial_auth: true)
    end.check_request do |endpoint, data, headers|
      assert_match(/<settingName>allowPartialAuth<\/settingName>/, data)
      assert_match(/<settingValue>false<\/settingValue>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passes_email_customer
    stub_comms do
      @gateway.purchase(@amount, credit_card, email_customer: true)
    end.check_request do |endpoint, data, headers|
      assert_match(/<settingName>emailCustomer<\/settingName>/, data)
      assert_match(/<settingValue>true<\/settingValue>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passes_header_email_receipt
    stub_comms do
      @gateway.purchase(@amount, credit_card, header_email_receipt: "yet another field")
    end.check_request do |endpoint, data, headers|
      assert_match(/<settingName>headerEmailReceipt<\/settingName>/, data)
      assert_match(/<settingValue>yet another field<\/settingValue>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passes_line_items
    stub_comms do
      @gateway.purchase(@amount, credit_card, @options.merge(@additional_options))
    end.check_request do |endpoint, data, headers|
      assert_match(/<lineItems>/, data)
      assert_match(/<lineItem>/, data)
      assert_match(/<itemId>#{@additional_options[:line_items][0][:item_id]}<\/itemId>/, data)
      assert_match(/<name>#{@additional_options[:line_items][0][:name]}<\/name>/, data)
      assert_match(/<description>#{@additional_options[:line_items][0][:description]}<\/description>/, data)
      assert_match(/<quantity>#{@additional_options[:line_items][0][:quantity]}<\/quantity>/, data)
      assert_match(/<unitPrice>#{@additional_options[:line_items][0][:unit_price]}<\/unitPrice>/, data)
      assert_match(/<\/lineItem>/, data)
      assert_match(/<itemId>#{@additional_options[:line_items][1][:item_id]}<\/itemId>/, data)
      assert_match(/<name>#{@additional_options[:line_items][1][:name]}<\/name>/, data)
      assert_match(/<description>#{@additional_options[:line_items][1][:description]}<\/description>/, data)
      assert_match(/<quantity>#{@additional_options[:line_items][1][:quantity]}<\/quantity>/, data)
      assert_match(/<unitPrice>#{@additional_options[:line_items][1][:unit_price]}<\/unitPrice>/, data)
      assert_match(/<\/lineItems>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'incorrect_number', response.error_code
  end

  def test_live_gateway_cannot_use_test_mode_on_auth_dot_net_server
    test_gateway = AuthorizeNetGateway.new(
      login: 'X',
      password: 'Y',
      test: true
    )
    test_gateway.stubs(:ssl_post).returns(successful_purchase_response_test_mode)

    response = test_gateway.purchase(@amount, @credit_card)
    assert_success response

    real_gateway = AuthorizeNetGateway.new(
      login: 'X',
      password: 'Y',
      test: false
    )
    real_gateway.stubs(:ssl_post).returns(successful_purchase_response_test_mode)
    response = real_gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal "Using a live Authorize.net account in Test Mode is not permitted.", response.message
  end

  def test_successful_purchase_using_stored_card
    @gateway.expects(:ssl_post).returns(successful_store_response)
    store = @gateway.store(@credit_card, @options)
    assert_success store

    @gateway.expects(:ssl_post).returns(successful_purchase_using_stored_card_response)

    response = @gateway.purchase(@amount, store.authorization)
    assert_success response

    assert_equal '2235700270#XXXX2224#cim_purchase', response.authorization
    assert_equal 'Y', response.avs_result['code']
    assert response.avs_result['street_match']
    assert response.avs_result['postal_match']
    assert_equal 'Street address and 5-digit postal code match.', response.avs_result['message']
  end

  def test_failed_purchase_using_stored_card
    @gateway.expects(:ssl_post).returns(successful_store_response)
    store = @gateway.store(@credit_card, @options)
    assert_success store

    @gateway.expects(:ssl_post).returns(failed_purchase_using_stored_card_response)

    response = @gateway.purchase(@amount, store.authorization)
    assert_failure response
    assert_equal "The credit card number is invalid.", response.message
    assert_equal "6", response.params["response_reason_code"]
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'incorrect_number', response.error_code
  end

  def test_successful_authorize_and_capture_using_stored_card
    @gateway.expects(:ssl_post).returns(successful_store_response)
    store = @gateway.store(@credit_card, @options)

    @gateway.expects(:ssl_post).returns(successful_authorize_using_stored_card_response)
    auth = @gateway.authorize(@amount, store.authorization)
    assert_success auth
    assert_equal "This transaction has been approved.", auth.message

    @gateway.expects(:ssl_post).returns(successful_capture_using_stored_card_response)

    capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal "This transaction has been approved.", capture.message
  end

  def test_failed_authorize_using_stored_card
    @gateway.expects(:ssl_post).returns(successful_store_response)
    store = @gateway.store(@credit_card, @options)

    @gateway.expects(:ssl_post).returns(failed_authorize_using_stored_card_response)
    response = @gateway.authorize(@amount, store.authorization)
    assert_failure response
    assert_equal "The credit card number is invalid.", response.message
    assert_equal "6", response.params["response_reason_code"]
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    capture = @gateway.capture(@amount, '2214269051#XXXX1234', @options)
    assert_success capture
    assert_equal nil, capture.error_code
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    assert capture = @gateway.capture(@amount, '2214269051#XXXX1234')
    assert_failure capture
  end

  def test_failed_already_actioned_capture
    @gateway.expects(:ssl_post).returns(already_actioned_capture_response)

    response = @gateway.capture(50, '123456789')
    assert_instance_of Response, response
    assert_failure response
  end

  def test_failed_capture_using_stored_card
    @gateway.expects(:ssl_post).returns(successful_store_response)
    store = @gateway.store(@credit_card, @options)

    @gateway.expects(:ssl_post).returns(successful_authorize_using_stored_card_response)
    auth = @gateway.authorize(@amount, store.authorization)

    @gateway.expects(:ssl_post).returns(failed_capture_using_stored_card_response)
    capture = @gateway.capture(@amount, auth.authorization)
    assert_failure capture
    assert_match(/The amount requested for settlement cannot be greater/, capture.message)
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert void = @gateway.void('')
    assert_success void
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('')
    assert_failure response
  end

  def test_successful_void_using_stored_card
    @gateway.expects(:ssl_post).returns(successful_store_response)
    store = @gateway.store(@credit_card, @options)

    @gateway.expects(:ssl_post).returns(successful_authorize_using_stored_card_response)
    auth = @gateway.authorize(@amount, store.authorization)

    @gateway.expects(:ssl_post).returns(successful_void_using_stored_card_response)
    void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal "This transaction has been approved.", void.message
  end

  def test_failed_void_using_stored_card
    @gateway.expects(:ssl_post).returns(successful_store_response)
    store = @gateway.store(@credit_card, @options)

    @gateway.expects(:ssl_post).returns(failed_authorize_using_stored_card_response)
    auth = @gateway.authorize(@amount, store.authorization)

    @gateway.expects(:ssl_post).returns(failed_void_using_stored_card_response)
    void = @gateway.void(auth.authorization)
    assert_failure void
    assert_equal "This transaction has already been voided.", void.message
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorize_response, successful_void_response)
    assert_success response
  end

  def test_successful_verify_failed_void
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_match %r{This transaction has been approved}, response.message
  end

  def test_unsuccessful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
    assert_not_nil response.message
  end

  def test_failed_refund_using_stored_card
    @gateway.expects(:ssl_post).returns(successful_store_response)
    store = @gateway.store(@credit_card, @options)
    assert_success store

    @gateway.expects(:ssl_post).returns(successful_purchase_using_stored_card_response)

    purchase = @gateway.purchase(@amount, store.authorization)
    assert_success purchase

    @gateway.expects(:ssl_post).returns(failed_refund_using_stored_card_response)
    refund = @gateway.refund(@amount, purchase.authorization)
    assert_failure refund
    assert_equal "The record cannot be found", refund.message
  end

  def test_failed_refund_due_to_unsettled_payment
    @gateway.expects(:ssl_post).returns(failed_refund_for_unsettled_payment_response)
    @gateway.expects(:void).never

    @gateway.refund(36.40, '2214269051#XXXX1234')
  end

  def test_failed_full_refund_due_to_unsettled_payment_forces_void
    @gateway.expects(:ssl_post).returns(failed_refund_for_unsettled_payment_response)
    @gateway.expects(:void).once

    @gateway.refund(36.40, '2214269051#XXXX1234', force_full_refund_if_unsettled: true)
  end

  def test_failed_full_refund_returns_failed_response_if_reason_code_is_not_unsettled_error
    @gateway.expects(:ssl_post).returns(failed_refund_response)
    @gateway.expects(:void).never

    response = @gateway.refund(36.40, '2214269051#XXXX1234', force_full_refund_if_unsettled: true)
    assert response.present?
    assert_failure response
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    store = @gateway.store(@credit_card, @options)
    assert_success store
    assert_equal "Successful", store.message
    assert_equal "35959426", store.params["customer_profile_id"]
    assert_equal "32506918", store.params["customer_payment_profile_id"]
  end

  def test_failed_store
    @gateway.expects(:ssl_post).returns(failed_store_response)

    store = @gateway.store(@credit_card, @options)
    assert_failure store
    assert_match(/The field length is invalid/, store.message)
    assert_equal("15", store.params["message_code"])
  end

  def test_successful_unstore
    response = stub_comms do
      @gateway.unstore('35959426#32506918#cim_store')
    end.check_request do |endpoint, data, headers|
      doc = parse(data)
      assert_equal "35959426", doc.at_xpath("//deleteCustomerProfileRequest/customerProfileId").content
    end.respond_with(successful_unstore_response)

    assert_success response
    assert_equal "Successful", response.message
  end

  def test_failed_unstore
    @gateway.expects(:ssl_post).returns(failed_unstore_response)

    unstore = @gateway.unstore('35959426#32506918#cim_store')
    assert_failure unstore
    assert_match(/The record cannot be found/, unstore.message)
    assert_equal("40", unstore.params["message_code"])
  end

  def test_successful_store_new_payment_profile
    @gateway.expects(:ssl_post).returns(successful_store_new_payment_profile_response)

    store = @gateway.store(@credit_card, @options)
    assert_success store
    assert_equal "Successful", store.message
    assert_equal "38392170", store.params["customer_profile_id"]
    assert_equal "34896759", store.params["customer_payment_profile_id"]
  end

  def test_failed_store_new_payment_profile
    @gateway.expects(:ssl_post).returns(failed_store_new_payment_profile_response)

    store = @gateway.store(@credit_card, @options)
    assert_failure store
    assert_equal "A duplicate customer payment profile already exists", store.message
    assert_equal "38392767", store.params["customer_profile_id"]
    assert_equal "34897359", store.params["customer_payment_profile_id"]
  end

  def test_address
    stub_comms do
      @gateway.authorize(@amount, @credit_card, billing_address: {address1: '164 Waverley Street', country: 'US', state: 'CO', phone: '(555)555-5555', fax: '(555)555-4444'})
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal "CO", doc.at_xpath("//billTo/state").content, data
        assert_equal "164 Waverley Street", doc.at_xpath("//billTo/address").content, data
        assert_equal "US", doc.at_xpath("//billTo/country").content, data
        assert_equal "(555)555-5555", doc.at_xpath("//billTo/phoneNumber").content
        assert_equal "(555)555-4444", doc.at_xpath("//billTo/faxNumber").content
      end
    end.respond_with(successful_authorize_response)
  end

  def test_address_with_empty_billing_address
    stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal "", doc.at_xpath("//billTo/address").content, data
        assert_equal "", doc.at_xpath("//billTo/city").content, data
        assert_equal "n/a", doc.at_xpath("//billTo/state").content, data
        assert_equal "", doc.at_xpath("//billTo/zip").content, data
        assert_equal "", doc.at_xpath("//billTo/country").content, data
      end
    end.respond_with(successful_authorize_response)
  end

  def test_address_with_address2_present
    stub_comms do
      @gateway.authorize(@amount, @credit_card, billing_address: {address1: '164 Waverley Street', address2: 'Apt 1234', country: 'US', state: 'CO', phone: '(555)555-5555', fax: '(555)555-4444'})
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal "CO", doc.at_xpath("//billTo/state").content, data
        assert_equal "164 Waverley Street Apt 1234", doc.at_xpath("//billTo/address").content, data
        assert_equal "US", doc.at_xpath("//billTo/country").content, data
        assert_equal "(555)555-5555", doc.at_xpath("//billTo/phoneNumber").content
        assert_equal "(555)555-4444", doc.at_xpath("//billTo/faxNumber").content
      end
    end.respond_with(successful_authorize_response)
  end

  def test_address_north_america_with_defaults
    stub_comms do
      @gateway.authorize(@amount, @credit_card, billing_address: {address1: '164 Waverley Street', country: 'US'})
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal "NC", doc.at_xpath("//billTo/state").content, data
        assert_equal "164 Waverley Street", doc.at_xpath("//billTo/address").content, data
        assert_equal "US", doc.at_xpath("//billTo/country").content, data
      end
    end.respond_with(successful_authorize_response)
  end

  def test_address_outsite_north_america
    stub_comms do
      @gateway.authorize(@amount, @credit_card, billing_address: {address1: '164 Waverley Street', country: 'DE'})
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal "n/a", doc.at_xpath("//billTo/state").content, data
        assert_equal "164 Waverley Street", doc.at_xpath("//billTo/address").content, data
        assert_equal "DE", doc.at_xpath("//billTo/country").content, data
      end
    end.respond_with(successful_authorize_response)
  end

  def test_address_outsite_north_america_with_address2_present
    stub_comms do
      @gateway.authorize(@amount, @credit_card, billing_address: {address1: '164 Waverley Street', address2: 'Apt 1234', country: 'DE'})
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal "n/a", doc.at_xpath("//billTo/state").content, data
        assert_equal "164 Waverley Street Apt 1234", doc.at_xpath("//billTo/address").content, data
        assert_equal "DE", doc.at_xpath("//billTo/country").content, data
      end
    end.respond_with(successful_authorize_response)
  end

  def test_duplicate_window
    stub_comms do
      @gateway.purchase(@amount, @credit_card, duplicate_window: 0)
    end.check_request do |endpoint, data, headers|
      assert_equal settings_from_doc(parse(data))["duplicateWindow"], "0"
    end.respond_with(successful_purchase_response)
  end

  def test_duplicate_window_class_attribute_deprecated
    @gateway.class.duplicate_window = 0
    assert_deprecation_warning("Using the duplicate_window class_attribute is deprecated. Use the transaction options hash instead.") do
      stub_comms do
        @gateway.purchase(@amount, @credit_card)
      end.respond_with(successful_purchase_response)
    end
  ensure
    @gateway.class.duplicate_window = nil
  end

  def test_add_cardholder_authentication_value
    stub_comms do
      @gateway.purchase(@amount, @credit_card, cardholder_authentication_value: 'E0Mvq8AAABEiMwARIjNEVWZ3iJk=', authentication_indicator: "2")
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal "E0Mvq8AAABEiMwARIjNEVWZ3iJk=", doc.at_xpath("//cardholderAuthentication/cardholderAuthenticationValue").content
        assert_equal "2", doc.at_xpath("//cardholderAuthentication/authenticationIndicator").content
        assert_equal "1.00", doc.at_xpath("//transactionRequest/amount").content
      end
    end.respond_with(successful_purchase_response)
  end

  def test_capture_passing_extra_info
    response = stub_comms do
      @gateway.capture(50, '123456789', description: "Yo", order_id: "Sweetness")
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_not_nil doc.at_xpath("//order/description"), data
        assert_equal "Yo", doc.at_xpath("//order/description").content, data
        assert_equal "Sweetness", doc.at_xpath("//order/invoiceNumber").content, data
        assert_equal "0.50", doc.at_xpath("//transactionRequest/amount").content
      end
    end.respond_with(successful_capture_response)
    assert_success response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert refund = @gateway.refund(36.40, '2214269051#XXXX1234')
    assert_success refund
    assert_equal 'This transaction has been approved', refund.message
    assert_equal '2214602071#2224#refund', refund.authorization
  end

  def test_refund_passing_extra_info
    response = stub_comms do
      @gateway.refund(50, '123456789', card_number: @credit_card.number, first_name: "Bob", last_name: "Smith", zip: "12345", order_id: "1", description: "Refund for order 1")
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal "Bob", doc.at_xpath("//billTo/firstName").content, data
        assert_equal "Smith", doc.at_xpath("//billTo/lastName").content, data
        assert_equal "12345", doc.at_xpath("//billTo/zip").content, data
        assert_equal "0.50", doc.at_xpath("//transactionRequest/amount").content
        assert_equal "1", doc.at_xpath("//transactionRequest/order/invoiceNumber").content
        assert_equal "Refund for order 1", doc.at_xpath("//transactionRequest/order/description").content
      end
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    refund = @gateway.refund(nil, '')
    assert_failure refund
    assert_equal 'The sum of credits against the referenced transaction would exceed original debit amount', refund.message
    assert_equal '0#2224#refund', refund.authorization
  end

  def test_successful_credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)

    response = @gateway.credit(@amount, @credit_card)
    assert_success response

    assert_equal '2230004436', response.authorization.split('#')[0]
    assert_equal "This transaction has been approved", response.message
  end

  def test_failed_credit
    @gateway.expects(:ssl_post).returns(failed_credit_response)

    response = @gateway.credit(@amount, @credit_card)
    assert_failure response
    assert_equal "The credit card number is invalid", response.message
  end

  def test_supported_countries
    assert_equal 4, (['US', 'CA', 'AU', 'VA'] & AuthorizeNetGateway.supported_countries).size
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover, :diners_club, :jcb, :maestro], AuthorizeNetGateway.supported_cardtypes
  end

  def test_failure_without_response_reason_text
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(no_message_response)
    assert_equal "", response.message
  end

  def test_response_under_review_by_fraud_service
    @gateway.expects(:ssl_post).returns(fraud_review_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert response.fraud_review?
    assert_equal "Thank you! For security reasons your order is currently being reviewed", response.message
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(fraud_review_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'X', response.avs_result['code']
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'Y', response.avs_result['postal_match']


    @gateway.expects(:ssl_post).returns(address_not_provided_avs_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'I', response.avs_result['code']
    assert_equal nil, response.avs_result['street_match']
    assert_equal nil, response.avs_result['postal_match']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(fraud_review_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'M', response.cvv_result['code']
  end

  def test_message
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(no_match_cvv_response)
    assert_equal "CVV does not match", response.message

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(no_match_avs_response)
    assert_equal "Street address matches, but 5-digit and 9-digit postal code do not match.", response.message

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)
    assert_equal "The credit card number is invalid", response.message
  end

  def test_solution_id_is_added_to_post_data_parameters
    @gateway.class.application_id = 'A1000000'
    stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      doc = parse(data)
      assert_equal "A1000000", fields_from_doc(doc)["x_solution_id"], data
      assert_equal "1.00", doc.at_xpath("//transactionRequest/amount").content
    end.respond_with(successful_authorize_response)
  ensure
    @gateway.class.application_id = nil
  end

  def test_alternate_currency
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, currency: "GBP")
    assert_success response
  end

  def assert_no_has_customer_id(data)
    assert_no_match %r{x_cust_id}, data
  end

  def test_include_cust_id_for_numeric_values
   stub_comms do
      @gateway.purchase(@amount, @credit_card, customer: "123")
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_not_nil doc.at_xpath("//customer/id"), data
        assert_equal "123", doc.at_xpath("//customer/id").content, data
        assert_equal "1.00", doc.at_xpath("//transactionRequest/amount").content
      end
    end.respond_with(successful_authorize_response)
  end

  def test_include_cust_id_for_word_character_values
   stub_comms do
      @gateway.purchase(@amount, @credit_card, customer: "4840_TT")
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_not_nil doc.at_xpath("//customer/id"), data
        assert_equal "4840_TT", doc.at_xpath("//customer/id").content, data
        assert_equal "1.00", doc.at_xpath("//transactionRequest/amount").content
      end
    end.respond_with(successful_authorize_response)
  end

  def test_dont_include_cust_id_for_email_addresses
   stub_comms do
      @gateway.purchase(@amount, @credit_card, customer: "bob@test.com")
    end.check_request do |endpoint, data, headers|
      doc = parse(data)
      assert !doc.at_xpath("//customer/id"), data
      assert_equal "1.00", doc.at_xpath("//transactionRequest/amount").content
    end.respond_with(successful_authorize_response)
  end

  def test_dont_include_cust_id_for_phone_numbers
   stub_comms do
      @gateway.purchase(@amount, @credit_card, customer: "111-123-1231")
    end.check_request do |endpoint, data, headers|
      doc = parse(data)
      assert !doc.at_xpath("//customer/id"), data
      assert_equal "1.00", doc.at_xpath("//transactionRequest/amount").content
    end.respond_with(successful_authorize_response)
  end

  def test_includes_shipping_name_when_different_from_billing_name
    card = credit_card('4242424242424242',
      first_name: "billing",
      last_name: "name")

    options = {
      order_id: "a" * 21,
      billing_address: address(name: "billing name"),
      shipping_address: address(name: "shipping lastname")
    }

    stub_comms do
      @gateway.purchase(@amount, card, options)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal "billing", doc.at_xpath("//billTo/firstName").text
        assert_equal "name", doc.at_xpath("//billTo/lastName").text
        assert_equal "shipping", doc.at_xpath("//shipTo/firstName").text
        assert_equal "lastname", doc.at_xpath("//shipTo/lastName").text
      end
    end.respond_with(successful_purchase_response)
  end

  def test_includes_shipping_name_when_passed_as_options
    card = credit_card('4242424242424242',
      first_name: "billing",
      last_name: "name")

    shipping_address = address(first_name: "shipping", last_name: "lastname")
    shipping_address.delete(:name)
    options = {
      order_id: "a" * 21,
      billing_address: address(name: "billing name"),
      shipping_address: shipping_address
    }

    stub_comms do
      @gateway.purchase(@amount, card, options)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal "billing", doc.at_xpath("//billTo/firstName").text
        assert_equal "name", doc.at_xpath("//billTo/lastName").text
        assert_equal "shipping", doc.at_xpath("//shipTo/firstName").text
        assert_equal "lastname", doc.at_xpath("//shipTo/lastName").text
      end
    end.respond_with(successful_purchase_response)
  end

  def test_truncation
    card = credit_card('4242424242424242',
      first_name: "a" * 51,
      last_name: "a" * 51,
    )

    options = {
      order_id: "a" * 21,
      description: "a" * 256,
      billing_address: address(
        company: "a" * 51,
        address1: "a" * 61,
        city: "a" * 41,
        state: "a" * 41,
        zip: "a" * 21,
        country: "a" * 61,
      ),
      shipping_address: address(
        name: ["a" * 51, "a" * 51].join(" "),
        company: "a" * 51,
        address1: "a" * 61,
        city: "a" * 41,
        state: "a" * 41,
        zip: "a" * 21,
        country: "a" * 61,
      )
    }

    stub_comms do
      @gateway.purchase(@amount, card, options)
    end.check_request do |endpoint, data, headers|
      assert_truncated(data, 20, "//refId")
      assert_truncated(data, 255, "//description")
      assert_address_truncated(data, 50, "firstName")
      assert_address_truncated(data, 50, "lastName")
      assert_address_truncated(data, 50, "company")
      assert_address_truncated(data, 60, "address")
      assert_address_truncated(data, 40, "city")
      assert_address_truncated(data, 40, "state")
      assert_address_truncated(data, 20, "zip")
      assert_address_truncated(data, 60, "country")
    end.respond_with(successful_purchase_response)
  end

  def test_invalid_cvv
    invalid_cvvs = ['47', '12345', '']
    invalid_cvvs.each do |cvv|
      card = credit_card(@credit_card.number, { verification_value: cvv })
      stub_comms do
        @gateway.purchase(@amount, card)
      end.check_request do |endpoint, data, headers|
        parse(data) { |doc| assert_nil doc.at_xpath('//cardCode') }
      end.respond_with(successful_purchase_response)
    end
  end

  def test_card_number_truncation
    card = credit_card(@credit_card.number + '0123456789')
    stub_comms do
      @gateway.purchase(@amount, card)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal @credit_card.number, doc.at_xpath('//cardNumber').text
      end
    end.respond_with(successful_purchase_response)
  end

  def test_scrub
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_supports_scrubbing?
    assert @gateway.supports_scrubbing?
  end

  def test_successful_apple_pay_authorization_with_network_tokenization
    credit_card = network_tokenization_credit_card('4242424242424242',
      :payment_cryptogram => "111111111100cryptogram"
    )

    response = stub_comms do
      @gateway.authorize(@amount, credit_card)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal credit_card.payment_cryptogram, doc.at_xpath("//creditCard/cryptogram").content
        assert_equal credit_card.number, doc.at_xpath("//creditCard/cardNumber").content
      end
    end.respond_with(successful_authorize_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '508141794', response.authorization.split('#')[0]
  end

  def test_failed_apple_pay_authorization_with_network_tokenization_not_supported
    credit_card = network_tokenization_credit_card('4242424242424242',
      :payment_cryptogram => "111111111100cryptogram"
    )

    response = stub_comms do
      @gateway.authorize(@amount, credit_card)
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal credit_card.payment_cryptogram, doc.at_xpath("//creditCard/cryptogram").content
        assert_equal credit_card.number, doc.at_xpath("//creditCard/cardNumber").content
      end
    end.respond_with(network_tokenization_not_supported_response)

    assert_equal Gateway::STANDARD_ERROR_CODE[:unsupported_feature], response.error_code
  end

  def test_supports_network_tokenization_true
    response = stub_comms do
      @gateway.supports_network_tokenization?
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal "authOnlyTransaction", doc.at_xpath("//transactionType").content
        assert_equal "0.01", doc.at_xpath("//amount").content
        assert_equal "EHuWW9PiBkWvqE5juRwDzAUFBAk=", doc.at_xpath("//creditCard/cryptogram").content
        assert_equal "4111111111111111", doc.at_xpath("//creditCard/cardNumber").content
      end
    end.respond_with(successful_authorize_response)

    assert_instance_of TrueClass, response
  end

  def test_supports_network_tokenization_false
    response = stub_comms do
      @gateway.supports_network_tokenization?
    end.check_request do |endpoint, data, headers|
      parse(data) do |doc|
        assert_equal "authOnlyTransaction", doc.at_xpath("//transactionType").content
        assert_equal "0.01", doc.at_xpath("//amount").content
        assert_equal "EHuWW9PiBkWvqE5juRwDzAUFBAk=", doc.at_xpath("//creditCard/cryptogram").content
        assert_equal "4111111111111111", doc.at_xpath("//creditCard/cardNumber").content
      end
    end.respond_with(network_tokenization_not_supported_response)

    assert_instance_of FalseClass, response
  end

  def test_verify_good_credentials
    @gateway.expects(:ssl_post).returns(credentials_are_legit_response)
    assert @gateway.verify_credentials
  end

  def test_verify_bad_credentials
    @gateway.expects(:ssl_post).returns(credentials_are_bogus_response)
    assert !@gateway.verify_credentials
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to apitest.authorize.net:443...
      opened
      starting SSL for apitest.authorize.net:443...
      SSL established
      <- "POST /xml/v1/request.api HTTP/1.1\r\nContent-Type: text/xml\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: apitest.authorize.net\r\nContent-Length: 1306\r\n\r\n"
      <- "<?xml version=\"1.0\"?>\n<createTransactionRequest xmlns=\"AnetApi/xml/v1/schema/AnetApiSchema.xsd\">\n<merchantAuthentication>\n<name>5KP3u95bQpv</name>\n<transactionKey>4Ktq966gC55GAX7S</transactionKey>\n</merchantAuthentication>\n<refId>1</refId>\n<transactionRequest>\n<transactionType>authCaptureTransaction</transactionType>\n<amount>1.00</amount>\n<payment>\n<creditCard>\n<cardNumber>4000100011112224</cardNumber>\n<expirationDate>09/2016</expirationDate>\n<cardCode>123</cardCode>\n<cryptogram>EHuWW9PiBkWvqE5juRwDzAUFBAk=</cryptogram>\n</creditCard>\n</payment>\n<order>\n<invoiceNumber>1</invoiceNumber>\n<description>Store Purchase</description>\n</order>\n<customer/>\n<billTo>\n<firstName>Longbob</firstName>\n<lastName>Longsen</lastName>\n<company>Widgets Inc</company>\n<address>1234 My Street</address>\n<city>Ottawa</city>\n<state>ON</state>\n<zip>K1C2N6</zip>\n<country>CA</country>\n<phoneNumber>(555)555-5555</phoneNumber>\n<faxNumber>(555)555-6666</faxNumber>\n</billTo>\n<cardholderAuthentication>\n<authenticationIndicator/>\n<cardholderAuthenticationValue/>\n</cardholderAuthentication>\n<transactionSettings>\n<setting>\n<settingName>duplicateWindow</settingName>\n<settingValue>0</settingValue>\n</setting>\n</transactionSettings>\n<userFields>\n<userField>\n<name>x_currency_code</name>\n<value>USD</value>\n</userField>\n</userFields>\n<trackData>\n<track1>123456</track1>\n<track2>78910</track2></trackData>\n</transactionRequest>\n</createTransactionRequest>\n"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Cache-Control: private\r\n"
      -> "Content-Length: 973\r\n"
      -> "Content-Type: application/xml; charset=utf-8\r\n"
      -> "Server: Microsoft-IIS/7.5\r\n"
      -> "X-AspNet-Version: 2.0.50727\r\n"
      -> "X-Powered-By: ASP.NET\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Methods: GET,POST,OPTIONS\r\n"
      -> "Access-Control-Allow-Headers: x-requested-with,cache-control,content-type,origin,method\r\n"
      -> "Date: Mon, 26 Jan 2015 16:29:30 GMT\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 973 bytes...
      -> "\xEF\xBB\xBF<?xml version=\"1.0\" encoding=\"utf-8\"?><createTransactionResponse xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns=\"AnetApi/xml/v1/schema/AnetApiSchema.xsd\"><refId>1</refId><messages><resultCode>Ok</resultCode><message><code>I00001</code><text>Successful.</text></message></messages><transactionResponse><responseCode>1</responseCode><authCode>H6K4BU</authCode><avsResultCode>Y</avsResultCode><cvvResultCode>P</cvvResultCode><cavvResultCode>2</cavvResultCode><transId>2227534280</transId><refTransID /><transHash>FE7A5BA8F209227CE1EC4B07C4A1BB81</transHash><testRequest>0</testRequest><accountNumber>XXXX2224</accountNumber><accountType>Visa</accountType><messages><message><code>1</code><description>This transaction has been approved.</description></message></messages><userFields><userField><name>x_currency_code</name><value>USD</value></userField></userFields></transactionResponse></createTransactionResponse>"
      read 973 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-PRE_SCRUBBED
      opening connection to apitest.authorize.net:443...
      opened
      starting SSL for apitest.authorize.net:443...
      SSL established
      <- "POST /xml/v1/request.api HTTP/1.1\r\nContent-Type: text/xml\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: apitest.authorize.net\r\nContent-Length: 1306\r\n\r\n"
      <- "<?xml version=\"1.0\"?>\n<createTransactionRequest xmlns=\"AnetApi/xml/v1/schema/AnetApiSchema.xsd\">\n<merchantAuthentication>\n<name>5KP3u95bQpv</name>\n<transactionKey>[FILTERED]</transactionKey>\n</merchantAuthentication>\n<refId>1</refId>\n<transactionRequest>\n<transactionType>authCaptureTransaction</transactionType>\n<amount>1.00</amount>\n<payment>\n<creditCard>\n<cardNumber>[FILTERED]</cardNumber>\n<expirationDate>09/2016</expirationDate>\n<cardCode>[FILTERED]</cardCode>\n<cryptogram>[FILTERED]</cryptogram>\n</creditCard>\n</payment>\n<order>\n<invoiceNumber>1</invoiceNumber>\n<description>Store Purchase</description>\n</order>\n<customer/>\n<billTo>\n<firstName>Longbob</firstName>\n<lastName>Longsen</lastName>\n<company>Widgets Inc</company>\n<address>1234 My Street</address>\n<city>Ottawa</city>\n<state>ON</state>\n<zip>K1C2N6</zip>\n<country>CA</country>\n<phoneNumber>(555)555-5555</phoneNumber>\n<faxNumber>(555)555-6666</faxNumber>\n</billTo>\n<cardholderAuthentication>\n<authenticationIndicator/>\n<cardholderAuthenticationValue/>\n</cardholderAuthentication>\n<transactionSettings>\n<setting>\n<settingName>duplicateWindow</settingName>\n<settingValue>0</settingValue>\n</setting>\n</transactionSettings>\n<userFields>\n<userField>\n<name>x_currency_code</name>\n<value>USD</value>\n</userField>\n</userFields>\n<trackData>\n<track1>[FILTERED]</track1>\n<track2>[FILTERED]</track2></trackData>\n</transactionRequest>\n</createTransactionRequest>\n"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Cache-Control: private\r\n"
      -> "Content-Length: 973\r\n"
      -> "Content-Type: application/xml; charset=utf-8\r\n"
      -> "Server: Microsoft-IIS/7.5\r\n"
      -> "X-AspNet-Version: 2.0.50727\r\n"
      -> "X-Powered-By: ASP.NET\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Methods: GET,POST,OPTIONS\r\n"
      -> "Access-Control-Allow-Headers: x-requested-with,cache-control,content-type,origin,method\r\n"
      -> "Date: Mon, 26 Jan 2015 16:29:30 GMT\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 973 bytes...
      -> "\xEF\xBB\xBF<?xml version=\"1.0\" encoding=\"utf-8\"?><createTransactionResponse xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns=\"AnetApi/xml/v1/schema/AnetApiSchema.xsd\"><refId>1</refId><messages><resultCode>Ok</resultCode><message><code>I00001</code><text>Successful.</text></message></messages><transactionResponse><responseCode>1</responseCode><authCode>H6K4BU</authCode><avsResultCode>Y</avsResultCode><cvvResultCode>P</cvvResultCode><cavvResultCode>2</cavvResultCode><transId>2227534280</transId><refTransID /><transHash>FE7A5BA8F209227CE1EC4B07C4A1BB81</transHash><testRequest>0</testRequest><accountNumber>[FILTERED]</accountNumber><accountType>Visa</accountType><messages><message><code>1</code><description>This transaction has been approved.</description></message></messages><userFields><userField><name>x_currency_code</name><value>USD</value></userField></userFields></transactionResponse></createTransactionResponse>"
      read 973 bytes
      Conn close
    PRE_SCRUBBED
  end

  def parse(data)
    Nokogiri::XML(data).tap do |doc|
      doc.remove_namespaces!
      yield(doc) if block_given?
    end
  end

  def fields_from_doc(doc)
    assert_not_nil doc.at_xpath("//userFields/userField/name")
    doc.xpath("//userFields/userField").inject({}) do |hash, element|
      hash[element.at_xpath("name").content] = element.at_xpath("value").content
      hash
    end
  end

  def settings_from_doc(doc)
    assert_not_nil doc.at_xpath("//transactionSettings/setting/settingName")
    doc.xpath("//transactionSettings/setting").inject({}) do |hash, element|
      hash[element.at_xpath("settingName").content] = element.at_xpath("settingValue").content
      hash
    end
  end

  def assert_truncated(data, expected_size, field)
    assert_equal ("a" * expected_size), parse(data).at_xpath(field).text, data
  end

  def assert_address_truncated(data, expected_size, field)
    assert_truncated(data, expected_size, "//billTo/#{field}")
    assert_truncated(data, expected_size, "//shipTo/#{field}")
  end

  def successful_purchase_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"
      xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
      <refId>1</refId>
      <messages>
        <resultCode>Ok</resultCode>
          <message>
          <code>I00001</code>
          <text>Successful.</text>
          </message>
      </messages>
      <transactionResponse>
        <responseCode>1</responseCode>
        <authCode>GSOFTZ</authCode>
        <avsResultCode>Y</avsResultCode>
        <cvvResultCode>P</cvvResultCode>
        <cavvResultCode>2</cavvResultCode>
        <transId>508141795</transId>
          <refTransID/>
          <transHash>655D049EE60E1766C9C28EB47CFAA389</transHash>
        <testRequest>0</testRequest>
        <accountNumber>XXXX2224</accountNumber>
        <accountType>Visa</accountType>
        <messages>
          <message>
            <code>1</code>
            <description>This transaction has been approved.</description>
          </message>
        </messages>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def fraud_review_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"
      xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
      <refId>1</refId>
      <messages>
        <resultCode>Ok</resultCode>
          <message>
          <code>I00001</code>
          <text>Successful.</text>
          </message>
      </messages>
      <transactionResponse>
        <responseCode>4</responseCode>
        <authCode>GSOFTZ</authCode>
        <avsResultCode>X</avsResultCode>
        <cvvResultCode>M</cvvResultCode>
        <cavvResultCode>2</cavvResultCode>
        <transId>508141795</transId>
          <refTransID/>
          <transHash>655D049EE60E1766C9C28EB47CFAA389</transHash>
        <testRequest>0</testRequest>
        <accountNumber>XXXX2224</accountNumber>
        <accountType>Visa</accountType>
        <messages>
          <message>
            <code>1</code>
            <description>Thank you! For security reasons your order is currently being reviewed</description>
          </message>
        </messages>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def address_not_provided_avs_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"
      xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
      <refId>1</refId>
      <messages>
        <resultCode>Ok</resultCode>
          <message>
          <code>I00001</code>
          <text>Successful.</text>
          </message>
      </messages>
      <transactionResponse>
        <responseCode>4</responseCode>
        <authCode>GSOFTZ</authCode>
        <avsResultCode>B</avsResultCode>
        <cvvResultCode>M</cvvResultCode>
        <cavvResultCode>2</cavvResultCode>
        <transId>508141795</transId>
          <refTransID/>
          <transHash>655D049EE60E1766C9C28EB47CFAA389</transHash>
        <testRequest>0</testRequest>
        <accountNumber>XXXX2224</accountNumber>
        <accountType>Visa</accountType>
        <messages>
          <message>
            <code>1</code>
            <description>Thank you! For security reasons your order is currently being reviewed</description>
          </message>
        </messages>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def no_match_cvv_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"
      xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
      <refId>1</refId>
      <messages>
        <resultCode>Error</resultCode>
          <message>
          <code>E00027</code>
          <text>The transaction was unsuccessful.</text>
          </message>
      </messages>
      <transactionResponse>
        <responseCode>2</responseCode>
        <authCode>GSOFTZ</authCode>
        <avsResultCode>A</avsResultCode>
        <cvvResultCode>N</cvvResultCode>
        <cavvResultCode>2</cavvResultCode>
        <transId>508141795</transId>
          <refTransID/>
          <transHash>655D049EE60E1766C9C28EB47CFAA389</transHash>
        <testRequest>0</testRequest>
        <accountNumber>XXXX2224</accountNumber>
        <accountType>Visa</accountType>
        <messages>
          <message>
            <code>1</code>
            <description>Thank you! For security reasons your order is currently being reviewed</description>
          </message>
        </messages>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def no_match_avs_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"
      xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
      <refId>1</refId>
      <messages>
        <resultCode>Error</resultCode>
          <message>
          <code>E00027</code>
          <text>The transaction was unsuccessful.</text>
          </message>
      </messages>
      <transactionResponse>
        <responseCode>2</responseCode>
        <authCode>GSOFTZ</authCode>
        <avsResultCode>A</avsResultCode>
        <cvvResultCode>M</cvvResultCode>
        <cavvResultCode>2</cavvResultCode>
        <transId>508141795</transId>
          <refTransID/>
          <transHash>655D049EE60E1766C9C28EB47CFAA389</transHash>
        <testRequest>0</testRequest>
        <accountNumber>XXXX2224</accountNumber>
        <accountType>Visa</accountType>
        <errors>
          <error>
            <errorCode>27</errorCode>
            <errorText>The transaction cannot be found.</errorText>
          </error>
        </errors>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def failed_purchase_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>1234567</refId>
        <messages>
          <resultCode>Error</resultCode>
          <message>
            <code>E00027</code>
            <text>The transaction was unsuccessful.</text>
          </message>
        </messages>
        <transactionResponse>
          <responseCode>3</responseCode>
          <authCode/>
          <avsResultCode>P</avsResultCode>
          <cvvResultCode/>
          <cavvResultCode/>
          <transId>0</transId>
          <refTransID/>
          <transHash>7F9A0CB845632DCA5833D2F30ED02677</transHash>
          <testRequest>0</testRequest>
          <accountNumber>XXXX0001</accountNumber>
          <accountType/>
          <errors>
            <error>
              <errorCode>6</errorCode>
              <errorText>The credit card number is invalid.</errorText>
            </error>
          </errors>
          <userFields>
            <userField>
              <name>MerchantDefinedFieldName1</name>
              <value>MerchantDefinedFieldValue1</value>
            </userField>
            <userField>
              <name>favorite_color</name>
              <value>blue</value>
            </userField>
          </userFields>
        </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def no_message_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>1234567</refId>
        <messages>
          <resultCode>Error</resultCode>
        </messages>
        <transactionResponse>
          <responseCode>3</responseCode>
          <authCode/>
          <avsResultCode>P</avsResultCode>
          <cvvResultCode/>
          <cavvResultCode/>
          <transId>0</transId>
          <refTransID/>
          <transHash>7F9A0CB845632DCA5833D2F30ED02677</transHash>
          <testRequest>0</testRequest>
          <accountNumber>XXXX0001</accountNumber>
          <accountType/>
          <userFields>
            <userField>
              <name>MerchantDefinedFieldName1</name>
              <value>MerchantDefinedFieldValue1</value>
            </userField>
            <userField>
              <name>favorite_color</name>
              <value>blue</value>
            </userField>
          </userFields>
        </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def successful_purchase_response_test_mode
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"
      xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
      <refId>1</refId>
      <messages>
        <resultCode>Ok</resultCode>
          <message>
          <code>I00001</code>
          <text>Successful.</text>
          </message>
      </messages>
      <transactionResponse>
        <responseCode>1</responseCode>
        <authCode>GSOFTZ</authCode>
        <avsResultCode>Y</avsResultCode>
        <cvvResultCode>P</cvvResultCode>
        <cavvResultCode>2</cavvResultCode>
        <transId>508141795</transId>
          <refTransID/>
          <transHash>655D049EE60E1766C9C28EB47CFAA389</transHash>
        <testRequest>1</testRequest>
        <accountNumber>XXXX2224</accountNumber>
        <accountType>Visa</accountType>
        <messages>
          <message>
            <code>1</code>
            <description>This transaction has been approved.</description>
          </message>
        </messages>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def successful_authorize_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                                 xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>123456</refId>
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <transactionResponse>
          <responseCode>1</responseCode>
          <authCode>A88MS0</authCode>
          <avsResultCode>Y</avsResultCode>
          <cvvResultCode>M</cvvResultCode>
          <cavvResultCode>2</cavvResultCode>
          <transId>508141794</transId>
          <refTransID/>
          <transHash>D0EFF3F32E5ABD14A7CE6ADF32736D57</transHash>
          <testRequest>0</testRequest>
          <accountNumber>XXXX0015</accountNumber>
          <accountType>MasterCard</accountType>
          <messages>
            <message>
              <code>1</code>
              <description>This transaction has been approved.</description>
            </message>
          </messages>
          <userFields>
            <userField>
              <name>MerchantDefinedFieldName1</name>
              <value>MerchantDefinedFieldValue1</value>
            </userField>
            <userField>
              <name>favorite_color</name>
              <value>blue</value>
            </userField>
          </userFields>
        </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def failed_authorize_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                                 xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>123456</refId>
        <messages>
          <resultCode>Error</resultCode>
          <message>
            <code>E00027</code>
            <text>The transaction was unsuccessful.</text>
          </message>
        </messages>
        <transactionResponse>
          <responseCode>3</responseCode>
          <authCode/>
          <avsResultCode>P</avsResultCode>
          <cvvResultCode/>
          <cavvResultCode/>
          <transId>0</transId>
          <refTransID/>
          <transHash>DA56E64108957174C5AE9BE466914741</transHash>
          <testRequest>0</testRequest>
          <accountNumber>XXXX0001</accountNumber>
          <accountType/>
          <errors>
            <error>
              <errorCode>6</errorCode>
              <errorText>The credit card number is invalid.</errorText>
            </error>
          </errors>
          <userFields>
            <userField>
              <name>MerchantDefinedFieldName1</name>
              <value>MerchantDefinedFieldValue1</value>
            </userField>
            <userField>
              <name>favorite_color</name>
              <value>blue</value>
            </userField>
          </userFields>
        </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def successful_capture_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema xmlns=AnetApi/xml/v1/schema/AnetApiSchema.xsd">
      <refId/>
      <messages>
        <resultCode>Ok</resultCode>
        <message>
          <code>I00001</code>
          <text>Successful.</text>
        </message>
      </messages>
      <transactionResponse>
      <responseCode>1</responseCode>
      <authCode>UTDVHP</authCode>
      <avsResultCode>P</avsResultCode>
      <cvvResultCode/>
      <cavvResultCode/>
      <transId>2214675515</transId>
      <refTransID>2214675515</refTransID>
      <transHash>6D739029E129D87F6CEFE3B3864F6D61</transHash>
      <testRequest>0</testRequest>
      <accountNumber>XXXX2224</accountNumber>
      <accountType>Visa</accountType>
      <messages>
        <message>
          <code>1</code>
          <description>This transaction has been approved.</description>
        </message>
      </messages>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def already_actioned_capture_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema xmlns=AnetApi/xml/v1/schema/AnetApiSchema.xsd">
      <refId/>
      <messages>
        <resultCode>Ok</resultCode>
        <message>
          <code>I00001</code>
          <text>This transaction has already been captured.</text>
        </message>
      </messages>
      <transactionResponse>
      <responseCode>1</responseCode>
      <authCode>UTDVHP</authCode>
      <avsResultCode>P</avsResultCode>
      <cvvResultCode/>
      <cavvResultCode/>
      <transId>2214675515</transId>
      <refTransID>2214675515</refTransID>
      <transHash>6D739029E129D87F6CEFE3B3864F6D61</transHash>
      <testRequest>0</testRequest>
      <accountNumber>XXXX2224</accountNumber>
      <accountType>Visa</accountType>
      <messages>
        <message>
          <code>311</code>
          <description>This transaction has already been captured.</description>
        </message>
      </messages>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def failed_capture_response
    <<-eos
      <createTransactionResponse xmlns:xsi=
                                 http://www.w3.org/2001/XMLSchema-instance xmlns:xsd=http://www.w3.org/2001/XMLSchema xmlns=AnetApi/xml/v1/schema/AnetApiSchema.xsd><refId/><messages>
      <resultCode>Error</resultCode>
      <message>
        <code>E00027</code>
        <text>The transaction was unsuccessful.</text>
      </message>
      </messages><transactionResponse>
      <responseCode>3</responseCode>
      <authCode/>
      <avsResultCode>P</avsResultCode>
      <cvvResultCode/>
      <cavvResultCode/>
      <transId>0</transId>
      <refTransID>23124</refTransID>
      <transHash>D99CC43D1B34F0DAB7F430F8F8B3249A</transHash>
      <testRequest>0</testRequest>
      <accountNumber/>
      <accountType/>
      <errors>
        <error>
          <errorCode>16</errorCode>
          <errorText>The transaction cannot be found.</errorText>
        </error>
      </errors>
      <shipTo/>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def successful_refund_response
    <<-eos
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                                 xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
      <messages>
        <resultCode>Ok</resultCode>
        <message>
          <code>I00001</code>
          <text>Successful.</text>
        </message>
      </messages>
      <transactionResponse>
        <responseCode>1</responseCode>
        <authCode/>
        <avsResultCode>P</avsResultCode>
        <cvvResultCode/>
        <cavvResultCode/>
        <transId>2214602071</transId>
        <refTransID>2214269051</refTransID>
        <transHash>A3E5982FB6789092985F2D618196A268</transHash>
        <testRequest>0</testRequest>
        <accountNumber>XXXX2224</accountNumber>
        <accountType>Visa</accountType>
        <messages>
          <message>
            <code>1</code>
            <description>This transaction has been approved.</description>
          </message>
        </messages>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def failed_refund_response
    <<-eos
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                                 xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
      <messages>
        <resultCode>Error</resultCode>
        <message>
          <code>E00027</code>
          <text>The transaction was unsuccessful.</text>
        </message>
      </messages>
      <transactionResponse>
        <responseCode>3</responseCode>
        <authCode/>
        <avsResultCode>P</avsResultCode>
        <cvvResultCode/>
        <cavvResultCode/>
        <transId>0</transId>
        <refTransID>2214269051</refTransID>
        <transHash>63E03F4968F0874E1B41FCD79DD54717</transHash>
        <testRequest>0</testRequest>
        <accountNumber>XXXX2224</accountNumber>
        <accountType>Visa</accountType>
        <errors>
          <error>
            <errorCode>55</errorCode>
            <errorText>The sum of credits against the referenced transaction would exceed original debit amount.</errorText>
          </error>
        </errors>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def successful_void_response
    <<-eos
    <?xml version="1.0" encoding="utf-8"?>
    <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                               xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
    <messages>
      <resultCode>Ok</resultCode>
      <message>
        <code>I00001</code>
        <text>Successful.</text>
      </message>
    </messages>
    <transactionResponse>
      <responseCode>1</responseCode>
      <authCode>GYEB3</authCode>
      <avsResultCode>P</avsResultCode>
      <cvvResultCode/>
      <cavvResultCode/>
      <transId>2213755822</transId>
      <refTransID>2213755822</refTransID>
      <transHash>3383BBB85FF98057D61B2D9B9A2DA79F</transHash>
      <testRequest>0</testRequest>
      <accountNumber>XXXX0015</accountNumber>
      <accountType>MasterCard</accountType>
      <messages>
        <message>
          <code>1</code>
          <description>This transaction has been approved.</description>
        </message>
      </messages>
    </transactionResponse>
    </createTransactionResponse>
    eos
  end

  def failed_void_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                                 xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
      <messages>
        <resultCode>Error</resultCode>
        <message>
          <code>E00027</code>
          <text>The transaction was unsuccessful.</text>
        </message>
      </messages>
      <transactionResponse>
        <responseCode>3</responseCode>
        <authCode/>
        <avsResultCode>P</avsResultCode>
        <cvvResultCode/>
        <cavvResultCode/>
        <transId>0</transId>
        <refTransID>2213755821</refTransID>
        <transHash>39DC95085A313FEF7278C40EA8A66B16</transHash>
        <testRequest>0</testRequest>
        <accountNumber/>
        <accountType/>
        <errors>
          <error>
            <errorCode>16</errorCode>
            <errorText>The transaction cannot be found.</errorText>
          </error>
        </errors>
        <shipTo/>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def successful_credit_response
    <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <createTransactionResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <refId>1</refId>
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <transactionResponse>
          <responseCode>1</responseCode>
          <authCode />
          <avsResultCode>P</avsResultCode>
          <cvvResultCode />
          <cavvResultCode />
          <transId>2230004436</transId>
          <refTransID />
          <transHash>BF2ADA32B70495EE035C6A5ADC635047</transHash>
          <testRequest>0</testRequest>
          <accountNumber>XXXX2224</accountNumber>
          <accountType>Visa</accountType>
          <messages>
            <message>
              <code>1</code>
              <description>This transaction has been approved.</description>
            </message>
          </messages>
          <userFields>
            <userField>
              <name>x_currency_code</name>
              <value>USD</value>
            </userField>
          </userFields>
        </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def failed_credit_response
    <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <createTransactionResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <refId>1</refId>
        <messages>
          <resultCode>Error</resultCode>
          <message>
            <code>E00027</code>
            <text>The transaction was unsuccessful.</text>
          </message>
        </messages>
        <transactionResponse>
          <responseCode>3</responseCode>
          <authCode />
          <avsResultCode>P</avsResultCode>
          <cvvResultCode />
          <cavvResultCode />
          <transId>0</transId>
          <refTransID />
          <transHash>0FFA5F1B4CA8DC9643BC117DAFB45770</transHash>
          <testRequest>0</testRequest>
          <accountNumber>XXXX1222</accountNumber>
          <accountType />
          <errors>
            <error>
              <errorCode>6</errorCode>
              <errorText>The credit card number is invalid.</errorText>
            </error>
          </errors>
          <userFields>
            <userField>
              <name>x_currency_code</name>
              <value>USD</value>
            </userField>
          </userFields>
        </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def successful_store_response
    <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <createCustomerProfileResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <messages>
          <resultCode>Ok</resultCode>
          <message>
          <code>I00001</code>
          <text>Successful.</text>
          </message>
      </messages>
      <customerProfileId>35959426</customerProfileId>
      <customerPaymentProfileIdList>
          <numericString>32506918</numericString>
      </customerPaymentProfileIdList>
      <customerShippingAddressIdList />
      <validationDirectResponseList />
      </createCustomerProfileResponse>
    eos
  end

  def failed_store_response
    <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <createCustomerProfileResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <messages>
          <resultCode>Error</resultCode>
          <message>
          <code>E00015</code>
          <text>The field length is invalid for Card Number.</text>
          </message>
      </messages>
      <customerPaymentProfileIdList />
      <customerShippingAddressIdList />
      <validationDirectResponseList />
      </createCustomerProfileResponse>
    eos
  end

  def successful_unstore_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <deleteCustomerProfileResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
      </deleteCustomerProfileResponse>
    eos
  end

  def failed_unstore_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <deleteCustomerProfileResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <messages>
          <resultCode>Error</resultCode>
          <message>
            <code>E00040</code>
            <text>The record cannot be found.</text>
          </message>
        </messages>
      </deleteCustomerProfileResponse>
    eos
  end

  def successful_store_new_payment_profile_response
    <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <createCustomerPaymentProfileResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <customerProfileId>38392170</customerProfileId>
        <customerPaymentProfileId>34896759</customerPaymentProfileId>
      </createCustomerPaymentProfileResponse>
    eos
  end

  def failed_store_new_payment_profile_response
    <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <createCustomerPaymentProfileResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <messages>
          <resultCode>Error</resultCode>
          <message>
            <code>E00039</code>
            <text>A duplicate customer payment profile already exists.</text>
          </message>
        </messages>
        <customerProfileId>38392767</customerProfileId>
        <customerPaymentProfileId>34897359</customerPaymentProfileId>
      </createCustomerPaymentProfileResponse>
    eos
  end

  def successful_purchase_using_stored_card_response
    <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <createCustomerProfileTransactionResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <refId>1</refId>
      <messages>
          <resultCode>Ok</resultCode>
          <message>
          <code>I00001</code>
          <text>Successful.</text>
          </message>
      </messages>
      <directResponse>1,1,1,This transaction has been approved.,8HUT72,Y,2235700270,1,Store Purchase,1.01,CC,auth_capture,e385c780422f4bd182c4,Longbob,Longsen,,,,n/a,,,,,,,,,,,,,,,,,,,4A20EEAF89018FF075899DDB332E9D35,,2,,,,,,,,,,,XXXX2224,Visa,,,,,,,,,,,,,,,,</directResponse>
      </createCustomerProfileTransactionResponse>
    eos
  end

  def failed_purchase_using_stored_card_response
    <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <createCustomerProfileTransactionResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <refId>1</refId>
        <messages>
          <resultCode>Error</resultCode>
          <message>
            <code>E00027</code>
            <text>The credit card number is invalid.</text>
          </message>
        </messages>
        <directResponse>3,1,6,The credit card number is invalid.,,P,0,1,Store Purchase,1.01,CC,auth_capture,2da01d7b583c706106e2,Longbob,Longsen,,,,n/a,,,,,,,,,,,,,,,,,,,13BA28EEA3593C13E2E3BC109D16E5D2,,,,,,,,,,,,,XXXX1222,,,,,,,,,,,,,,,,,</directResponse>
      </createCustomerProfileTransactionResponse>
    eos
  end

  def successful_authorize_using_stored_card_response
    <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <createCustomerProfileTransactionResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <refId>1</refId>
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <directResponse>1,1,1,This transaction has been approved.,GGHQ5R,Y,2235700640,1,Store Purchase,1.01,CC,auth_only,0bde9d39f8eb9443f2af,Longbob,Longsen,,,,n/a,,,,,,,,,,,,,,,,,,,E47E5CA4F1239B00D39A7F8C147215D3,,2,,,,,,,,,,,XXXX2224,Visa,,,,,,,,,,,,,,,,</directResponse>
      </createCustomerProfileTransactionResponse>
    eos
  end

  def failed_authorize_using_stored_card_response
    <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <createCustomerProfileTransactionResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <refId>1</refId>
        <messages>
          <resultCode>Error</resultCode>
          <message>
            <code>E00027</code>
            <text>The credit card number is invalid.</text>
          </message>
        </messages>
        <directResponse>3,1,6,The credit card number is invalid.,,P,0,1,Store Purchase,1.01,CC,auth_only,f632442ce056f9f82ee9,Longbob,Longsen,,,,n/a,,,,,,,,,,,,,,,,,,,13BA28EEA3593C13E2E3BC109D16E5D2,,,,,,,,,,,,,XXXX1222,,,,,,,,,,,,,,,,,</directResponse>
      </createCustomerProfileTransactionResponse>
    eos
  end

  def successful_capture_using_stored_card_response
    <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <createCustomerProfileTransactionResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <refId />
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <directResponse>1,1,1,This transaction has been approved.,GGHQ5R,P,2235700640,1,,1.01,CC,prior_auth_capture,0bde9d39f8eb9443f2af,,,,,,,,,,,,,,,,,,,,,,,,,E47E5CA4F1239B00D39A7F8C147215D3,,,,,,,,,,,,,XXXX2224,Visa,,,,,,,,,,,,,,,,</directResponse>
      </createCustomerProfileTransactionResponse>
    eos
  end

  def failed_capture_using_stored_card_response
    <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <createCustomerProfileTransactionResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <refId />
        <messages>
          <resultCode>Error</resultCode>
          <message>
            <code>E00027</code>
            <text>The amount requested for settlement cannot be greater than the original amount authorized.</text>
          </message>
        </messages>
        <directResponse>3,2,47,The amount requested for settlement cannot be greater than the original amount authorized.,,P,0,,,41.01,CC,prior_auth_capture,,,,,,,,,,,,,,,,,,,,,,,,,,8A556B125A1DA070AF5A84B798B7FBF7,,,,,,,,,,,,,,Visa,,,,,,,,,,,,,,,,</directResponse>
      </createCustomerProfileTransactionResponse>
    eos
  end

  def failed_refund_using_stored_card_response
    <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <createCustomerProfileTransactionResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <refId>1</refId>
        <messages>
          <resultCode>Error</resultCode>
          <message>
            <code>E00040</code>
            <text>The record cannot be found.</text>
          </message>
        </messages>
      </createCustomerProfileTransactionResponse>
    eos

  end

  def successful_void_using_stored_card_response
    <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <createCustomerProfileTransactionResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <refId />
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <directResponse>1,1,1,This transaction has been approved.,3R9YE2,P,2235701141,1,,0.00,CC,void,becdb509b35a32c30e97,,,,,,,,,,,,,,,,,,,,,,,,,C3C4B846B9D5A37D14462C2BF5B924FD,,,,,,,,,,,,,XXXX2224,Visa,,,,,,,,,,,,,,,,</directResponse>
      </createCustomerProfileTransactionResponse>
    eos
  end

  def failed_void_using_stored_card_response
    <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <createCustomerProfileTransactionResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <refId />
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <directResponse>1,1,310,This transaction has already been voided.,,P,0,,,0.00,CC,void,,,,,,,,,,,,,,,,,,,,,,,,,,FD9FAE70BEF461997A6C15D7D597658D,,,,,,,,,,,,,,Visa,,,,,,,,,,,,,,,,</directResponse>
      </createCustomerProfileTransactionResponse>
    eos
  end

  def network_tokenization_not_supported_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                                 xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>123456</refId>
        <messages>
          <resultCode>Error</resultCode>
          <message>
            <code>E00155</code>
            <text>This processor does not support this method of submitting payment data</text>
          </message>
        </messages>
        <transactionResponse>
          <responseCode>3</responseCode>
          <authCode/>
          <avsResultCode>P</avsResultCode>
          <cvvResultCode/>
          <cavvResultCode/>
          <transId>0</transId>
          <refTransID/>
          <transHash>DA56E64108957174C5AE9BE466914741</transHash>
          <testRequest>0</testRequest>
          <accountNumber>XXXX0001</accountNumber>
          <accountType/>
          <errors>
            <error>
              <errorCode>155</errorCode>
              <errorText>This processor does not support this method of submitting payment data</errorText>
            </error>
          </errors>
          <userFields>
            <userField>
              <name>MerchantDefinedFieldName1</name>
              <value>MerchantDefinedFieldValue1</value>
            </userField>
            <userField>
              <name>favorite_color</name>
              <value>blue</value>
            </userField>
          </userFields>
        </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def credentials_are_legit_response
    <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <authenticateTestResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
      </authenticateTestResponse>
    eos
  end

  def credentials_are_bogus_response
    <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <authenticateTestResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <messages>
          <resultCode>Error</resultCode>
          <message>
            <code>E00007</code>
            <text>User authentication failed due to invalid authentication values.</text>
          </message>
        </messages>
      </authenticateTestResponse>
    eos
  end

  def failed_refund_for_unsettled_payment_response
    <<-eos
    <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <messages>
          <resultCode>Error</resultCode>
          <message>
            <code>E00027</code>
            <text>The transaction was unsuccessful.</text>
          </message>
        </messages>
        <transactionResponse>
          <responseCode>3</responseCode>
          <authCode/>
          <avsResultCode>P</avsResultCode>
          <cvvResultCode/>
          <cavvResultCode/>
          <transId>0</transId>
          <refTransID/>
          <transHash/>
          <testRequest>0</testRequest>
          <accountNumber>XXXX0001</accountNumber>
          <accountType>Visa</accountType>
          <errors>
            <error>
              <errorCode>54</errorCode>
              <errorText>The referenced transaction does not meet the criteria for issuing a credit.</errorText>
            </error>
          </errors>
          <userFields/>
          <transHashSha2/>
        </transactionResponse>
      </createTransactionResponse>
    eos
  end
end
