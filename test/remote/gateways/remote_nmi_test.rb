require 'test_helper'

class RemoteNmiTest < Test::Unit::TestCase
  def setup
    @gateway = NmiGateway.new(fixtures(:nmi))
    @amount = Random.rand(100...1000)
    @credit_card = credit_card('4111111111111111', verification_value: 917)
    @check = check(
      :routing_number => '123123123',
      :account_number => '123123123'
    )
    @apple_pay_card = network_tokenization_credit_card('4111111111111111',
      :payment_cryptogram => "EHuWW9PiBkWvqE5juRwDzAUFBAk=",
      :month              => "01",
      :year               => "2024",
      :source             => :apple_pay,
      :eci                => "5",
      :transaction_id     => "123456789"
    )
    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => 'Store purchase'
    }
  end

  def test_invalid_login
    @gateway = NmiGateway.new(login: "invalid", password: "no")
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Authentication Failed", response.message
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'Succeeded', response.message
    assert response.authorization
  end

  def test_successful_purchase_sans_cvv
    @credit_card.verification_value = nil
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'Succeeded', response.message
    assert response.authorization
  end

  def test_failed_purchase
    assert response = @gateway.purchase(99, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'DECLINE', response.message
  end

  def test_successful_purchase_with_echeck
    assert response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert response.test?
    assert_equal 'Succeeded', response.message
    assert response.authorization
  end

  def test_failed_purchase_with_echeck
    assert response = @gateway.purchase(99, @check, @options)
    assert_failure response
    assert response.test?
    assert_equal 'FAILED', response.message
  end

  def test_successful_purchase_with_apple_pay_card
    assert @gateway.supports_network_tokenization?
    assert response = @gateway.purchase(@amount, @apple_pay_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'Succeeded', response.message
    assert response.authorization
  end

  def test_failed_purchase_with_apple_pay_card
    assert response = @gateway.purchase(99, @apple_pay_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'DECLINE', response.message
  end

  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert response.authorization
  end

  def test_failed_authorization
    assert response = @gateway.authorize(99, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'DECLINE', response.message
  end

  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert_equal 'Succeeded', capture.message
  end

  def test_failed_capture
    assert capture = @gateway.capture(@amount, "badauth")
    assert_failure capture
  end

  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert void = @gateway.void(authorization.authorization)
    assert_success void
    assert_equal 'Succeeded', void.message
  end

  def test_failed_void
    assert void = @gateway.void("badauth")
    assert_failure void
  end

  def test_successful_void_with_echeck
    assert response = @gateway.purchase(@amount, @check, @options)
    assert_success response

    assert response = @gateway.void(response.authorization)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert response = @gateway.refund(@amount, response.authorization)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_refund
    assert response = @gateway.refund(@amount, "badauth")
    assert_failure response
  end

  def test_successful_refund_with_echeck
    assert response = @gateway.purchase(@amount, @check, @options)
    assert_success response

    assert response = @gateway.refund(@amount, response.authorization)
    assert_success response
    assert_equal 'Succeeded', response.message
  end


  def test_successful_credit
    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_credit
    card = credit_card(year: 2010)
    response = @gateway.credit(@amount, card, @options)
    assert_failure response
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match "Succeeded", response.message
  end

  def test_failed_verify
    card = credit_card(year: 2010)
    response = @gateway.verify(card, @options)
    assert_failure response
    assert_match "Invalid Credit Card", response.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert response.params["customer_vault_id"]
  end

  def test_failed_store
    card = credit_card(year: 2010)
    response = @gateway.store(card, @options)
    assert_failure response
    assert_nil response.params["customer_vault_id"]
  end

  def test_successful_store_with_echeck
    response = @gateway.store(@check, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert response.params["customer_vault_id"]
  end

  def test_successful_store_and_purchase
    vault_id = @gateway.store(@credit_card, @options).params["customer_vault_id"]
    purchase = @gateway.purchase(@amount, vault_id, @options)
    assert_success purchase
    assert_equal "Succeeded", purchase.message
  end

  def test_successful_store_and_auth
    vault_id = @gateway.store(@credit_card, @options).params["customer_vault_id"]
    auth = @gateway.authorize(@amount, vault_id, @options)
    assert_success auth
    assert_equal "Succeeded", auth.message
  end

  def test_successful_store_and_credit
    vault_id = @gateway.store(@credit_card, @options).params["customer_vault_id"]
    credit = @gateway.credit(@amount, vault_id, @options)
    assert_success credit
    assert_equal "Succeeded", credit.message
  end

  def test_merchant_defined_fields
    (1..20).each { |e| @options["merchant_defined_field_#{e}".to_sym] = "value #{e}" }
    assert_success @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_verify_credentials
    assert @gateway.verify_credentials

    gateway = NmiGateway.new(login: 'unknown', password: 'unknown')
    assert !gateway.verify_credentials
    gateway = NmiGateway.new(login: fixtures(:nmi)[:login], password: 'unknown')
    assert !gateway.verify_credentials
  end

  def test_card_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)

    # "password=password is filtered, but can't be tested b/c of key match"
    # assert_scrubbed(@gateway.options[:password], clean_transcript)
  end

  def test_check_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @check, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@check.account_number, clean_transcript)
    assert_scrubbed(@check.routing_number, clean_transcript)

    # "password=password is filtered, but can't be tested b/c of key match"
    # assert_scrubbed(@gateway.options[:password], clean_transcript)
  end

  def test_network_tokenization_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @apple_pay_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@apple_pay_card.number, clean_transcript)
    assert_scrubbed(@apple_pay_card.payment_cryptogram, clean_transcript)

    # "password=password is filtered, but can't be tested b/c of key match"
    # assert_scrubbed(@gateway.options[:password], clean_transcript)
  end
end
