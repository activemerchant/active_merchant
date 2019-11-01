require 'test_helper'

class RemoteRealexTest < Test::Unit::TestCase

  def setup
    @gateway = RealexGateway.new(fixtures(:realex_with_account))

    # Replace the card numbers with the test account numbers from Realex
    @visa              = card_fixtures(:realex_visa)
    @visa_declined     = card_fixtures(:realex_visa_declined)
    @visa_referral_b   = card_fixtures(:realex_visa_referral_b)
    @visa_referral_a   = card_fixtures(:realex_visa_referral_a)
    @visa_coms_error   = card_fixtures(:realex_visa_coms_error)
    @visa_3ds_enrolled = card_fixtures(:realex_visa_3ds_enrolled)

    @mastercard            = card_fixtures(:realex_mastercard)
    @mastercard_declined   = card_fixtures(:realex_mastercard_declined)
    @mastercard_referral_b = card_fixtures(:realex_mastercard_referral_b)
    @mastercard_referral_a = card_fixtures(:realex_mastercard_referral_a)
    @mastercard_coms_error = card_fixtures(:realex_mastercard_coms_error)

    @apple_pay = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      verification_value: nil,
      eci: '05',
      source: :apple_pay
    )

    @declined_apple_pay = network_tokenization_credit_card('4000120000001154',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      verification_value: nil,
      eci: '05',
      source: :apple_pay
    )
    @amount = 10000
  end

  def card_fixtures(name)
    credit_card(nil, fixtures(name))
  end

  def test_realex_purchase
    [ @visa, @mastercard ].each do |card|
      response = @gateway.purchase(@amount, card,
        :order_id => generate_unique_id,
        :description => 'Test Realex Purchase',
        :billing_address => {
          :zip => '90210',
          :country => 'US'
        }
      )
      assert_not_nil response
      assert_success response
      assert response.test?
      assert response.authorization.length > 0
      assert_equal 'Successful', response.message
    end
  end

  def test_realex_purchase_with_invalid_login
    gateway = RealexGateway.new(
      :login => 'invalid',
      :password => 'invalid'
    )
    response = gateway.purchase(@amount, @visa,
      :order_id => generate_unique_id,
      :description => 'Invalid login test'
    )

    assert_not_nil response
    assert_failure response

    assert_equal '504', response.params['result']
    assert_match %r{no such}i, response.message
  end

  def test_realex_purchase_with_invalid_account
    response = RealexGateway.new(fixtures(:realex_with_account).merge(account: 'invalid')).purchase(@amount, @visa,
      :order_id => generate_unique_id,
      :description => 'Test Realex purchase with invalid account'
    )

    assert_not_nil response
    assert_failure response

    assert_equal '506', response.params['result']
    assert_match %r{no such}i, response.message
  end

  def test_realex_purchase_with_apple_pay
    response = @gateway.purchase(1000, @apple_pay, :order_id => generate_unique_id, :description => 'Test Realex with ApplePay')
    assert_success response
    assert response.test?
    assert_equal 'Successful', response.message
  end

  def test_realex_purchase_declined
    [ @visa_declined, @mastercard_declined ].each do |card|
      response = @gateway.purchase(@amount, card,
        :order_id => generate_unique_id,
        :description => 'Test Realex purchase declined'
      )
      assert_not_nil response
      assert_failure response

      assert_equal '101', response.params['result']
      assert_equal response.params['message'], response.message
    end
  end

  def test_realex_purchase_with_apple_pay_declined
    response = @gateway.purchase(1101, @declined_apple_pay, :order_id => generate_unique_id, :description => 'Test Realex with ApplePay')
    assert_failure response
    assert response.test?
    assert_equal '101', response.params['result']
    assert_match %r{DECLINED}i, response.message
  end

  def test_realex_purchase_with_three_d_secure_1
    response = @gateway.purchase(
      1000,
      @visa_3ds_enrolled,
      three_d_secure: {
        eci: '05',
        cavv: 'AgAAAAAAAIR8CQrXcIhbQAAAAAA',
        xid: 'MDAwMDAwMDAwMDAwMDAwMzIyNzY=',
        version: '1.0.2',
      },
      :order_id => generate_unique_id,
      :description => 'Test Realex with 3DS'
    )
    assert_success response
    assert response.test?
    assert_equal 'Successful', response.message
  end

  def test_realex_purchase_with_three_d_secure_2
    response = @gateway.purchase(
      1000,
      @visa_3ds_enrolled,
      three_d_secure: {
        eci: '05',
        cavv: 'AgAAAAAAAIR8CQrXcIhbQAAAAAA',
        ds_transaction_id: 'bDE9Aa1A-C5Ac-AD3a-4bBC-aC918ab1de3E',
        version: '2.1.0',
      },
      :order_id => generate_unique_id,
      :description => 'Test Realex with 3DS'
    )
    assert_success response
    assert response.test?
    assert_equal 'Successful', response.message
  end

  def test_realex_purchase_referral_b
    [ @visa_referral_b, @mastercard_referral_b ].each do |card|
      response = @gateway.purchase(@amount, card,
        :order_id => generate_unique_id,
        :description => 'Test Realex Referral B'
      )
      assert_not_nil response
      assert_failure response
      assert response.test?
      assert_equal '102', response.params['result']
      assert_equal RealexGateway::DECLINED, response.message
    end
  end

  def test_realex_purchase_referral_a
    [ @visa_referral_a, @mastercard_referral_a ].each do |card|
      response = @gateway.purchase(@amount, card,
        :order_id => generate_unique_id,
        :description => 'Test Realex Rqeferral A'
      )
      assert_not_nil response
      assert_failure response
      assert_equal '103', response.params['result']
      assert_equal RealexGateway::DECLINED, response.message
    end
  end

  def test_realex_purchase_coms_error
    [ @visa_coms_error, @mastercard_coms_error ].each do |card|
      response = @gateway.purchase(@amount, card,
        :order_id => generate_unique_id,
        :description => 'Test Realex coms error'
      )
      assert_not_nil response
      assert_failure response

      assert_equal '200', response.params['result']
      assert_equal RealexGateway::BANK_ERROR, response.message
    end
  end

  def test_realex_expiry_month_error
    @visa.month = 13

    response = @gateway.purchase(@amount, @visa,
      :order_id => generate_unique_id,
      :description => 'Test Realex expiry month error'
    )
    assert_not_nil response
    assert_failure response

    assert_equal '509', response.params['result']
    assert_match %r{invalid}i, response.message
  end

  def test_realex_expiry_year_error
    @visa.year = 2005

    response = @gateway.purchase(@amount, @visa,
      :order_id => generate_unique_id,
      :description => 'Test Realex expiry year error'
    )
    assert_not_nil response
    assert_failure response

    assert_equal '509', response.params['result']
    assert_equal 'Expiry date invalid', response.message
  end

  def test_invalid_credit_card_name
    @visa.first_name = ''
    @visa.last_name = ''

    response = @gateway.purchase(@amount, @visa,
      :order_id => generate_unique_id,
      :description => 'test_chname_error'
    )
    assert_not_nil response
    assert_failure response

    assert_equal '506', response.params['result']
    assert_match(/does not conform/i, response.message)
  end

  def test_cvn
    @visa_cvn = @visa.clone
    @visa_cvn.verification_value = '111'
    response = @gateway.purchase(@amount, @visa_cvn,
      :order_id => generate_unique_id,
      :description => 'test_cvn'
    )
    assert_not_nil response
    assert_success response
    assert response.authorization.length > 0
  end

  def test_customer_number
    response = @gateway.purchase(@amount, @visa,
      :order_id => generate_unique_id,
      :description => 'test_cust_num',
      :customer => 'my customer id'
    )
    assert_not_nil response
    assert_success response
    assert response.authorization.length > 0
  end

  def test_realex_authorize
    response = @gateway.authorize(@amount, @visa,
      :order_id => generate_unique_id,
      :description => 'Test Realex Purchase',
      :billing_address => {
        :zip => '90210',
        :country => 'US'
      }
    )

    assert_not_nil response
    assert_success response
    assert response.test?
    assert response.authorization.length > 0
    assert_equal 'Successful', response.message
  end

  def test_realex_authorize_then_capture
    order_id = generate_unique_id

    auth_response = @gateway.authorize(@amount, @visa,
      :order_id => order_id,
      :description => 'Test Realex Purchase',
      :billing_address => {
        :zip => '90210',
        :country => 'US'
      }
    )
    assert auth_response.test?

    capture_response = @gateway.capture(nil, auth_response.authorization)

    assert_not_nil capture_response
    assert_success capture_response
    assert capture_response.authorization.length > 0
    assert_equal 'Successful', capture_response.message
    assert_match(/Settled Successfully/, capture_response.params['message'])
  end

  def test_realex_authorize_then_capture_with_extra_amount
    order_id = generate_unique_id

    auth_response = @gateway.authorize(@amount*115, @visa,
      :order_id => order_id,
      :description => 'Test Realex Purchase',
      :billing_address => {
        :zip => '90210',
        :country => 'US'
      }
    )
    assert auth_response.test?

    capture_response = @gateway.capture(@amount, auth_response.authorization)

    assert_not_nil capture_response
    assert_success capture_response
    assert capture_response.authorization.length > 0
    assert_equal 'Successful', capture_response.message
    assert_match(/Settled Successfully/, capture_response.params['message'])
  end

  def test_realex_purchase_then_void
    order_id = generate_unique_id

    purchase_response = @gateway.purchase(@amount, @visa,
      :order_id => order_id,
      :description => 'Test Realex Purchase',
      :billing_address => {
        :zip => '90210',
        :country => 'US'
      }
    )
    assert purchase_response.test?

    void_response = @gateway.void(purchase_response.authorization)

    assert_not_nil void_response
    assert_success void_response
    assert_equal 'Successful', void_response.message
    assert_match(/Voided Successfully/, void_response.params['message'])
  end

  def test_realex_purchase_then_refund
    order_id = generate_unique_id

    gateway_with_refund_password = RealexGateway.new(fixtures(:realex).merge(:rebate_secret => 'rebate'))

    purchase_response = gateway_with_refund_password.purchase(@amount, @visa,
      :order_id => order_id,
      :description => 'Test Realex Purchase',
      :billing_address => {
        :zip => '90210',
        :country => 'US'
      }
    )
    assert purchase_response.test?

    rebate_response = gateway_with_refund_password.refund(@amount, purchase_response.authorization)

    assert_not_nil rebate_response
    assert_success rebate_response
    assert rebate_response.authorization.length > 0
    assert_equal 'Successful', rebate_response.message
  end

  def test_realex_verify
    response = @gateway.verify(@visa,
      :order_id => generate_unique_id,
      :description => 'Test Realex verify'
    )

    assert_not_nil response
    assert_success response
    assert response.test?
    assert response.authorization.length > 0
    assert_equal 'Successful', response.message
  end

  def test_realex_verify_declined
    response = @gateway.verify(@visa_declined,
      :order_id => generate_unique_id,
      :description => 'Test Realex verify declined'
    )

    assert_not_nil response
    assert_failure response
    assert response.test?
    assert_equal '101', response.params['result']
    assert_match %r{DECLINED}i, response.message
  end

  def test_successful_credit
    gateway_with_refund_password = RealexGateway.new(fixtures(:realex).merge(:refund_secret => 'refund'))

    credit_response = gateway_with_refund_password.credit(@amount, @visa,
      :order_id => generate_unique_id,
      :description => 'Test Realex Credit',
      :billing_address => {
        :zip => '90210',
        :country => 'US'
      }
    )

    assert_not_nil credit_response
    assert_success credit_response
    assert credit_response.authorization.length > 0
    assert_equal 'Successful', credit_response.message
  end

  def test_failed_credit
    credit_response = @gateway.credit(@amount, @visa,
      :order_id => generate_unique_id,
      :description => 'Test Realex Credit',
      :billing_address => {
        :zip => '90210',
        :country => 'US'
      }
    )

    assert_not_nil credit_response
    assert_failure credit_response
    assert credit_response.authorization.length > 0
    assert_equal 'Refund Hash not present.', credit_response.message
  end

  def test_maps_avs_and_cvv_response_codes
    [ @visa, @mastercard ].each do |card|
      response = @gateway.purchase(@amount, card,
        :order_id => generate_unique_id,
        :description => 'Test Realex Purchase',
        :billing_address => {
          :zip => '90210',
          :country => 'US'
        }
      )
      assert_not_nil response
      assert_success response
      assert_equal 'M', response.avs_result['code']
      assert_equal 'M', response.cvv_result['code']
    end
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @visa_declined,
        :order_id => generate_unique_id,
        :description => 'Test Realex Purchase',
        :billing_address => {
          :zip => '90210',
          :country => 'US'
        }
      )
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@visa_declined.number, clean_transcript)
    assert_scrubbed(@visa_declined.verification_value.to_s, clean_transcript)
  end
end
