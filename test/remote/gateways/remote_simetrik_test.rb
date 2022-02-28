require 'test_helper'
require 'securerandom'

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
    @amount = 100

    setup_options()
  end

  def test_success_authorize
    response = @gateway.authorize(@amount, @credit_card, @authorize_capture_options_success)
    assert_success response
    assert_instance_of Response, response
    assert_equal response.params['message'], 'successful authorize'
    assert_equal response.params['code'][0], 'S', 'Should expected code like Sxxx'
    assert_equal response.avs_result.to_hash['code'], 'G'
    assert_equal response.cvv_result.to_hash['code'], 'P'
    assert response.test?
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @credit_card, @authorize_capture_options_failed)
    assert_failure response
    assert_instance_of Response, response
    # assert_equal response.message, 'Successful authorize'
    assert_equal response.params['code'][0], 'R', 'Should expected code like Rxxx'
    assert_equal response.avs_result.to_hash['code'], 'I'
    assert_equal response.cvv_result.to_hash['code'], 'P'
    assert response.test?
  end

  def test_success_purchase
    response = @gateway.purchase(@amount, @credit_card, @authorize_capture_options_success)
    assert_success response
    assert_instance_of Response, response
    assert_equal response.params['message'], 'successful charge'
    assert_equal response.params['code'][0], 'S', 'Should expected code like Sxxx'
    assert_equal response.avs_result.to_hash['code'], 'G'
    assert_equal response.cvv_result.to_hash['code'], 'P'
    assert response.test?
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @credit_card, @authorize_capture_options_failed)
    assert_failure response
    assert_instance_of Response, response
    assert_equal response.params['code'][0], 'R', 'Should expected code like Rxxx'
    assert_equal response.avs_result.to_hash['code'], 'I'
    assert_equal response.cvv_result.to_hash['code'], 'P'
    assert response.test?
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @authorize_capture_options_success)
    assert_success auth

    option = {
      vat: @authorize_capture_options_success[:order][:amount][:vat],
      currency: @authorize_capture_options_success[:order][:amount][:currency],
      transaction_id: auth.authorization,
      token_acquirer: @token_acquirer,
      trace_id: @authorize_capture_options_success[:trace_id]
    }

    assert capture = @gateway.capture(@amount, auth.authorization, option)
    assert_success capture
    assert_equal 'successful capture', capture.params['message']
  end

  def test_failed_capture
    auth = @gateway.authorize(@amount, @credit_card, @authorize_capture_options_success)
    assert_success auth

    option = {
      vat: @authorize_capture_options_success[:order][:amount][:vat],
      currency: @authorize_capture_options_success[:order][:amount][:currency],
      transaction_id: auth.authorization,
      token_acquirer: @token_acquirer,
      trace_id: @authorize_capture_options_success[:trace_id]
    }
    sleep(3)
    # First successful capture
    capture = @gateway.capture(@amount, auth.authorization, option)
    assert_success capture
    option = {
      vat: 19,
      currency: 'USD',
      transaction_id: auth.authorization,
      token_acquirer: @token_acquirer,
      trace_id: @authorize_capture_options_success[:trace_id]
    }

    assert capture = @gateway.capture(@amount, auth.authorization, option)
    assert_failure capture
    assert_equal 'CAPTURE_REJECTED', capture.params['message']
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @authorize_void_options_success)
    assert_success auth

    option = {
      token_acquirer: @token_acquirer,
      trace_id: @authorize_capture_options_success[:trace_id],
      acquire_extra_options: {}
    }

    assert void = @gateway.void(auth.authorization, option)
    assert_success void
    assert_equal 'successful void', void.params['message']
  end

  def test_failed_void
    # First successful void
    auth = @gateway.authorize(@amount, @credit_card, @authorize_void_options_success)
    assert_success auth

    option = {
      token_acquirer: @token_acquirer,
      trace_id: @authorize_capture_options_success[:trace_id],
      acquire_extra_options: {}
    }
    sleep(3)
    assert void = @gateway.void(auth.authorization, option)
    assert_success void
    assert_equal 'successful void', void.params['message']

    # Second failed void
    option = {
      token_acquirer: @token_acquirer,
      trace_id: '2717a3e0-0db2-4971-b94f-686d3b72c44b'
    }
    void = @gateway.void(auth.authorization, option)
    assert_failure void
    assert_equal 'VOID_REJECTED', void.params['message']
  end

  def test_successful_refund
    option = {
      token_acquirer: 'bd4c0f26-a357-4294-9b9e-a90e6c868c6e',
      trace_id: '23138123-321213',
      comment: 'Daniel Bernal',
      currency: 'PEN',
      acquire_extra_options: {
        ruc: '20202380621'
      }
    }

    assert refund = @gateway.refund(200, '936ca6a48a8b4cd3a3050bc637a5e2bc', option)
    assert_success refund
    assert_equal 'successful refund', refund.message
  end

  def test_failed_refund
    response = @gateway.purchase(@amount, @credit_card, @authorize_capture_options_success)
    option = {
      token_acquirer: @token_acquirer,
      trace_id: '2717a3e0-0db2-4971-b94f-686d3b72c44b',
      currency: 'USD',
      comment: 'This is a comment',
      acquire_extra_options: {
        ruc: '13431131234'
      }
    }
    sleep(3)
    refund = @gateway.refund(@amount, response.authorization, option)
    assert_failure refund
    assert_equal('REFUND_REJECTED', refund.params['message'])
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @authorize_capture_options_success)
    end
    transcript = @gateway.scrub(transcript)
    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, transcript)
  end

  private

  def setup_options
    setup_authorize_void_success_options()
    @authorize_capture_options_failed = {
      acquire_extra_options: {},
      trace_id: SecureRandom.uuid,
      user: {
        id: '123',
        email: 's@example.com'
      },
      order: {
        id: rand(100000000000..999999999999).to_s,
        description: 'a popsicle',
        installments: 1,
        amount: {
          currency: 'USD',
          vat: 19
        },
        shipping_address: {
          name: 'string',
          company: 'string',
          address1: 'string',
          address2: 'string',
          city: 'string',
          state: 'string',
          country: 'string',
          zip: 'string',
          phone: 'string'
        }
      },
      payment_method: {
        card: {
          name: 'string',
          company: 'string',
          address1: 'string',
          address2: 'string',
          city: 'string',
          state: 'string',
          country: 'string',
          zip: 'string',
          phone: 'string'
        }
      },
      authentication: {
        three_d_secure: {
          version: '2.1.0',
          eci: '05',
          cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA',
          ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC',
          acs_transaction_id: '13c701a3-5a88-4c45-89e9-ef65e50a8bf9',
          xid: '00000000000000000501',
          enrolled: 'string',
          cavv_algorithm: '1',
          directory_response_status: 'Y',
          authentication_response_status: 'Y',
          three_ds_server_trans_id: '24f701e3-9a85-4d45-89e9-af67e70d8fg8'
        }
      },
      sub_merchant: {
        "merchant_id": 'string',
        "extra_params": {},
        "mcc": 'string',
        "name": 'string',
        "address": 'string',
        "postal_code": 'string',
        "url": 'string',
        "phone_number": 'string'
      },
      token_acquirer: @token_acquirer
    }

    @authorize_capture_options_success = {
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
        installments: 1,
        amount: {
          currency: 'USD',
          vat: 19
        },
        shipping_address: {
          name: 'string',
          company: 'string',
          address1: 'string',
          address2: 'string',
          city: 'string',
          state: 'string',
          country: 'string',
          zip: 'string',
          phone: 'string'
        }
      },
      payment_method: {
        card: {
          billing_address: {
            name: 'string',
            company: 'string',
            address1: 'string',
            address2: 'string',
            city: 'string',
            state: 'string',
            country: 'string',
            zip: 'string',
            phone: 'string'
          }
        }
      },
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
      sub_merchant: {
        address: 'None',
        extra_params: {
        },
        mcc: '5816',
        merchant_id: '400000008',
        name: '885.519.237',
        phone_number: '3434343',
        postal_code: 'None',
        url: 'string'
      },
      psp_info: {
        id: '0123',
        name: 'mci',
        sub_merchant: {
          id: 'string',
          name: 'string'
        }

      },
      token_acquirer: @token_acquirer
    }
  end

  def setup_authorize_void_success_options
    @authorize_void_options_success = {
      acquire_extra_options: {},
      trace_id: SecureRandom.uuid,
      user: {
        id: '123',
        email: 's@example.com'
      },
      order: {
        id: rand(100000000000..999999999999).to_s,
        description: 'apopsicle',
        installments: 1,
        datetime_local_transaction: Time.new.strftime('%Y-%m-%dT%H:%M:%S.%L%:z'),
        amount: {
          currency: 'USD',
          vat: 19
        },
        shipping_address: {
          name: 'string',
          company: 'string',
          address1: 'string',
          address2: 'string',
          city: 'string',
          state: 'string',
          country: 'string',
          zip: 'string',
          phone: 'string'
        }
      },
      payment_method: {
        card: {
          billing_address: {
            name: 'string',
            company: 'string',
            address1: 'string',
            address2: 'string',
            city: 'string',
            state: 'string',
            country: 'string',
            zip: 'string',
            phone: 'string'
          }
        }
      },
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
      sub_merchant: {
        address: 'None',
        extra_params: {
        },
        mcc: '5816',
        merchant_id: '400000008',
        name: '885.519.237',
        phone_number: '3434343',
        postal_code: 'None',
        url: 'string'
      },
      psp_info: {
        id: '0123',
        name: 'mci',
        sub_merchant: {
          id: 'string',
          name: 'string'
        }

      },
      token_acquirer: @token_acquirer
    }
  end
end
