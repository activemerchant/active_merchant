require          'test_helper'

class RemoteEmerchantpayDirectTest < Test::Unit::TestCase

  EmerchantpayDirectGateway::RESPONSE_ERROR_CODES.each do |key, _|
    name = "response_code_#{key}"
    define_method(name) { EmerchantpayDirectGateway::RESPONSE_ERROR_CODES[key] }
  end

  EmerchantpayDirectGateway::ISSUER_RESPONSE_ERROR_CODES.each do |key, _|
    name = "issuer_code_#{key}"
    define_method(name) { EmerchantpayDirectGateway::ISSUER_RESPONSE_ERROR_CODES[key] }
  end

  def setup
    @gateway = EmerchantpayDirectGateway.new(fixtures(:emerchantpay_direct))

    prepare_shared_test_data
  end

  def test_successful_visa_authorize
    add_successful_description('Visa Authorization')
    add_credit_cards(:visa)

    auth = @gateway.authorize(@amount, @approved_visa, @order_details)

    expect_successful_response(auth, EmerchantpayDirectGateway::AUTHORIZE)
  end

  def test_successful_visa_authorize_3d
    add_successful_description('Visa 3D Authorization')
    add_3d_credit_cards

    auth = @gateway.authorize(@amount, @visa_3d_enrolled, @order_details)

    expect_successful_response(auth, EmerchantpayDirectGateway::AUTHORIZE_3D)
  end

  def test_failed_visa_authorize
    add_failed_description('Visa Authorization')
    add_credit_cards(:visa)

    authorize = @gateway.authorize(@amount, @declined_visa, @order_details)

    expect_failed_response(authorize,
                           status:           EmerchantpayDirectGateway::DECLINED,
                           transaction_type: EmerchantpayDirectGateway::AUTHORIZE,
                           code:             response_codes_invalid_card)
  end

  def test_failed_mastercard_authorize
    add_failed_description('MasterCard Authorization')
    add_credit_cards(:mastercard)

    authorize = @gateway.authorize(@amount, @declined_mastercard, @order_details)
    expect_failed_response(authorize,
                           status:           EmerchantpayDirectGateway::DECLINED,
                           transaction_type: EmerchantpayDirectGateway::AUTHORIZE,
                           code:             response_codes_invalid_card)
  end

  def test_failed_authorize_3d_with_enrolled_failing
    add_failed_description('Visa 3D Enrolled Authentication')
    add_3d_credit_cards

    authorize = @gateway.authorize(@amount, @visa_3d_enrolled_fail_auth, @order_details)

    expect_failed_response(authorize,
                           status:           EmerchantpayDirectGateway::DECLINED,
                           transaction_type: EmerchantpayDirectGateway::AUTHORIZE_3D,
                           code:             response_code_authentication_error)
  end

  def test_failed_authorize_3d_with_card_not_participating
    add_failed_description('Visa 3D Card Not Participating')
    add_3d_credit_cards

    authorize = @gateway.authorize(@amount, @visa_3d_not_participating, @order_details)

    expect_failed_response(authorize,
                           status:           EmerchantpayDirectGateway::DECLINED,
                           transaction_type: EmerchantpayDirectGateway::AUTHORIZE_3D,
                           code:             response_code_processing_error)
  end

  def test_failed_authorize_3d_in_3ds_first_step
    add_failed_description('Visa 3D in 1st Step of 3DS Auth Process')
    add_3d_credit_cards

    authorize = @gateway.authorize(@amount,
                                   @visa_3d_error_first_step_auth,
                                   @order_details)

    expect_failed_response(authorize,
                           status:           EmerchantpayDirectGateway::ERROR,
                           transaction_type: EmerchantpayDirectGateway::AUTHORIZE_3D,
                           code:             response_code_authentication_error)
  end

  def test_failed_authorize_3d_in_3ds_second_step
    add_failed_description('Visa 3D in 2nd Step of 3DS Auth Process')
    add_3d_credit_cards

    authorize = @gateway.authorize(@amount,
                                   @visa_3d_error_second_step_auth,
                                   @order_details)

    expect_failed_response(authorize,
                           status:           EmerchantpayDirectGateway::ERROR,
                           transaction_type: EmerchantpayDirectGateway::AUTHORIZE_3D,
                           code:             response_code_authentication_error)
  end

  def test_successful_mastercard_capture
    add_successful_description('MasterCard Capture')
    add_credit_cards(:mastercard)

    auth = @gateway.authorize(@amount, @mastercard, @order_details)
    capture = @gateway.capture(@amount, auth.authorization, @order_details)

    expect_successful_response(capture, EmerchantpayDirectGateway::CAPTURE)
  end

  def test_successful_visa_capture
    add_successful_description('Visa Capture')
    add_3d_credit_cards

    auth = @gateway.authorize(@amount, @visa_3d_enrolled, @order_details)
    capture = @gateway.capture(@amount, auth.authorization, @order_details)

    expect_successful_response(capture, EmerchantpayDirectGateway::CAPTURE)
  end

  def test_partial_visa_capture
    add_successful_description('Partial Visa Capture')
    add_credit_cards(:visa)

    auth = @gateway.authorize(@amount, @approved_visa, @order_details)
    capture = @gateway.capture(@amount - 76, auth.authorization)

    expect_successful_response(capture, EmerchantpayDirectGateway::CAPTURE)
  end

  def test_failed_capture
    add_failed_description('Capture')

    capture = @gateway.capture(@amount, '')

    expect_failed_response(capture,
                           status:           EmerchantpayDirectGateway::ERROR,
                           transaction_type: EmerchantpayDirectGateway::CAPTURE,
                           code:             response_code_txn_not_found_error)
  end

  def test_successful_visa_purchase
    add_successful_description('Visa Purchase')
    add_credit_cards(:visa)

    purchase = @gateway.purchase(@amount, @approved_visa, @order_details)

    expect_successful_response(purchase, EmerchantpayDirectGateway::SALE)
  end

  def test_successful_visa_purchase_3d
    add_successful_description('Visa 3D Purchase')
    add_3d_credit_cards

    purchase = @gateway.purchase(@amount, @visa_3d_enrolled, @order_details)

    expect_successful_response(purchase, EmerchantpayDirectGateway::SALE_3D)
  end

  def test_failed_visa_purchase
    add_failed_description('Visa Purchase')
    add_credit_cards(:visa)

    purchase = @gateway.purchase(@amount, @declined_visa, @order_details)

    expect_failed_response(purchase,
                           status:           EmerchantpayDirectGateway::DECLINED,
                           transaction_type: EmerchantpayDirectGateway::SALE,
                           code:             response_codes_invalid_card)
  end

  def test_failed_mastercard_purchase
    add_failed_description('MasterCard Purchase')
    add_credit_cards(:mastercard)

    purchase = @gateway.purchase(@amount, @declined_mastercard, @order_details)

    expect_failed_response(purchase,
                           status:           EmerchantpayDirectGateway::DECLINED,
                           transaction_type: EmerchantpayDirectGateway::SALE,
                           code:             response_codes_invalid_card)
  end

  def test_failed_purchase_3d_with_enrolled_failing
    add_failed_description('Visa 3D Enrolled Authentication')
    add_3d_credit_cards

    purchase = @gateway.purchase(@amount, @visa_3d_enrolled_fail_auth, @order_details)

    expect_failed_response(purchase,
                           status:           EmerchantpayDirectGateway::DECLINED,
                           transaction_type: EmerchantpayDirectGateway::SALE_3D,
                           code:             response_code_authentication_error)
  end

  def test_failed_purchase_3d_with_card_not_participating
    add_failed_description('Visa 3D Card Not Participating')
    add_3d_credit_cards

    purchase = @gateway.purchase(@amount, @visa_3d_not_participating, @order_details)

    expect_failed_response(purchase,
                           status:           EmerchantpayDirectGateway::DECLINED,
                           transaction_type: EmerchantpayDirectGateway::SALE_3D,
                           code:             response_code_processing_error)
  end

  def test_failed_purchase_3d_in_3ds_first_step
    add_failed_description('Visa 3D in 1st Step of 3DS Auth Process')
    add_3d_credit_cards

    purchase = @gateway.purchase(@amount, @visa_3d_error_first_step_auth, @order_details)

    expect_failed_response(purchase,
                           status:           EmerchantpayDirectGateway::ERROR,
                           transaction_type: EmerchantpayDirectGateway::SALE_3D,
                           code:             response_code_authentication_error)
  end

  def test_failed_purchase_3d_in_3ds_second_step
    add_failed_description('Visa 3D in 2nd Step of 3DS Auth Process')
    add_3d_credit_cards

    purchase = @gateway.purchase(@amount, @visa_3d_error_second_step_auth, @order_details)

    expect_failed_response(purchase,
                           status:           EmerchantpayDirectGateway::ERROR,
                           transaction_type: EmerchantpayDirectGateway::SALE_3D,
                           code:             response_code_authentication_error)
  end

  def test_successful_mastercard_refund
    add_successful_description('MasterCard Refund')
    add_credit_cards(:mastercard)

    sale = @gateway.purchase(@amount, @mastercard, @order_details)
    refund = @gateway.refund(@amount, sale.authorization, @order_details)

    expect_successful_response(refund, EmerchantpayDirectGateway::REFUND)
  end

  def test_partial_visa_3d_refund
    add_successful_description('Visa 3D Partial Refund')
    add_3d_credit_cards

    sale3d = @gateway.purchase(@amount, @visa_3d_enrolled, @order_details)
    refund = @gateway.refund(@amount - 50, sale3d.authorization)

    expect_successful_response(refund, EmerchantpayDirectGateway::REFUND)
  end

  def test_failed_refund
    add_failed_description('Refund')

    refund = @gateway.refund(@amount, '')

    expect_failed_response(refund,
                           status:           EmerchantpayDirectGateway::ERROR,
                           transaction_type: EmerchantpayDirectGateway::REFUND,
                           code:             response_code_txn_not_found_error)
  end

  def test_successful_mastercard_verify
    add_successful_description('Verification')
    add_credit_cards(:mastercard)

    response = @gateway.verify(@mastercard, @order_details)

    expect_successful_response(response, EmerchantpayDirectGateway::AUTHORIZE)
  end

  def test_failed_visa_verify
    add_failed_description('Verification')
    add_credit_cards(:visa)

    response = @gateway.verify(@declined_visa, @order_details)

    expect_failed_response(response,
                           status:           EmerchantpayDirectGateway::DECLINED,
                           transaction_type: EmerchantpayDirectGateway::AUTHORIZE,
                           code:             response_codes_invalid_card)
  end

  def test_successful_mastercard_void
    add_successful_description('MasterCard Void')
    add_credit_cards(:mastercard)

    auth = @gateway.authorize(@amount, @mastercard, @order_details)
    void = @gateway.void(auth.authorization, @order_details)

    expect_successful_response(void, EmerchantpayDirectGateway::VOID)
  end

  def test_failed_void
    add_failed_description('Void')

    void = @gateway.void('')

    expect_failed_response(void,
                           status:           EmerchantpayDirectGateway::ERROR,
                           transaction_type: EmerchantpayDirectGateway::VOID,
                           code:             response_code_txn_not_found_error)
  end

  def test_failed_store_card
    add_credit_cards(:visa)

    response = @gateway.store(@approved_visa, @order_details)

    assert_response_instance(response)
    assert_failure response
  end

  def test_failed_unstore_card
    response = @gateway.unstore(0, @order_details)

    assert_response_instance(response)
    assert_failure response
  end

  def test_invalid_login
    set_invalid_gateway_credentials
    add_credit_cards(:visa)

    response = @gateway.purchase(@amount, @approved_visa, @order_details)

    expect_failed_response(response,
                           status: EmerchantpayDirectGateway::ERROR,
                           code:   response_code_merchant_login_failed)
  end

  private

  def assert_response_instance(response)
    assert_instance_of Response, response
  end

  def prepare_shared_test_data
    save_order_details
  end

  def save_order_details
    @amount        = generate_order_amount
    @order_details = build_base_order_details

    save_all_order_address_details
  end

  def order_address_types
    %w(billing shipping)
  end

  def save_all_order_address_details
    order_address_types.each do |address_type|
      save_order_address_details(address_type)
    end
  end

  def save_order_address_details(address_type)
    return unless order_address_types.include?(address_type)

    @order_details["#{address_type}_address".to_sym] = build_order_address_details
  end

  def add_successful_description(description)
    add_description('Successful', description)
  end

  def add_failed_description(description)
    add_description('Failed', description)
  end

  def add_description(expected_result, description)
    @order_details[:description] = "Active Merchant - Test #{expected_result} #{description}"
  end

  def set_invalid_gateway_credentials
    %w(username password token).each do |param|
      @gateway.options[param.to_sym] = "fake_#{param}"
    end
  end

  def assert_includes(expected_items, actual, failure_message = nil)
    return unless expected_items.is_a? Array

    assert_equal(true,
                 expected_items.include?(actual),
                 failure_message)
  end

  def response_codes_invalid_card
    [response_code_invalid_card_error, response_code_blacklist_error]
  end

  def check_response_assertions(response, assertions)
    assertions.each do |key, value|
      next unless value.present?

      expected_value = response.params[key.to_s]

      return assert_includes(value, expected_value) if value.is_a? Array

      assert_equal(value, expected_value)
    end
  end

  def error_transaction_expected?(assertions = {})
    assertions.key?('code') && !@gateway.configuration_error?(assertions['code'])
  end

  def expect_successful_response(response, transaction_type)
    assert response
    assert_success response
    assert_nil response.params['code']

    check_response_assertions(response,
                              transaction_type: transaction_type,
                              response_code:    issuer_code_approved)

    assert response.message
    assert_nil response.error_code

    check_response_txn_id(response)
    check_response_authorization(response, transaction_type)
  end

  def expect_failed_response(response, assertions = {})
    assert response
    assert_failure response

    check_response_assertions(response, assertions)

    assert response.message

    check_response_txn_id(response)     if error_transaction_expected?(assertions)
    check_response_error_code(response) if assertions.key?('code')

    assert_nil response.authorization
  end

  def check_response_txn_id(response)
    response_params = response.params

    assert response_params['unique_id']
    assert response_params['transaction_id']
  end

  def check_response_authorization(response, transaction_type)
    response_authorization = response.authorization

    return assert_nil response_authorization if reversed_transaction?(transaction_type)

    assert response_authorization
  end

  def reversed_transaction?(transaction_type)
    @gateway.reversed_transaction?(transaction_type)
  end

  def check_response_error_code(response)
    mapped_response_error_code = @gateway.map_error_code(response.params['code'])

    assert_equal mapped_response_error_code, response.error_code
  end

  def credit_card_mpi_params
    {
      payment_cryptogram: 'AAACA1BHADYJkIASQkcAAAAAAAA=',
      eci:                '05',
      transaction_id:     '0pv62FIrT5qQODB7DCewKgEBAQI='
    }
  end

  def add_credit_card_options
    @visa_options = {
      first_name: 'Active',
      last_name:  'Merchant'
    }

    @mastercard_options = @visa_options.merge(brand: 'mastercard')
  end

  def add_credit_cards(card_brand = nil)
    add_credit_card_options

    add_default_credit_cards    unless card_brand
    add_visa_credit_cards       if card_brand == :visa
    add_mastercard_credit_cards if card_brand == :mastercard
  end

  def add_default_credit_cards
    add_visa_credit_cards
    add_mastercard_credit_cards
  end

  def add_visa_credit_cards
    @approved_visa = credit_card('4200000000000000', @visa_options)
    @declined_visa = credit_card('4111111111111111', @visa_options)
  end

  def add_mastercard_credit_cards
    @mastercard          = credit_card('5555555555554444', @mastercard_options)
    @declined_mastercard = credit_card('5105105105105100', @mastercard_options)
  end

  def add_3d_credit_cards
    add_credit_card_options

    @visa_3d_enrolled               = build_credit_card_with_mpi('4711100000000000')
    @visa_3d_enrolled_fail_auth     = build_credit_card_with_mpi('4012001037461114')
    @visa_3d_not_participating      = build_credit_card_with_mpi('4012001036853337')
    @visa_3d_error_first_step_auth  = build_credit_card_with_mpi('4012001037484447')
    @visa_3d_error_second_step_auth = build_credit_card_with_mpi('4012001036273338')
  end

  def build_credit_card_with_mpi(number)
    card_options = @visa_options.merge(credit_card_mpi_params)

    network_tokenization_credit_card(number, card_options)
  end

  def generate_order_amount
    rand(100..200)
  end

  def build_base_order_details
    {
      order_id:        generate_unique_id,
      ip:              '127.0.0.1',
      customer:        'Active Merchant',
      invoice:         generate_unique_id,
      merchant:        'Merchant Name',
      description:     'Test Active Merchant Purchase',
      email:           'active.merchant@example.com',
      currency:        @gateway.default_currency
    }
  end

  def build_order_address_details
    {
      name:     'Travis Pastrana',
      phone:    '+1987987987988',
      address1: 'Muster Str. 14',
      address2: '',
      city:     'Los Angeles',
      state:    'CA',
      country:  'US',
      zip:      '10178'
    }
  end

end
