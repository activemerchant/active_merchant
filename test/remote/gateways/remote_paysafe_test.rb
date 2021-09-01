require 'test_helper'

class RemotePaysafeTest < Test::Unit::TestCase
  def setup
    @gateway = PaysafeGateway.new(fixtures(:paysafe))

    @amount = 100
    @credit_card = credit_card('4107857757053670')
    @mastercard = credit_card('5186750368967720', brand: 'mastercard')
    @pm_token = 'Ci3S9DWyOP9CiJ5'
    @options = {
      billing_address: address,
      merchant_descriptor: {
        dynamic_descriptor: 'Store Purchase',
        phone: '999-8887777'
      }
    }
    @profile_options = {
      date_of_birth: {
        year: 1979,
        month: 1,
        day: 1
      },
      email: 'profile@memail.com',
      phone: '111-222-3456',
      address: address
    }
    @mc_three_d_secure_2_options = {
      currency: 'EUR',
      three_d_secure: {
        eci: 0,
        cavv: 'AAABBhkXYgAAAAACBxdiENhf7A+=',
        version: '2.1.0',
        ds_transaction_id: 'a3a721f3-b6fa-4cb5-84ea-c7b5c39890a2'
      }
    }
    @visa_three_d_secure_2_options = {
      currency: 'EUR',
      three_d_secure: {
        eci: 5,
        cavv: 'AAABBhkXYgAAAAACBxdiENhf7A+=',
        version: '2.1.0'
      }
    }
    @mc_three_d_secure_1_options = {
      currency: 'EUR',
      three_d_secure: {
        eci: 0,
        cavv: 'AAABBhkXYgAAAAACBxdiENhf7A+=',
        xid: 'aWg4N1ZZOE53TkFrazJuMmkyRDA=',
        version: '1.0.2',
        ds_transaction_id: 'a3a721f3-b6fa-4cb5-84ea-c7b5c39890a2'
      }
    }
    @visa_three_d_secure_1_options = {
      currency: 'EUR',
      three_d_secure: {
        eci: 5,
        cavv: 'AAABBhkXYgAAAAACBxdiENhf7A+=',
        xid: 'aWg4N1ZZOE53TkFrazJuMmkyRDA=',
        version: '1.0.2'
      }
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'COMPLETED', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      ip: '127.0.0.1',
      email: 'joe@example.com'
    }

    response = @gateway.purchase(@amount, @credit_card, @options.merge(options))
    assert_success response
    assert_equal 'COMPLETED', response.message
  end

  def test_successful_purchase_with_token
    response = @gateway.purchase(200, @pm_token, @options)
    assert_success response
    assert_equal 'COMPLETED', response.message
  end

  def test_successful_purchase_with_token_3ds2
    response = @gateway.purchase(200, @pm_token, @options.merge(@visa_three_d_secure_2_options))
    assert_success response
    assert_equal 'COMPLETED', response.message
  end

  def test_successful_purchase_with_mastercard_3ds1
    response = @gateway.purchase(@amount, @mastercard, @options.merge(@mc_three_d_secure_1_options))
    assert_success response
    assert_equal 'COMPLETED', response.message
  end

  def test_successful_purchase_with_mastercard_3ds2
    response = @gateway.purchase(@amount, @mastercard, @options.merge(@mc_three_d_secure_2_options))
    assert_success response
    assert_equal 'COMPLETED', response.message
  end

  def test_successful_purchase_with_visa_3ds1
    response = @gateway.purchase(@amount, @credit_card, @options.merge(@visa_three_d_secure_1_options))
    assert_success response
    assert_equal 'COMPLETED', response.message
  end

  def test_successful_purchase_with_visa_3ds2
    response = @gateway.purchase(@amount, @credit_card, @options.merge(@visa_three_d_secure_2_options))
    assert_success response
    assert_equal 'COMPLETED', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(11, @credit_card, @options)
    assert_failure response
    assert_equal 'Error(s)- code:3022, message:The card has been declined due to insufficient funds.', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'PENDING', capture.message
  end

  def test_successful_authorize_and_capture_with_token
    auth = @gateway.authorize(@amount, @pm_token, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'PENDING', capture.message
  end

  def test_successful_authorize_with_token
    response = @gateway.authorize(250, @pm_token, @options)
    assert_success response
    assert_equal 'COMPLETED', response.message
  end

  def test_successful_authorize_with_token_3ds1
    response = @gateway.authorize(200, @pm_token, @options.merge(@visa_three_d_secure_1_options))
    assert_success response
    assert_equal 'COMPLETED', response.message
  end

  def test_successful_authorize_with_token_3ds2
    response = @gateway.authorize(200, @pm_token, @options.merge(@visa_three_d_secure_2_options))
    assert_success response
    assert_equal 'COMPLETED', response.message
  end

  def test_failed_authorize
    response = @gateway.authorize(5, @credit_card, @options)
    assert_failure response
    assert_equal 'Error(s)- code:3009, message:Your request has been declined by the issuing bank.', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, 'invalidtransactionid')
    assert_failure response
    assert_equal 'Error(s)- code:3201, message:The authorization ID included in this settlement request could not be found.', response.message
  end

  # Can test refunds by logging into our portal and grabbing transaction IDs from settled transactions
  # Refunds will return 'PENDING' status until they are batch processed at EOD
  def test_successful_refund
    auth = 'e25875b2-2a72-4a31-924c-66667507cad6'

    assert refund = @gateway.refund(@amount, auth)
    assert_success refund
    assert_equal 'PENDING', refund.message
  end

  def test_partial_refund
    auth = 'cb6fed1e-1c71-4e87-abbb-3beae97d7775'

    assert refund = @gateway.refund(@amount - 1, auth)
    assert_success refund
    assert_equal 'PENDING', refund.message
  end

  def test_failed_refund
    response = @gateway.refund(@amount, 'thisisnotavalidtrasactionid')
    assert_failure response
    assert_equal 'Error(s)- code:3407, message:The settlement referred to by the transaction response ID you provided cannot be found.', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'COMPLETED', void.message
  end

  def test_successful_void_with_token_purchase
    auth = @gateway.authorize(@amount, @pm_token, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'COMPLETED', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal "Error(s)- code:5023, message:Request method 'POST' not supported", response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match 'COMPLETED', response.message
  end

  def test_successful_verify_with_token
    response = @gateway.verify(@pm_token, @options)
    assert_success response
    assert_match 'COMPLETED', response.message
  end

  # Not including a test_failed_verify since the only way to force a failure on this
  # gateway is with a specific dollar amount

  def test_successful_store
    response = @gateway.store(credit_card('4111111111111111'), @profile_options)
    assert_success response
  end

  def test_successful_store_and_redact
    response = @gateway.store(credit_card('4111111111111111'), @profile_options)
    assert_success response
    id = response.authorization
    redact = @gateway.redact(id)
    assert_success redact
  end

  def test_invalid_login
    gateway = PaysafeGateway.new(username: '', password: '', account_id: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '5279', response.error_code
    assert_match 'invalid', response.params['error']['message'].downcase
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value, clean_transcript)
  end
end
