require 'test_helper'
require 'securerandom'
require 'json'
require 'net/http'
require 'uri'

class RemoteMidtransTest < Test::Unit::TestCase
  def setup
    @gateway = MidtransGateway.new(fixtures(:midtrans))
    @default_options = default_options
    @accepted_payment = accepted_payment
    @declined_payment = declined_payment
    @challenged_payment = challenged_payment
  end

  def test_successful_purchase
    options = @default_options.merge(order_id_options)
    response = @gateway.purchase(options[:gross_amount], @accepted_payment, options)
    assert_success response
    assert_equal response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:capture]
  end

  def test_declined_payment
    options = @default_options.merge(order_id_options)
    response = @gateway.purchase(options[:gross_amount], @declined_payment, options)
    assert_failure response
    assert_equal response.status_code, MidtransGateway::STATUS_CODE_MAPPING[:denied]
    assert_equal response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:deny]
  end

  def test_incorrect_gross_amount
    options = @default_options.merge(order_id_options)
    response = @gateway.purchase(options[:gross_amount] - 1, @accepted_payment, options)
    assert_failure response
    assert_equal response.status_code, MidtransGateway::STATUS_CODE_MAPPING[:validation_error]
  end

  def test_order_id_is_not_exist
    options = @default_options
    response = @gateway.purchase(options[:gross_amount], @accepted_payment, options)
    assert_failure response
    assert_equal response.status_code, MidtransGateway::STATUS_CODE_MAPPING[:validation_error]
  end

  def test_duplicated_order_id
    options = @default_options.merge(order_id_options)
    response = @gateway.purchase(options[:gross_amount], @accepted_payment, options)
    assert_success response
    assert_equal response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:capture]

    response = @gateway.purchase(options[:gross_amount], @accepted_payment, options)
    assert_failure response
    assert_equal response.status_code, MidtransGateway::STATUS_CODE_MAPPING[:duplicated_order_id]
  end

  def test_token_id_is_missing
    options = @default_options
    missing_token_id_payment = @accepted_payment.dup
    missing_token_id_payment[:credit_card][:token_id] = nil
    response = @gateway.purchase(options[:gross_amount], missing_token_id_payment, options)
    assert_failure response
    assert_equal response.status_code, MidtransGateway::STATUS_CODE_MAPPING[:token_error]
  end

  def test_invalid_data_type
    options = @default_options.merge(order_id_options)
    response = @gateway.purchase('Invalid gross amount', @accepted_payment, options)
    assert_failure response
    assert_equal response.status_code, MidtransGateway::STATUS_CODE_MAPPING[:validation_error]
  end

  def test_successful_authorize
    options = @default_options.merge(order_id_options)
    response = @gateway.authorize(options[:gross_amount], @accepted_payment, options)
    assert_success response
    assert_equal response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:authorize]
  end

  def test_failed_authorize_cause_declined_card
    options = @default_options.merge(order_id_options)
    response = @gateway.purchase(options[:gross_amount], @declined_payment, options)
    assert_failure response
    assert_equal response.status_code, MidtransGateway::STATUS_CODE_MAPPING[:denied]
    assert_equal response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:deny]
  end

  def test_successful_authorize_and_capture
    options = @default_options.merge(order_id_options)
    auth_response = @gateway.authorize(options[:gross_amount], @accepted_payment, options)
    assert_success auth_response
    assert_equal auth_response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:authorize]

    assert capture_response = @gateway.capture(auth_response.params[:gross_amount], auth_response.authorization)
    assert_success capture_response
    assert_equal capture_response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:capture]
  end

  def test_not_exists_transaction
    options = @default_options.merge(order_id_options)
    auth_response = @gateway.authorize(options[:gross_amount], @accepted_payment, options)
    assert_success auth_response
    assert_equal auth_response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:authorize]

    assert capture_response = @gateway.capture(auth_response.params[:gross_amount], 'Not exists transaction')
    assert_failure capture_response
    assert_equal capture_response.status_code, MidtransGateway::STATUS_CODE_MAPPING[:resouce_not_found]
  end

  def test_partial_capture
    options = @default_options.merge(order_id_options)
    auth_response = @gateway.authorize(options[:gross_amount], @accepted_payment, options)
    assert_success auth_response
    assert_equal auth_response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:authorize]

    assert capture_response = @gateway.capture(auth_response.params[:gross_amount].to_i - 1, auth_response.authorization)
    assert_success capture_response
    assert_equal capture_response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:capture]
  end

  def test_capture_malformed_syntax_error
    response = @gateway.capture(@amount, {})
    assert_failure response
    assert_equal response.status_code, MidtransGateway::STATUS_CODE_MAPPING[:malformed_syntax_error]
  end

  def test_successful_void
    options = @default_options.merge(order_id_options)
    authorize_response = @gateway.authorize(options[:gross_amount], @accepted_payment, options)
    assert_success authorize_response
    assert_equal authorize_response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:authorize]

    assert void_response = @gateway.void(authorize_response.authorization)
    assert_success void_response
    assert_equal void_response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:cancel]
  end

  def test_void_not_found_transaction
    response = @gateway.void('Not found transaction')
    assert_failure response
    assert_equal response.status_code, MidtransGateway::STATUS_CODE_MAPPING[:resouce_not_found]
  end

  def test_successful_verify
    assert response = @gateway.verify(@accepted_payment, order_id_options)
    assert_success response
    assert_equal response.primary_response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:cancel]
  end

  def test_failed_verify_cause_declined_card
    assert response = @gateway.verify(@declined_payment, order_id_options)
    assert_failure response
    assert_equal response.primary_response.status_code, MidtransGateway::STATUS_CODE_MAPPING[:denied]
    assert_equal response.primary_response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:deny]
  end

  def test_successful_purchase_and_approve
    options = @default_options.merge(order_id_options)
    charge_response = @gateway.purchase(options[:gross_amount], @challenged_payment, options)
    assert_success charge_response
    assert_equal charge_response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:capture]
    assert_equal charge_response.params[:fraud_status], MidtransGateway::FRAUD_STATUS_MAPPING[:challenge]

    assert approve_response = @gateway.approve(charge_response.authorization)
    assert_success approve_response
    assert_equal approve_response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:capture]
    assert_equal approve_response.params[:fraud_status], MidtransGateway::FRAUD_STATUS_MAPPING[:accept]
  end

  def test_approve_accept_payment_purchase
    options = @default_options.merge(order_id_options)
    charge_response = @gateway.purchase(options[:gross_amount], @accepted_payment, options)
    assert_success charge_response
    assert_equal charge_response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:capture]
    assert_equal charge_response.params[:fraud_status], MidtransGateway::FRAUD_STATUS_MAPPING[:accept]

    assert approve_response = @gateway.approve(charge_response.authorization)
    assert_failure approve_response
    assert_equal approve_response.status_code, MidtransGateway::STATUS_CODE_MAPPING[:cannot_modify_transaction_status]
  end

  def test_successful_status
    options = @default_options.merge(order_id_options)
    charge_response = @gateway.purchase(options[:gross_amount], @accepted_payment, options)
    assert_success charge_response
    assert_equal charge_response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:capture]

    assert status_response = @gateway.status(charge_response.authorization)
    assert_success status_response
    assert_equal status_response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:capture]
    assert_equal charge_response.authorization, status_response.authorization
  end

  def test_failed_status_with_incorrect_transaction
    options = @default_options.merge(order_id_options)
    charge_response = @gateway.purchase(options[:gross_amount], @accepted_payment, options)
    assert_success charge_response
    assert_equal charge_response.transaction_status, MidtransGateway::TRANSACTION_STATUS_MAPPING[:capture]

    assert status_response = @gateway.status('Incorrect transaction id')
    assert_failure status_response
    assert_equal status_response.status_code, MidtransGateway::STATUS_CODE_MAPPING[:resouce_not_found]
  end

  def test_invalid_credentials
    gateway = MidtransGateway.new(client_key: 'Invalid client key', server_key: 'Invalid server key')
    options = @default_options.merge(order_id_options)
    response = gateway.purchase(@amount, @accepted_payment, options)
    assert_failure response
    assert_equal response.status_code, MidtransGateway::STATUS_CODE_MAPPING[:access_denied]
  end

  private

  def token_id_for(credit_card, client_key)
    @uri = URI.parse(
      "https://api.sandbox.veritrans.co.id/v2/token?card_number=#{credit_card[:card_number]}&card_cvv=#{credit_card[:card_cvv]}&card_exp_month=#{credit_card[:card_exp_month]}&card_exp_year=#{credit_card[:card_exp_year]}&client_key=#{client_key}"
    )
    response = Net::HTTP.get_response(@uri)
    JSON.parse(response.body)['token_id']
  end

  def default_options
    {
      gross_amount: 40,
      item_details: [{
        id: 'a1',
        price: 20,
        quantity: 2,
        name: 'Apel',
        brand: 'Fuji Apple',
        category: 'Fruit',
        merchant_name: 'Fruit-store'
      }],
      customer_details: {
        first_name: 'Luu',
        last_name: 'Nguyen',
        email: 'luu.nguyen@honestbee.com',
        phone: '+6582431164',
        billing_address: {
          first_name: 'Luu',
          last_name: 'Nguyen',
          email: 'luu.nguyen@honestbee.com',
          phone: '+6582431164',
          address: '2 Alexandra Road, Singapore 159919',
          city: 'Singapore',
          postal_code: '159919',
          country_code: 'SGP'
        },
        shipping_address: {
          first_name: 'Luu',
          last_name: 'Nguyen',
          email: 'luu.nguyen@honestbee.com',
          phone: '+6582431164',
          address: '2 Alexandra Road, Singapore 159919',
          city: 'Singapore',
          postal_code: '159919',
          country_code: 'SGP'
        }
      }
    }
  end

  def accepted_payment
    accepted_card = {
      card_number: '4811111111111114',
      card_cvv: '123',
      card_exp_month: '01',
      card_exp_year: '2020'
    }

    payment_for(accepted_card)
  end

  def declined_payment
    declined_card = {
      card_number: '4911111111111113',
      card_cvv: '123',
      card_exp_month: '01',
      card_exp_year: '2020'
    }

    payment_for(declined_card)
  end

  def challenged_payment
    challenged_card = {
      card_number: '4511111111111117',
      card_cvv: '123',
      card_exp_month: '01',
      card_exp_year: '2020'
    }

    payment_for(challenged_card)
  end

  def payment_for(credit_card)
    {
      payment_type: 'credit_card',
      credit_card: {
        token_id: token_id_for(credit_card, @gateway.options[:client_key])
      }
    }
  end

  def order_id_options
    { order_id: SecureRandom.uuid }
  end
end
