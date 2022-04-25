require 'test_helper'

class RemoteSimetrikTest < Test::Unit::TestCase
  def setup
    @gateway = SimetrikGateway.new(fixtures(:simetrik))
    @token_acquirer = 'bc4c0f26-a357-4294-9b9e-a90e6c868c6e'
    @credit_card = CreditCard.new(
      first_name: 'Joe',
      last_name: 'Doe',
      number: '4551708161768059',
      month: 7,
      year: 2022,
      verification_value: '111'
    )
    @credit_card_invalid = CreditCard.new(
      first_name: 'Joe',
      last_name: 'Doe',
      number: '3551708161768059',
      month: 3,
      year: 2026,
      verification_value: '111'
    )
    @amount = 100
    @sub_merchant = {
      address: 'None',
      extra_params: {
      },
      mcc: '5816',
      merchant_id: '400000008',
      name: '885.519.237',
      phone_number: '3434343',
      postal_code: 'None',
      url: 'string'
    }
    @psp_info = {
      id: '0123',
      name: 'mci',
      sub_merchant: {
        id: 'string',
        name: 'string'
      }

    }

    @authorize_options_success = {
      acquire_extra_options: {},
      trace_id: SecureRandom.uuid,
      user: {
        id: '123',
        email: 's@example.com'
      },
      order: {
        id: rand(100000000000..999999999999).to_s,
        datetime_local_transaction: Time.new.strftime('%Y-%m-%dT%H:%M:%S.%L%:z'),
        description: 'apopsicle',
        installments: 1
      },
      vat: 19,
      currency: 'USD',
      authentication: {
        three_ds_fields: {
          version: '2.1.0',
          eci: '05',
          cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA',
          ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC',
          acs_transaction_id: '13c701a3-5a88-4c45-89e9-ef65e50a8bf9',
          cavv_algorithm: '1',
          xid: '333333333',
          directory_response_status: 'Y',
          authentication_response_status: 'Y',
          enrolled: 'test',
          three_ds_server_trans_id: '24f701e3-9a85-4d45-89e9-af67e70d8fg8'
        }
      },
      sub_merchant: @sub_merchant,
      psp_info: @psp_info,
      token_acquirer: @token_acquirer
    }
  end

  def test_success_authorize
    response = @gateway.authorize(@amount, @credit_card, @authorize_options_success)
    assert_success response
    assert_instance_of Response, response
    assert_equal response.message, 'successful authorize'
    assert_equal response.error_code, nil, 'Should expected error code equal to nil'
    assert_equal response.avs_result['code'], 'G'
    assert_equal response.cvv_result['code'], 'P'
    assert response.test?
  end

  def test_failed_authorize
    options = @authorize_options_success.clone()
    options.delete(:user)

    response = @gateway.authorize(@amount, @credit_card, options)
    assert_failure response
    assert_instance_of Response, response
    assert_equal response.error_code, 'config_error'
    assert_equal response.avs_result['code'], 'I'
    assert_equal response.cvv_result['code'], 'P'
    assert response.test?
  end

  def test_failed_authorize_by_invalid_card
    response = @gateway.authorize(@amount, @credit_card_invalid, @authorize_options_success)
    assert_failure response
    assert_instance_of Response, response
    assert_equal response.error_code, 'invalid_number'
    assert_equal response.avs_result['code'], 'G'
    assert_equal response.cvv_result['code'], 'P'
    assert response.test?
  end

  def test_success_purchase
    response = @gateway.purchase(@amount, @credit_card, @authorize_options_success)
    assert_success response
    assert_instance_of Response, response
    assert_equal response.message, 'successful charge'
    assert_equal response.error_code, nil, 'Should expected error code equal to nil'
    assert_equal response.avs_result['code'], 'G'
    assert_equal response.cvv_result['code'], 'P'
    assert response.test?
  end

  def test_failed_purchase
    options = @authorize_options_success.clone()
    options.delete(:user)

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_failure response
    assert_instance_of Response, response
    assert_equal response.error_code, 'config_error'
    assert_equal response.avs_result['code'], 'I'
    assert_equal response.cvv_result['code'], 'P'
    assert response.test?
  end

  def test_failed_purchase_by_invalid_card
    response = @gateway.purchase(@amount, @credit_card_invalid, @authorize_options_success)
    assert_failure response
    assert_instance_of Response, response
    assert_equal response.error_code, 'invalid_number'
    assert_equal response.avs_result['code'], 'G'
    assert_equal response.cvv_result['code'], 'P'
    assert response.test?
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @authorize_options_success)
    assert_success auth
    sleep(3)
    option = {
      vat: @authorize_options_success[:vat],
      currency: @authorize_options_success[:currency],

      transaction_id: auth.authorization,
      token_acquirer: @token_acquirer,
      trace_id: @authorize_options_success[:trace_id]
    }
    assert capture = @gateway.capture(@amount, auth.authorization, option)
    assert_success capture
    assert_equal 'successful capture', capture.message
  end

  def test_failed_capture
    auth = @gateway.authorize(@amount, @credit_card, @authorize_options_success)
    assert_success auth

    option = {
      vat: @authorize_options_success[:vat],
      currency: @authorize_options_success[:currency],
      transaction_id: auth.authorization,
      token_acquirer: @token_acquirer,
      trace_id: @authorize_options_success[:trace_id]
    }
    sleep(3)
    capture = @gateway.capture(@amount, auth.authorization, option)
    assert_success capture
    option = {
      vat: 19,
      currency: 'USD',
      transaction_id: auth.authorization,
      token_acquirer: @token_acquirer,
      trace_id: @authorize_options_success[:trace_id]
    }

    assert capture = @gateway.capture(@amount, auth.authorization, option)
    assert_failure capture
    assert_equal 'CAPTURE_REJECTED', capture.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @authorize_options_success)
    assert_success auth

    option = {
      token_acquirer: @token_acquirer,
      trace_id: @authorize_options_success[:trace_id],
      acquire_extra_options: {}
    }
    sleep(6)
    assert void = @gateway.void(auth.authorization, option)
    assert_success void
    assert_equal 'successful void', void.message
  end

  def test_failed_void
    # First successful void
    auth = @gateway.authorize(@amount, @credit_card, @authorize_options_success)
    assert_success auth

    option = {
      token_acquirer: @token_acquirer,
      trace_id: @authorize_options_success[:trace_id],
      acquire_extra_options: {}
    }
    sleep(3)
    assert void = @gateway.void(auth.authorization, option)
    assert_success void
    assert_equal 'successful void', void.message

    # Second failed void
    option = {
      token_acquirer: @token_acquirer,
      trace_id: '2717a3e0-0db2-4971-b94f-686d3b72c44b'
    }
    void = @gateway.void(auth.authorization, option)
    assert_failure void
    assert_equal 'VOID_REJECTED', void.message
  end

  def test_failed_refund
    response = @gateway.purchase(@amount, @credit_card, @authorize_options_success)
    option = {
      token_acquirer: @token_acquirer,
      trace_id: '2717a3e0-0db2-4971-b94f-686d3b72c44b',
      currency: 'USD',
      comment: 'This is a comment',
      acquire_extra_options: {
        ruc: '13431131234'
      }
    }
    assert_success response
    sleep(3)
    refund = @gateway.refund(@amount, response.authorization, option)
    assert_failure refund
    assert_equal 'REFUND_REJECTED', refund.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @authorize_options_success)
    end
    transcript = @gateway.scrub(transcript)
    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:client_secret], transcript)
  end
end
