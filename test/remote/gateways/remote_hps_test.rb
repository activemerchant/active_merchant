require 'test_helper'

class RemoteHpsTest < Test::Unit::TestCase
  def setup
    @gateway = HpsGateway.new(fixtures(:hps))

    @amount = 100
    @declined_amount = 1034
    @credit_card =   credit_card('4000100011112224')

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_without_cardholder
    response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_details
    @options[:description] = 'Description'
    @options[:order_id] = '12345'
    @options[:customer_id] = '654321'

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_descriptor
    response = @gateway.purchase(@amount, @credit_card, @options.merge(descriptor_name: 'Location Name'))
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_no_address
    options = {
      order_id: '1',
      description: 'Store Purchase'
    }
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_instance_of Response, response
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The card was declined.', response.message
  end

  def test_successful_authorize_with_details
    @options[:description] = 'Description'
    @options[:order_id] = '12345'
    @options[:customer_id] = '654321'

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture
  end

  def test_successful_authorize_no_address
    options = {
      order_id: '1',
      description: 'Store Authorize'
    }
    response = @gateway.authorize(@amount, @credit_card, options)
    assert_instance_of Response, response
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@declined_amount, @credit_card, @options)
    assert_failure response
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(nil, '')
    assert_failure response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Success', refund.params['GatewayRspMsg']
    assert_equal '0', refund.params['GatewayRspCode']
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
    assert_equal 'Success', refund.params['GatewayRspMsg']
    assert_equal '0', refund.params['GatewayRspCode']
  end

  def test_failed_refund
    response = @gateway.refund(nil, '')
    assert_failure response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Success', void.params['GatewayRspMsg']
  end

  def test_failed_void
    response = @gateway.void('123')
    assert_failure response
    assert_match %r{rejected}i, response.message
  end

  def test_empty_login
    gateway = HpsGateway.new(secret_api_key: '')
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Authentication error. Please double check your service configuration.', response.message
  end

  def test_nil_login
    gateway = HpsGateway.new(secret_api_key: nil)
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Authentication error. Please double check your service configuration.', response.message
  end

  def test_invalid_login
    gateway = HpsGateway.new(secret_api_key: 'Bad_API_KEY')
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Authentication error. Please double check your service configuration.', response.message
  end

  def test_successful_get_token_from_auth
    response = @gateway.authorize(@amount, @credit_card, @options.merge(store: true))

    assert_success response
    assert_equal 'Visa', response.params['CardType']
    assert_equal 'Success', response.params['TokenRspMsg']
    assert_not_nil response.params['TokenValue']
  end

  def test_successful_get_token_from_purchase
    response = @gateway.purchase(@amount, @credit_card, @options.merge(store: true))

    assert_success response
    assert_equal 'Visa', response.params['CardType']
    assert_equal 'Success', response.params['TokenRspMsg']
    assert_not_nil response.params['TokenValue']
  end

  def test_successful_purchase_with_token_from_auth
    response = @gateway.authorize(@amount, @credit_card, @options.merge(store: true))

    assert_success response
    assert_equal 'Visa', response.params['CardType']
    assert_equal 'Success', response.params['TokenRspMsg']
    assert_not_nil response.params['TokenValue']
    token = response.params['TokenValue']

    purchase = @gateway.purchase(@amount, token, @options)
    assert_success purchase
    assert_equal 'Success', purchase.message
  end

  def test_successful_purchase_with_swipe_no_encryption
    @credit_card.track_data = '%B547888879888877776?;5473500000000014=25121019999888877776?'
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_purchase_with_swipe_bad_track_data
    @credit_card.track_data = '%B547888879888877776?;?'
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert_equal 'Transaction was rejected because the track data could not be read.', response.message
  end

  def test_successful_purchase_with_swipe_encryption_type_01
    @options[:encryption_type] = '01'
    @credit_card.track_data = '&lt;E1052711%B5473501000000014^MC TEST CARD^251200000000000000000000000000000000?|GVEY/MKaKXuqqjKRRueIdCHPPoj1gMccgNOtHC41ymz7bIvyJJVdD3LW8BbwvwoenI+|+++++++C4cI2zjMp|11;5473501000000014=25120000000000000000?|8XqYkQGMdGeiIsgM0pzdCbEGUDP|+++++++C4cI2zjMp|00|||/wECAQECAoFGAgEH2wYcShV78RZwb3NAc2VjdXJlZXhjaGFuZ2UubmV0PX50qfj4dt0lu9oFBESQQNkpoxEVpCW3ZKmoIV3T93zphPS3XKP4+DiVlM8VIOOmAuRrpzxNi0TN/DWXWSjUC8m/PI2dACGdl/hVJ/imfqIs68wYDnp8j0ZfgvM26MlnDbTVRrSx68Nzj2QAgpBCHcaBb/FZm9T7pfMr2Mlh2YcAt6gGG1i2bJgiEJn8IiSDX5M2ybzqRT86PCbKle/XCTwFFe1X|&gt;'
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_swipe_encryption_type_02
    @options[:encryption_type] = '02'
    @options[:encrypted_track_number] = 2
    @options[:ktb] = '/wECAQECAoFGAgEH3QgVTDT6jRZwb3NAc2VjdXJlZXhjaGFuZ2UubmV0Nkt08KRSPigRYcr1HVgjRFEvtUBy+VcCKlOGA3871r3SOkqDvH2+30insdLHmhTLCc4sC2IhlobvWnutAfylKk2GLspH/pfEnVKPvBv0hBnF4413+QIRlAuGX6+qZjna2aMl0kIsjEY4N6qoVq2j5/e5I+41+a2pbm61blv2PEMAmyuCcAbN3/At/1kRZNwN6LSUg9VmJO83kOglWBe1CbdFtncq'
    @credit_card.track_data = '7SV2BK6ESQPrq01iig27E74SxMg'
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Success', response.message
  end

  def tests_successful_verify
    response = @gateway.verify(@credit_card, @options)

    assert_success response
    assert_equal 'Success', response.message
  end

  def tests_failed_verify
    @credit_card.number = 12345

    response = @gateway.verify(@credit_card, @options)

    assert_failure response
    assert_equal 'The card number is not a valid credit card number.', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:secret_api_key], transcript)
  end

  def test_transcript_scrubbing_with_cryptogram
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      verification_value: nil,
      eci: '05',
      source: :apple_pay
    )
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(credit_card.number, transcript)
    assert_scrubbed(@gateway.options[:secret_api_key], transcript)
    assert_scrubbed(credit_card.payment_cryptogram, transcript)
  end

  def test_successful_purchase_with_apple_pay_raw_cryptogram_with_eci
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      verification_value: nil,
      eci: '05',
      source: :apple_pay
    )
    assert response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_apple_pay_raw_cryptogram_without_eci
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      verification_value: nil,
      source: :apple_pay
    )
    assert response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_auth_with_apple_pay_raw_cryptogram_with_eci
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      verification_value: nil,
      eci: '05',
      source: :apple_pay
    )
    assert response = @gateway.authorize(@amount, credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_auth_with_apple_pay_raw_cryptogram_without_eci
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      verification_value: nil,
      source: :apple_pay
    )
    assert response = @gateway.authorize(@amount, credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_three_d_secure_visa
    @credit_card.number = '4012002000060016'
    @credit_card.brand = 'visa'

    options = {
      :three_d_secure => {
        :cavv => 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
        :eci => '05',
        :xid => 'TTBCSkVTa1ZpbDI1bjRxbGk5ODE='
      }
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_three_d_secure_mastercard
    @credit_card.number = '5473500000000014'
    @credit_card.brand = 'master'

    options = {
      :three_d_secure => {
        :cavv => 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
        :eci => '05',
        :xid => 'TTBCSkVTa1ZpbDI1bjRxbGk5ODE='
      }
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_three_d_secure_discover
    @credit_card.number = '6011000990156527'
    @credit_card.brand = 'discover'

    options = {
      :three_d_secure => {
        :cavv => 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
        :eci => '05',
        :xid => 'TTBCSkVTa1ZpbDI1bjRxbGk5ODE='
      }
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_three_d_secure_amex
    @credit_card.number = '372700699251018'
    @credit_card.brand = 'american_express'

    options = {
      :three_d_secure => {
        :cavv => 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
        :eci => '05',
        :xid => 'TTBCSkVTa1ZpbDI1bjRxbGk5ODE='
      }
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_three_d_secure_jcb
    @credit_card.number = '372700699251018'
    @credit_card.brand = 'jcb'

    options = {
      :three_d_secure => {
        :cavv => 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
        :eci => '05',
        :xid => 'TTBCSkVTa1ZpbDI1bjRxbGk5ODE='
      }
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end
end
