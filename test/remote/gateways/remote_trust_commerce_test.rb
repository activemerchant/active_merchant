require 'test_helper'

class TrustCommerceTest < Test::Unit::TestCase
  def setup
    @gateway = TrustCommerceGateway.new(fixtures(:trust_commerce))

    @credit_card = credit_card('4111111111111111')
    @declined_credit_card = credit_card('4111111111111112')
    @check = check({account_number: 55544433221, routing_number: 789456124})

    @amount = 100

    @valid_verification_value = '123'
    @invalid_verification_value = '1234'

    @valid_address = {
      :address1 => '123 Test St.',
      :address2 => nil,
      :city => 'Somewhere',
      :state => 'CA',
      :zip => '90001'
    }

    @invalid_address = {
      :address1 => '187 Apple Tree Lane.',
      :address2 => nil,
      :city => 'Woodside',
      :state => 'CA',
      :zip => '94062'
    }

    # The Trust Commerce API does not return anything different when custom fields are present.
    # To confirm that the field values are being stored with the transactions, add a custom
    # field in your account in the Vault UI, then examine the transactions after running the
    # test suite.
    custom_fields = {
      'customfield1' => 'test1'
    }

    @options = {
      :ip => '10.10.10.10',
      :order_id => '#1000.1',
      :email => 'cody@example.com',
      :billing_address => @valid_address,
      :shipping_address => @valid_address,
      :custom_fields => custom_fields
    }
  end

  def test_bad_login
    @gateway.options[:login] = 'X'
    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_equal Response, response.class
    assert_equal ['error',
                  'offenders',
                  'status'], response.params.keys.sort

    assert_match %r{A field was improperly formatted, such as non-digit characters in a number field}, response.message

    assert_failure response
  end

  def test_successful_purchase_with_avs
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Y', response.avs_result['code']
    assert_match %r{The transaction was successful}, response.message

    assert_success response
    assert !response.authorization.blank?
  end

  def test_successful_purchase_with_check
    assert response = @gateway.purchase(@amount, @check, @options)
    assert_match %r{The transaction was successful}, response.message

    assert_success response
    assert !response.authorization.blank?
  end

  def test_unsuccessful_purchase_with_invalid_cvv
    @credit_card.verification_value = @invalid_verification_value
    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_equal Response, response.class
    assert_match %r{CVV failed; the number provided is not the correct verification number for the card}, response.message
    assert_failure response
  end

  def test_purchase_with_avs_for_invalid_address
    assert response = @gateway.purchase(@amount, @credit_card, @options.update(:billing_address => @invalid_address))
    assert_equal 'N', response.params['avs']
    assert_match %r{The transaction was successful}, response.message
    assert_success response
  end

  # Requires enabling the setting: 'Allow voids to process or settle on processing node' in the Trust Commerce vault UI
  def test_purchase_and_void
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    void = @gateway.void(purchase.authorization)
    assert_success void
    assert_equal 'The transaction was successful', void.message
    assert_equal 'accepted', void.params['status']
    assert void.params['transid']
  end

  def test_successful_authorize_with_avs
    assert response = @gateway.authorize(@amount, @credit_card, :billing_address => @valid_address)

    assert_equal 'Y', response.avs_result['code']
    assert_match %r{The transaction was successful}, response.message

    assert_success response
    assert !response.authorization.blank?
  end

  def test_unsuccessful_authorize_with_invalid_cvv
    @credit_card.verification_value = @invalid_verification_value
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_match %r{CVV failed; the number provided is not the correct verification number for the card}, response.message
    assert_failure response
  end

  def test_authorization_with_avs_for_invalid_address
    assert response = @gateway.authorize(@amount, @credit_card, @options.update(:billing_address => @invalid_address))
    assert_equal 'N', response.params['avs']
    assert_match %r{The transaction was successful}, response.message
    assert_success response
  end

  def test_successful_capture
    auth = @gateway.authorize(300, @credit_card)
    assert_success auth
    response = @gateway.capture(300, auth.authorization)

    assert_success response
    assert_equal 'The transaction was successful', response.message
    assert_equal 'accepted', response.params['status']
    assert response.params['transid']
  end

  def test_authorization_and_void
    auth = @gateway.authorize(300, @credit_card, @options)
    assert_success auth

    void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'The transaction was successful', void.message
    assert_equal 'accepted', void.params['status']
    assert void.params['transid']
  end

  def test_successful_credit
    assert response = @gateway.credit(@amount, '011-0022698151')

    assert_match %r{The transaction was successful}, response.message
    assert_success response
  end

  def test_successful_check_refund
    purchase = @gateway.purchase(@amount, @check, @options)

    assert response = @gateway.refund(@amount, purchase.authorization)

    assert_match %r{The transaction was successful}, response.message
    assert_success response
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card)

    assert_equal Response, response.class
    assert_equal 'approved', response.params['status']
    assert_match %r{The transaction was successful}, response.message
  end

  def test_failed_store
    assert response = @gateway.store(@declined_credit_card)

    assert_bad_data_response(response)
  end

  def test_unstore_failure
    assert response = @gateway.unstore('does-not-exist')

    assert_match %r{A field was longer or shorter than the server allows}, response.message
    assert_failure response
  end

  def test_successful_recurring
    assert response = @gateway.recurring(@amount, @credit_card, :periodicity => :weekly)

    assert_match %r{The transaction was successful}, response.message
    assert_success response
  end

  def test_failed_recurring
    assert response = @gateway.recurring(@amount, @declined_credit_card, :periodicity => :weekly)

    assert_bad_data_response(response)
  end

  def test_transcript_scrubbing
    @credit_card.verification_value = @invalid_verification_value
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end

  private

  def assert_bad_data_response(response)
    assert_equal Response, response.class
    assert_equal 'A field was improperly formatted, such as non-digit characters in a number field', response.message
    assert_equal 'baddata', response.params['status']
  end
end
