require 'test_helper'

class RemotePaymentezTest < Test::Unit::TestCase
  def setup
    @gateway = PaymentezGateway.new(fixtures(:paymentez))

    @amount = 100
    @credit_card = credit_card('4111111111111111', verification_value: '666')
    @elo_credit_card = credit_card('6362970000457013',
      month: 10,
      year: 2022,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      brand: 'elo')
    @declined_card = credit_card('4242424242424242', verification_value: '666')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      user_id: '998',
      email: 'joe@example.com',
      vat: 0,
      dev_reference: 'Testing'
    }

    @cavv = 'example-cavv-value'
    @xid = 'three-ds-v1-trans-id'
    @eci = '01'
    @three_ds_v1_version = '1.0.2'
    @three_ds_v2_version = '2.1.0'
    @three_ds_server_trans_id = 'three-ds-v2-trans-id'
    @authentication_response_status = 'Y'

    @three_ds_v1_mpi = {
      cavv: @cavv,
      eci: @eci,
      version: @three_ds_v1_version,
      xid: @xid
    }

    @three_ds_v2_mpi = {
      cavv: @cavv,
      eci: @eci,
      version: @three_ds_v2_version,
      three_ds_server_trans_id: @three_ds_server_trans_id,
      authentication_response_status: @authentication_response_status
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_purchase_with_elo
    response = @gateway.purchase(@amount, @elo_credit_card, @options)
    assert_success response
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: '127.0.0.1',
      tax_percentage: 0.07,
      phone: '333 333 3333'
    }

    response = @gateway.purchase(@amount, @credit_card, @options.merge(options))
    assert_success response
  end

  def test_successful_purchase_without_phone_billing_address_option
    options = {
      order_id: '1',
      ip: '127.0.0.1',
      tax_percentage: 0.07,
      billing_address: {
        phone: nil
      }
    }

    response = @gateway.purchase(@amount, @credit_card, @options.merge(options))
    assert_success response
  end

  def test_successful_purchase_without_phone_option
    options = {
      order_id: '1',
      ip: '127.0.0.1',
      tax_percentage: 0.07
    }

    response = @gateway.purchase(@amount, @credit_card, @options.merge(options))
    assert_success response
  end

  def test_successful_purchase_with_extra_params
    options = {
      extra_params: {
        configuration1: 'value1',
        configuration2: 'value2',
        configuration3: 'value3'
      }
    }

    response = @gateway.purchase(@amount, @credit_card, @options.merge(options))
    assert_success response
  end

  def test_successful_purchase_with_token
    store_response = @gateway.store(@credit_card, @options)
    assert_success store_response
    token = store_response.authorization
    purchase_response = @gateway.purchase(@amount, token, @options)
    assert_success purchase_response
  end

  def test_successful_purchase_with_token_and_cvc
    store_response = @gateway.store(@credit_card, @options)
    assert_success store_response
    token = store_response.authorization
    purchase_response = @gateway.purchase(@amount, token, @options.merge({"cvc": "012", "vat": 0, "tax_percentage": 0.0}))
    assert_success purchase_response
  end

  def test_successful_purchase_with_3ds1_mpi_fields
    @options[:three_d_secure] = @three_ds_v1_mpi
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_purchase_with_3ds2_mpi_fields
    @options[:three_d_secure] = @three_ds_v2_mpi
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_refund
    auth = @gateway.purchase(@amount, @credit_card, @options)
    assert_success auth

    assert refund = @gateway.refund(@amount, auth.authorization, @options)
    assert_success refund
    assert_equal 'Completed', refund.message
  end

  def test_successful_refund_with_elo
    auth = @gateway.purchase(@amount, @elo_credit_card, @options)
    assert_success auth

    assert refund = @gateway.refund(@amount, auth.authorization, @options)
    assert_success refund
    assert_equal 'Completed', refund.message
  end

  def test_successful_void
    auth = @gateway.purchase(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Completed', void.message
  end

  def test_successful_void_with_elo
    auth = @gateway.purchase(@amount, @elo_credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Completed', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'ValidationError', response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:config_error], response.error_code
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Response by mock', capture.message
  end

  def test_successful_authorize_and_capture_with_elo
    auth = @gateway.authorize(@amount, @elo_credit_card, @options)
    assert_success auth
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Response by mock', capture.message
  end

  def test_successful_authorize_and_capture_with_token
    store_response = @gateway.store(@credit_card, @options)
    assert_success store_response
    token = store_response.authorization
    auth = @gateway.authorize(@amount, token, @options)
    assert_success auth
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Response by mock', capture.message
  end

  def test_successful_authorize_and_capture_with_different_amount
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    amount = 99.0
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
    assert_equal 'Response by mock', capture.message
  end

  def test_successful_authorize_with_3ds1_mpi_fields
    @options[:three_d_secure] = @three_ds_v1_mpi
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_authorize_with_3ds2_mpi_fields
    @options[:three_d_secure] = @three_ds_v2_mpi
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Response by mock', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
    assert_equal 'Response by mock', capture.message
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'The modification of the amount is not supported by carrier', response.message
  end

  def test_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
  end

  def test_store_with_elo
    response = @gateway.store(@elo_credit_card, @options)
    assert_success response
  end

  def test_unstore
    response = @gateway.store(@credit_card, @options)
    assert_success response
    auth = response.authorization
    response = @gateway.unstore(auth, @options)
    assert_success response
  end

  def test_unstore_with_elo
    response = @gateway.store(@elo_credit_card, @options)
    assert_success response
    auth = response.authorization
    response = @gateway.unstore(auth, @options)
    assert_success response
  end

  def test_invalid_login
    gateway = PaymentezGateway.new(application_code: '9z8y7w6x', app_key: '1a2b3c4d')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'BackendResponseError', response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:config_error], response.error_code
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:app_key], transcript)
  end
end
