require 'test_helper'

class CredoraxTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CredoraxGateway.new(merchant_id: 'login', cipher_key: 'password')
    @credit_card = credit_card
    @amount = 100

    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }

    @normalized_3ds_2_options = {
      reference: '345123',
      shopper_email: 'john.smith@test.com',
      shopper_ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      billing_address: address,
      shipping_address: address,
      order_id: '123',
      execute_threed: true,
      three_ds_initiate: '03',
      f23: '1',
      three_ds_reqchallengeind: '04',
      three_ds_challenge_window_size: '01',
      stored_credential: { reason_type: 'unscheduled' },
      three_ds_2: {
        channel: 'browser',
        notification_url: 'www.example.com',
        browser_info: {
          accept_header: 'unknown',
          depth: 100,
          java: false,
          language: 'US',
          height: 1000,
          width: 500,
          timezone: '-120',
          user_agent: 'unknown'
        }
      }
    }

    @nt_credit_card = network_tokenization_credit_card(
      '4176661000001015',
      brand: 'visa',
      eci: '07',
      source: :network_token,
      payment_cryptogram: 'AgAAAAAAosVKVV7FplLgQRYAAAA='
    )

    @apple_pay_card = network_tokenization_credit_card(
      '4176661000001015',
      month: 10,
      year: Time.new.year + 2,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      payment_cryptogram: 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      eci: '07',
      transaction_id: 'abc123',
      source: :apple_pay
    )
  end

  def test_supported_card_types
    klass = @gateway.class
    assert_equal %i[visa master maestro american_express jcb discover diners_club], klass.supported_cardtypes
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |_endpoint, data, _headers|
      assert_no_match(/i8=sample-eci%3Asample-cavv%3Asample-xid/, data)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal '8a82944a5351570601535955efeb513c;006596;02617cf5f02ccaed239b6521748298c5;purchase', response.authorization
    assert_equal 'Succeeded', response.message
    assert response.test?
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert_equal 'Transaction not allowed for cardholder', response.message
    assert response.test?
  end

  def test_successful_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal '8a829449535154bc0153595952a2517a;006597;90f7449d555f7bed0a2c5d780475f0bf;authorize', response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/8a829449535154bc0153595952a2517a/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
    assert_equal 'Succeeded', response.message
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal 'Transaction not allowed for cardholder', response.message
    assert response.test?
  end

  def test_failed_capture
    response = stub_comms do
      @gateway.capture(100, '')
    end.respond_with(failed_capture_response)

    assert_failure response
    assert_equal '2. At least one of input parameters is malformed.: Parameter [g4] cannot be empty.', response.message
  end

  def test_successful_void
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal '8a829449535154bc0153595952a2517a;006597;90f7449d555f7bed0a2c5d780475f0bf;purchase', response.authorization

    void = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/8a829449535154bc0153595952a2517a/, data)
    end.respond_with(successful_void_response)

    assert_success void
    assert_equal 'Succeeded', void.message
  end

  def test_failed_void
    response = stub_comms do
      @gateway.void('5d53a33d960c46d00f5dc061947d998c')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/5d53a33d960c46d00f5dc061947d998c/, data)
    end.respond_with(failed_void_response)

    assert_failure response
    assert_equal '2. At least one of input parameters is malformed.: Parameter [g4] cannot be empty.', response.message
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal '8a82944a5351570601535955efeb513c;006596;02617cf5f02ccaed239b6521748298c5;purchase', response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/8a82944a5351570601535955efeb513c/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
    assert_equal 'Succeeded', refund.message
  end

  def test_successful_refund_with_recipient_fields
    refund_options = {
      recipient_street_address: 'street',
      recipient_city: 'chicago',
      recipient_province_code: '312',
      recipient_country_code: 'US'
    }
    refund = stub_comms do
      @gateway.refund(@amount, '123', refund_options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/j6=street/, data)
      assert_match(/j7=chicago/, data)
      assert_match(/j8=312/, data)
      assert_match(/j9=USA/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(nil, '')
    end.respond_with(failed_refund_response)

    assert_failure response
    assert_equal '2. At least one of input parameters is malformed.: Parameter [g4] cannot be empty.', response.message
  end

  def test_successful_referral_cft
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal '8a82944a5351570601535955efeb513c;006596;02617cf5f02ccaed239b6521748298c5;purchase', response.authorization

    referral_cft = stub_comms do
      @gateway.refund(@amount, response.authorization, { referral_cft: true, first_name: 'John', last_name: 'Smith' })
    end.check_request do |_endpoint, data, _headers|
      assert_match(/8a82944a5351570601535955efeb513c/, data)
      # Confirm that `j5` (first name) and `j13` (surname) parameters are present
      # These fields are required for CFT payouts as of Sept 1, 2020
      assert_match(/j5=John/, data)
      assert_match(/j13=Smith/, data)
      # Confirm that the transaction type is `referral_cft`
      assert_match(/O=34/, data)
    end.respond_with(successful_referral_cft_response)

    assert_success referral_cft
    assert_equal 'Succeeded', referral_cft.message
  end

  def test_failed_referral_cft
    response = stub_comms do
      @gateway.refund(nil, '', referral_cft: true)
    end.check_request do |_endpoint, data, _headers|
      # Confirm that the transaction type is `referral_cft`
      assert_match(/O=34/, data)
    end.respond_with(failed_referral_cft_response)

    assert_failure response
    assert_equal 'Referred to transaction has not been found.', response.message
  end

  def test_successful_credit
    response = stub_comms do
      @gateway.credit(@amount, @credit_card)
    end.respond_with(successful_credit_response)

    assert_success response

    assert_equal '8a82944a53515706015359604c135301;;868f8b942fae639d28e27e8933d575d4;credit', response.authorization
    assert_equal 'Succeeded', response.message
    assert response.test?
  end

  def test_credit_sends_correct_action_code
    stub_comms do
      @gateway.credit(@amount, @credit_card)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/O=35/, data)
    end.respond_with(successful_credit_response)
  end

  def test_credit_sends_customer_name
    stub_comms do
      @gateway.credit(@amount, @credit_card, { first_name: 'Test', last_name: 'McTest' })
    end.check_request do |_endpoint, data, _headers|
      assert_match(/j5=Test/, data)
      assert_match(/j13=McTest/, data)
    end.respond_with(successful_credit_response)
  end

  def test_failed_credit
    response = stub_comms do
      @gateway.credit(@amount, @credit_card)
    end.respond_with(failed_credit_response)

    assert_failure response
    assert_equal 'Transaction not allowed for cardholder', response.message
    assert response.test?
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
    assert_equal 'Transaction not allowed for cardholder', response.message
  end

  def test_empty_response_fails
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(empty_purchase_response)

    assert_failure response
    assert_equal 'Unable to read error message', response.message
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  def test_adds_3d2_secure_fields
    options_with_3ds = @normalized_3ds_2_options

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/3ds_channel=02/, data)
      assert_match(/3ds_transtype=01/, data)
      assert_match(/3ds_initiate=03/, data)
      assert_match(/f23=1/, data)
      assert_match(/3ds_reqchallengeind=04/, data)
      assert_match(/3ds_redirect_url=www.example.com/, data)
      assert_match(/3ds_challengewindowsize=01/, data)
      assert_match(/d5=unknown/, data)
      assert_match(/3ds_browsertz=-120/, data)
      assert_match(/3ds_browserscreenwidth=500/, data)
      assert_match(/3ds_browserscreenheight=1000/, data)
      assert_match(/3ds_browsercolordepth=100/, data)
      assert_match(/d6=US/, data)
      assert_match(/3ds_browserjavaenabled=false/, data)
      assert_match(/3ds_browseracceptheader=unknown/, data)
      assert_match(/3ds_shipaddrstate=ON/, data)
      assert_match(/3ds_shipaddrpostcode=K1C2N6/, data)
      assert_match(/3ds_shipaddrline2=Apt\+1/, data)
      assert_match(/3ds_shipaddrline1=456\+My\+Street/, data)
      assert_match(/3ds_shipaddrcountry=CA/, data)
      assert_match(/3ds_shipaddrcity=Ottawa/, data)
      refute_match(/3ds_version/, data)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal '8a82944a5351570601535955efeb513c;006596;02617cf5f02ccaed239b6521748298c5;purchase', response.authorization
    assert response.test?
  end

  def test_does_not_add_incomplete_3d2_shipping_address
    incomplete_shipping_address = {
      state: 'ON',
      zip: 'K1C2N6',
      address1: '456 My Street',
      address2: '',
      country: 'CA',
      city: 'Ottawa'
    }
    options_with_3ds = @normalized_3ds_2_options.merge(shipping_address: incomplete_shipping_address)

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/3ds_initiate=03/, data)
      assert_not_match(/3ds_shipaddrstate=/, data)
      assert_not_match(/3ds_shipaddrpostcode=/, data)
      assert_not_match(/3ds_shipaddrline1=/, data)
      assert_not_match(/3ds_shipaddrline2=/, data)
      assert_not_match(/3ds_shipaddrcountry=/, data)
      assert_not_match(/3ds_shipaddrcity=/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
    assert response.test?
  end

  def test_adds_correct_3ds_browsercolordepth_when_color_depth_is_30
    @normalized_3ds_2_options[:three_ds_2][:browser_info][:depth] = 30

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @normalized_3ds_2_options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/3ds_browsercolordepth=32/, data)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal '8a82944a5351570601535955efeb513c;006596;02617cf5f02ccaed239b6521748298c5;purchase', response.authorization
    assert response.test?
  end

  def test_adds_3d2_secure_fields_with_3ds_transtype_specified
    options_with_3ds = @normalized_3ds_2_options.merge(three_ds_transtype: '03')

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/3ds_channel=02/, data)
      assert_match(/3ds_transtype=03/, data)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal '8a82944a5351570601535955efeb513c;006596;02617cf5f02ccaed239b6521748298c5;purchase', response.authorization
    assert response.test?
  end

  def test_purchase_adds_3d_secure_fields
    options_with_3ds = @options.merge({ eci: 'sample-eci', cavv: 'sample-cavv', xid: 'sample-xid', three_ds_version: '1.0.2' })

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/i8=sample-eci%3Asample-cavv%3Asample-xid/, data)
      assert_match(/3ds_version=1.0&/, data)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal '8a82944a5351570601535955efeb513c;006596;02617cf5f02ccaed239b6521748298c5;purchase', response.authorization
    assert response.test?
  end

  def test_purchase_adds_3d_secure_fields_via_normalized_hash
    version = '1.0.2'
    eci = 'sample-eci'
    cavv = 'sample-cavv'
    xid = 'sample-xid'
    options_with_normalized_3ds = @options.merge(
      three_d_secure: {
        version: version,
        eci: eci,
        cavv: cavv,
        xid: xid
      }
    )

    stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_normalized_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/i8=#{eci}%3A#{cavv}%3A#{xid}/, data)
      assert_match(/3ds_version=1.0&/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_3ds_channel_field_set_by_stored_credential_initiator
    options_with_3ds = @normalized_3ds_2_options.merge(stored_credential_options(:merchant, :unscheduled, id: 'abc123'))

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/3ds_channel=03/, data)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal '8a82944a5351570601535955efeb513c;006596;02617cf5f02ccaed239b6521748298c5;purchase', response.authorization
    assert response.test?
  end

  def test_authorize_adds_3d_secure_fields
    options_with_3ds = @options.merge({ eci: 'sample-eci', cavv: 'sample-cavv', xid: 'sample-xid' })

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options_with_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/i8=sample-eci%3Asample-cavv%3Asample-xid/, data)
      assert_match(/3ds_version=1.0/, data)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal '8a82944a5351570601535955efeb513c;006596;02617cf5f02ccaed239b6521748298c5;authorize', response.authorization
    assert response.test?
  end

  def test_defaults_3d_secure_cavv_field_to_none_if_not_present
    options_with_3ds = @options.merge({ eci: 'sample-eci', xid: 'sample-xid' })

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/i8=sample-eci%3Anone%3Asample-xid/, data)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal '8a82944a5351570601535955efeb513c;006596;02617cf5f02ccaed239b6521748298c5;purchase', response.authorization
    assert response.test?
  end

  def test_adds_3ds2_fields_via_normalized_hash
    version = '2'
    eci = '05'
    cavv = '637574652070757070792026206b697474656e73'
    ds_transaction_id = '97267598-FAE6-48F2-8083-C23433990FBC'
    options_with_normalized_3ds = @options.merge(
      three_d_secure: {
        version: version,
        eci: eci,
        cavv: cavv,
        ds_transaction_id: ds_transaction_id
      }
    )

    stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_normalized_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/i8=#{eci}%3A#{cavv}%3Anone/, data)
      assert_match(/3ds_version=2/, data)
      assert_match(/3ds_dstrxid=#{ds_transaction_id}/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_adds_default_cavv_when_omitted_from_normalized_hash
    version = '2.2.0'
    eci = '05'
    ds_transaction_id = '97267598-FAE6-48F2-8083-C23433990FBC'
    options_with_normalized_3ds = @options.merge(
      three_d_secure: {
        version: version,
        eci: eci,
        ds_transaction_id: ds_transaction_id
      }
    )

    stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_normalized_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/i8=#{eci}%3Anone%3Anone/, data)
      assert_match(/3ds_version=2.2.0/, data)
      assert_match(/3ds_dstrxid=#{ds_transaction_id}/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_adds_a9_field
    options_with_3ds = @options.merge({ transaction_type: '8' })
    stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a9=8/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_authorize_adds_a9_field
    options_with_3ds = @options.merge({ transaction_type: '8' })
    stub_comms do
      @gateway.authorize(@amount, @credit_card, options_with_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a9=8/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_credit_adds_a9_field
    options_with_3ds = @options.merge({ transaction_type: '8' })
    stub_comms do
      @gateway.credit(@amount, @credit_card, options_with_3ds)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a9=8/, data)
    end.respond_with(successful_credit_response)
  end

  def test_authorize_adds_authorization_details
    options_with_auth_details = @options.merge({ authorization_type: '2', multiple_capture_count: '5' })
    stub_comms do
      @gateway.authorize(@amount, @credit_card, options_with_auth_details)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a10=2/, data)
      assert_match(/a11=5/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_purchase_adds_submerchant_id
    @options[:submerchant_id] = '12345'
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/h3=12345/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_adds_moto_a2_field
    @options[:metadata] = { manual_entry: true }
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a2=3/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_authorize_adds_submerchant_id
    @options[:submerchant_id] = '12345'
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/h3=12345/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_capture_adds_submerchant_id
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    @options[:submerchant_id] = '12345'
    stub_comms do
      @gateway.capture(@amount, response.authorization, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/h3=12345/, data)
    end.respond_with(successful_capture_response)
  end

  def test_void_adds_submerchant_id
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    @options[:submerchant_id] = '12345'
    stub_comms do
      @gateway.void(response.authorization, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/h3=12345/, data)
    end.respond_with(successful_void_response)
  end

  def test_refund_adds_submerchant_id
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    @options[:submerchant_id] = '12345'
    stub_comms do
      @gateway.refund(@amount, response.authorization, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/h3=12345/, data)
    end.respond_with(successful_refund_response)
  end

  def test_credit_adds_submerchant_id
    @options[:submerchant_id] = '12345'
    stub_comms do
      @gateway.credit(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/h3=12345/, data)
    end.respond_with(successful_credit_response)
  end

  def test_purchase_adds_billing_descriptor
    @options[:billing_descriptor] = 'abcdefghijkl'
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/i2=abcdefghijkl/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_authorize_adds_billing_descriptor
    @options[:billing_descriptor] = 'abcdefghijkl'
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/i2=abcdefghijkl/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_capture_adds_billing_descriptor
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    @options[:billing_descriptor] = 'abcdefghijkl'
    stub_comms do
      @gateway.capture(@amount, response.authorization, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/i2=abcdefghijkl/, data)
    end.respond_with(successful_capture_response)
  end

  def test_refund_adds_billing_descriptor
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    @options[:billing_descriptor] = 'abcdefghijkl'
    stub_comms do
      @gateway.refund(@amount, response.authorization, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/i2=abcdefghijkl/, data)
    end.respond_with(successful_refund_response)
  end

  def test_credit_adds_billing_descriptor
    @options[:billing_descriptor] = 'abcdefghijkl'
    stub_comms do
      @gateway.credit(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/i2=abcdefghijkl/, data)
    end.respond_with(successful_credit_response)
  end

  def test_purchase_adds_processor_fields
    @options[:processor] = 'TEST'
    @options[:processor_merchant_id] = '123'
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/r1=TEST/, data)
      assert_match(/r2=123/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_authorize_adds_processor_fields
    @options[:processor] = 'TEST'
    @options[:processor_merchant_id] = '123'
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/r1=TEST/, data)
      assert_match(/r2=123/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_capture_adds_processor_fields
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    @options[:processor] = 'TEST'
    @options[:processor_merchant_id] = '123'
    stub_comms do
      @gateway.capture(@amount, response.authorization, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/r1=TEST/, data)
      assert_match(/r2=123/, data)
    end.respond_with(successful_capture_response)
  end

  def test_void_adds_processor_fields
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    @options[:processor] = 'TEST'
    @options[:processor_merchant_id] = '123'
    stub_comms do
      @gateway.void(response.authorization, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/r1=TEST/, data)
      assert_match(/r2=123/, data)
    end.respond_with(successful_void_response)
  end

  def test_refund_adds_processor_fields
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    @options[:processor] = 'TEST'
    @options[:processor_merchant_id] = '123'
    stub_comms do
      @gateway.refund(@amount, response.authorization, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/r1=TEST/, data)
      assert_match(/r2=123/, data)
    end.respond_with(successful_refund_response)
  end

  def test_credit_adds_processor_fields
    @options[:processor] = 'TEST'
    @options[:processor_merchant_id] = '123'
    stub_comms do
      @gateway.credit(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/r1=TEST/, data)
      assert_match(/r2=123/, data)
    end.respond_with(successful_credit_response)
  end

  def test_purchase_adds_echo_field
    @options[:echo] = 'Echo Parameter'
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/d2=Echo\+Parameter/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_authorize_adds_echo_field
    @options[:echo] = 'Echo Parameter'
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/d2=Echo\+Parameter/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_capture_adds_echo_field
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    @options[:echo] = 'Echo Parameter'
    stub_comms do
      @gateway.capture(@amount, response.authorization, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/d2=Echo\+Parameter/, data)
    end.respond_with(successful_capture_response)
  end

  def test_void_adds_echo_field
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    @options[:echo] = 'Echo Parameter'
    stub_comms do
      @gateway.void(response.authorization, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/d2=Echo\+Parameter/, data)
    end.respond_with(successful_void_response)
  end

  def test_refund_adds_echo_field
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    @options[:echo] = 'Echo Parameter'
    stub_comms do
      @gateway.refund(@amount, response.authorization, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/d2=Echo\+Parameter/, data)
    end.respond_with(successful_refund_response)
  end

  def test_credit_adds_echo_field
    @options[:echo] = 'Echo Parameter'
    stub_comms do
      @gateway.credit(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/d2=Echo\+Parameter/, data)
    end.respond_with(successful_credit_response)
  end

  def test_purchase_omits_phone_when_nil
    # purchase passes the phone number when provided
    @options[:billing_address][:phone] = '555-444-3333'
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/c2=555-444-3333/, data)
    end.respond_with(successful_purchase_response)

    # purchase doesn't pass the phone number when nil
    @options[:billing_address][:phone] = nil
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_not_match(/c2=/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_omits_3ds_homephonecountry_when_phone_is_nil
    # purchase passes 3ds_homephonecountry when it and phone number are provided
    @options[:billing_address][:phone] = '555-444-3333'
    @options[:three_ds_2] = { optional: { '3ds_homephonecountry': 'US' } }
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/c2=555-444-3333/, data)
      assert_match(/3ds_homephonecountry=US/, data)
    end.respond_with(successful_purchase_response)

    # purchase doesn't pass 3ds_homephonecountry when phone number is nil
    @options[:billing_address][:phone] = nil
    @options[:three_ds_2] = { optional: { '3ds_homephonecountry': 'US' } }
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_not_match(/c2=/, data)
      assert_not_match(/3ds_homephonecountry=/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_stored_credential_recurring_cit_initial
    options = stored_credential_options(:cardholder, :recurring, :initial)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a9=9/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_stored_credential_recurring_cit_used
    options = stored_credential_options(:cardholder, :recurring, id: 'abc123')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a9=9/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_stored_credential_recurring_mit_initial
    options = stored_credential_options(:merchant, :recurring, :initial)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a9=1/, data)
    end.respond_with(successful_authorize_response)
    assert_match(/z50=abc123/, successful_authorize_response)
    assert_success response
  end

  def test_stored_credential_recurring_mit_used
    options = stored_credential_options(:merchant, :recurring, id: 'abc123')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a9=2/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_stored_credential_installment_cit_initial
    options = stored_credential_options(:cardholder, :installment, :initial)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a9=9/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_stored_credential_installment_cit_used
    options = stored_credential_options(:cardholder, :installment, id: 'abc123')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a9=9/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_stored_credential_installment_mit_initial
    options = stored_credential_options(:merchant, :installment, :initial)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a9=8/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_stored_credential_installment_mit_used
    options = stored_credential_options(:merchant, :installment, id: 'abc123')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a9=8/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_stored_credential_unscheduled_cit_initial
    options = stored_credential_options(:cardholder, :unscheduled, :initial)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a9=9/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_stored_credential_unscheduled_cit_used
    options = stored_credential_options(:cardholder, :unscheduled, id: 'abc123')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a9=9/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_stored_credential_unscheduled_mit_initial
    options = stored_credential_options(:merchant, :unscheduled, :initial)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a9=8/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_stored_credential_unscheduled_mit_used
    options = stored_credential_options(:merchant, :unscheduled, id: 'abc123')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a9=8/, data)
      assert_match(/g6=abc123/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_purchase_with_stored_credential
    options = stored_credential_options(:merchant, :recurring, id: 'abc123')
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a9=2/, data)
      assert_match(/g6=abc123/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_add_transaction_type_overrides_stored_credential_option
    options = stored_credential_options(:merchant, :unscheduled, id: 'abc123').merge(transaction_type: '6')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a9=6/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_nonfractional_currency_handling
    stub_comms do
      @gateway.authorize(200, @credit_card, @options.merge(currency: 'ISK'))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a4=2&a1=/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_3ds_2_optional_fields_adds_fields_to_the_root_of_the_post
    post = {}
    options = { three_ds_2: { optional: { '3ds_optional_field_1': :a, '3ds_optional_field_2': :b } } }

    @gateway.add_3ds_2_optional_fields(post, options)

    assert_equal post, { '3ds_optional_field_1': :a, '3ds_optional_field_2': :b }
  end

  def test_3ds_2_optional_fields_does_not_overwrite_fields
    post = { '3ds_optional_field_1': :existing_value }
    options = { three_ds_2: { optional: { '3ds_optional_field_1': :a, '3ds_optional_field_2': :b } } }

    @gateway.add_3ds_2_optional_fields(post, options)

    assert_equal post, { '3ds_optional_field_1': :existing_value, '3ds_optional_field_2': :b }
  end

  def test_3ds_2_optional_fields_does_not_empty_fields
    post = {}
    options = { three_ds_2: { optional: { '3ds_optional_field_1': '', '3ds_optional_field_2': 'null', '3ds_optional_field_3': nil } } }

    @gateway.add_3ds_2_optional_fields(post, options)

    assert_equal post, {}
  end

  def test_successful_purchase_with_network_token
    response = stub_comms do
      @gateway.purchase(@amount, @nt_credit_card)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/b21=vts_mdes_token&token_eci=07&token_crypto=AgAAAAAAosVKVV7FplLgQRYAAAA%3D/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_successful_purchase_with_other_than_network_token
    response = stub_comms do
      @gateway.purchase(@amount, @apple_pay_card)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/b21=applepay/, data)
      assert_match(/token_eci=07/, data)
      assert_not_match(/token_crypto=/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  private

  def stored_credential_options(*args, id: nil)
    {
      order_id: '#1001',
      description: 'AM test',
      currency: 'GBP',
      customer: '123',
      stored_credential: stored_credential(*args, id: id)
    }
  end

  def successful_purchase_response
    'M=SPREE978&O=1&T=03%2F09%2F2016+03%3A05%3A16&V=413&a1=02617cf5f02ccaed239b6521748298c5&a2=2&a4=100&a9=6&z1=8a82944a5351570601535955efeb513c&z13=606944188282&z14=U&z15=100&z2=0&z3=Transaction+has+been+executed+successfully.&z4=006596&z5=0&z6=00&z9=X&K=057e123af2fba5a37b4df76a7cb5cfb6'
  end

  def failed_purchase_response
    'M=SPREE978&O=1&T=03%2F09%2F2016+03%3A05%3A47&V=413&a1=92176aca194ceafdb4a679389b77f207&a2=2&a4=100&a9=6&z1=8a82944a535157060153595668fd5162&z13=606944188283&z15=100&z2=05&z3=Transaction+has+been+declined.&z5=0&z6=57&K=2d44820a5a907ff820f928696e460ce1'
  end

  def successful_authorize_response
    'M=SPREE978&O=2&T=03%2F09%2F2016+03%3A08%3A58&V=413&a1=90f7449d555f7bed0a2c5d780475f0bf&a2=2&a4=100&a9=6&z1=8a829449535154bc0153595952a2517a&z13=606944188284&z14=U&z15=100&z2=0&z3=Transaction+has+been+executed+successfully.&z4=006597&z5=0&z6=00&z9=X&K=00effd2c80ab7ecd45b499c0bbea3d20z50=abc123'
  end

  def failed_authorize_response
    'M=SPREE978&O=2&T=03%2F09%2F2016+03%3A10%3A02&V=413&a1=9bd85e23639ffcd5206f8e7fe4e3d365&a2=2&a4=100&a9=6&z1=8a829449535154bc0153595a4bb051ac&z13=606944188285&z15=100&z2=05&z3=Transaction+has+been+declined.&z5=0&z6=57&K=2fe3ee6b975d1e4ba542c1e7549056f6'
  end

  def successful_capture_response
    'M=SPREE978&O=3&T=03%2F09%2F2016+03%3A09%3A03&V=413&a1=2a349969e0ed61fb0db59fc9f32d2fb3&a2=2&a4=100&g2=8a829449535154bc0153595952a2517a&g3=006597&g4=90f7449d555f7bed0a2c5d780475f0bf&z1=8a82944a535157060153595966ba51f9&z13=606944188284&z15=100&z2=0&z3=Transaction+has+been+executed+successfully.&z4=006597&z5=0&z6=00&K=4ad979199490a8d000302735220edfa6'
  end

  def failed_capture_response
    'M=SPREE978&O=3&T=03%2F09%2F2016+03%3A10%3A33&V=413&a1=eed7c896e1355dc4007c0c8df44d5852&a2=2&a4=100&a5=EUR&b1=-&z1=1A-1&z2=-9&z3=2.+At+least+one+of+input+parameters+is+malformed.%3A+Parameter+%5Bg4%5D+cannot+be+empty.&K=8d1d8f2f9feeb7909aa3e6c428903d57'
  end

  def successful_void_response
    'M=SPREE978&O=4&T=03%2F09%2F2016+03%3A11%3A11&V=413&a1=&a2=2&a4=100&g2=8a82944a535157060153595b484a524d&g3=006598&g4=0d600bf50198059dbe61979f8c28aab2&z1=8a829449535154bc0153595b57c351d2&z13=606944188287&z15=100&z2=0&z3=Transaction+has+been+executed+successfully.&z4=006598&z5=0&z6=00&K=e643b9e88b35fd69d5421b59c611a6c9'
  end

  def failed_void_response
    'M=SPREE978&O=4&T=03%2F09%2F2016+03%3A11%3A37&V=413&a1=-&a2=2&a4=-&a5=-&b1=-&z1=1A-1&z2=-9&z3=2.+At+least+one+of+input+parameters+is+malformed.%3A+Parameter+%5Bg4%5D+cannot+be+empty.&K=1e6683cd7b1d01712f12ce7bfc9a5ad2'
  end

  def successful_refund_response
    'M=SPREE978&O=5&T=03%2F09%2F2016+03%3A15%3A32&V=413&a1=b449bb41af3eb09fd483e7629eb2266f&a2=2&a4=100&g2=8a82944a535157060153595f3ea352c2&g3=006600&g4=78141b277cfadba072a0bcb90745faef&z1=8a82944a535157060153595f553a52de&z13=606944188288&z15=100&z2=0&z3=Transaction+has+been+executed+successfully.&z4=006600&z5=0&z6=00&K=bfdfd8b0dcee974c07c3c85cfea753fe'
  end

  def failed_refund_response
    'M=SPREE978&O=5&T=03%2F09%2F2016+03%3A16%3A06&V=413&a1=c2b481deffe0e27bdef1439655260092&a2=2&a4=-&a5=EUR&b1=-&z1=1A-1&z2=-9&z3=2.+At+least+one+of+input+parameters+is+malformed.%3A+Parameter+%5Bg4%5D+cannot+be+empty.&K=c2f6112b40c61859d03684ac8e422766'
  end

  def successful_referral_cft_response
    'M=SPREE978&O=34&T=11%2F15%2F2019+15%3A56%3A08&V=413&a1=e852c517da0ffb0cde45671b39165449&a2=2&a4=100&a9=9&b2=2&g2=XZZ72c3228fc3b58525STV56T7YMFAJB&z1=XZZ72e64209459e8C2BAMTBS65MCNGIF&z13=931924132623&z2=0&z3=Transaction+has+been+executed+successfully.&z33=CREDORAX&z34=59990010&z39=XZZ72e64209459e8C2BAMTBS65MCNGIF&z4=HOSTOK&z6=00&K=76f8a35c3357a7613d63438bd86c06d9'
  end

  def failed_referral_cft_response
    'T=11%2F15%2F2019+17%3A17%3A45&a1=896ffaf13766fff647d863e8ab0a707c&z1=XZZ7246087744e7993DRONGBWN4RNFWJ&z2=-9&z3=Referred+to+transaction+has+not+been+found.'
  end

  def successful_credit_response
    'M=SPREE978&O=35&T=03%2F09%2F2016+03%3A16%3A35&V=413&a1=868f8b942fae639d28e27e8933d575d4&a2=2&a4=100&z1=8a82944a53515706015359604c135301&z13=606944188289&z15=100&z2=0&z3=Transaction+has+been+executed+successfully.&z5=0&z6=00&K=51ba24f6ef3aa161f86e53c34c9616ac'
  end

  def failed_credit_response
    'M=SPREE978&O=35&T=03%2F09%2F2016+03%3A16%3A59&V=413&a1=ff28246cfc811b1c686a52d08d075d9c&a2=2&a4=100&z1=8a829449535154bc01535960a962524f&z13=606944188290&z15=100&z2=05&z3=Transaction+has+been+declined.&z5=0&z6=57&K=cf34816d5c25dc007ef3525505c4c610'
  end

  def empty_purchase_response
    %(
    )
  end

  def transcript
    %(
        opening connection to intconsole.credorax.com:443...
        opened
        starting SSL for intconsole.credorax.com:443...
        SSL established
        <- "POST /intenv/service/gateway HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: intconsole.credorax.com\r\nContent-Length: 264\r\n\r\n"
        <- "a4=100&a1=335ebb08c489e6d361108a7eb7d8b92a&a5=EUR&c1=Longbob+Longsen&b2=1&b1=5223450000000007&b5=090&b4=25&b3=12&d1=127.0.0.1&c3=unspecified%40example.com&c5=456+My+StreetApt+1&c7=Ottawa&c10=K1C2N6&c2=+555+555-5555&M=SPREE978&O=1&K=ef26476215cee15664e75d979d33935b"
        -> "HTTP/1.1 200 OK\r\n"
        -> "Date: Wed, 09 Mar 2016 03:03:00 GMT\r\n"
        -> "Content-Type: application/x-www-form-urlencoded\r\n"
        -> "Content-Length: 283\r\n"
        -> "Connection: close\r\n"
        -> "\r\n"
        reading 283 bytes...
        -> "M=SPREE978&O=1&T=03%2F09%2F2016+03%3A03%3A01&V=413&a1=335ebb08c489e6d361108a7eb7d8b92a&a2=2&a4=100&a9=6&z1=8a829449535154bc01535953dd235043&z13=606944188276&z14=U&z15=100&z2=0&z3=Transaction+has+been+executed+successfully.&z4=006592&z5=0&z6=00&z9=X&K=4061e16f39915297827af1586635015a"
        read 283 bytes
        Conn close
    )
  end

  def scrubbed_transcript
    %(
        opening connection to intconsole.credorax.com:443...
        opened
        starting SSL for intconsole.credorax.com:443...
        SSL established
        <- "POST /intenv/service/gateway HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: intconsole.credorax.com\r\nContent-Length: 264\r\n\r\n"
        <- "a4=100&a1=335ebb08c489e6d361108a7eb7d8b92a&a5=EUR&c1=Longbob+Longsen&b2=1&b1=[FILTERED]&b5=[FILTERED]&b4=25&b3=12&d1=127.0.0.1&c3=unspecified%40example.com&c5=456+My+StreetApt+1&c7=Ottawa&c10=K1C2N6&c2=+555+555-5555&M=SPREE978&O=1&K=ef26476215cee15664e75d979d33935b"
        -> "HTTP/1.1 200 OK\r\n"
        -> "Date: Wed, 09 Mar 2016 03:03:00 GMT\r\n"
        -> "Content-Type: application/x-www-form-urlencoded\r\n"
        -> "Content-Length: 283\r\n"
        -> "Connection: close\r\n"
        -> "\r\n"
        reading 283 bytes...
        -> "M=SPREE978&O=1&T=03%2F09%2F2016+03%3A03%3A01&V=413&a1=335ebb08c489e6d361108a7eb7d8b92a&a2=2&a4=100&a9=6&z1=8a829449535154bc01535953dd235043&z13=606944188276&z14=U&z15=100&z2=0&z3=Transaction+has+been+executed+successfully.&z4=006592&z5=0&z6=00&z9=X&K=4061e16f39915297827af1586635015a"
        read 283 bytes
        Conn close
    )
  end
end
