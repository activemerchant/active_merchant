# coding: utf-8

require 'test_helper'

class RemoteOgoneTest < Test::Unit::TestCase
  def setup
    @gateway = OgoneGateway.new(fixtures(:ogone))

    # this change is according the new PSD2 guideline
    # https://support.legacy.worldline-solutions.com/en/direct/faq/i-have-noticed-i-have-more-declined-transactions-status-2-than-usual-what-can-i-do
    @gateway_3ds = OgoneGateway.new(fixtures(:ogone).merge(signature_encryptor: 'sha512'))
    @amount = 100
    @credit_card     = credit_card('4000100011112224')
    @mastercard      = credit_card('5399999999999999', brand: 'mastercard')
    @declined_card   = credit_card('1111111111111111')
    @credit_card_d3d = credit_card('4000000000000002', verification_value: '111')
    @credit_card_d3d_2_challenge = credit_card('5130257474533310', verification_value: '123')
    @credit_card_d3d_2_frictionless = credit_card('4186455175836497', verification_value: '123')
    @options = {
      order_id: generate_unique_id[0...30],
      billing_address: address,
      description: 'Store Purchase',
      currency: fixtures(:ogone)[:currency] || 'EUR',
      origin: 'STORE'
    }
    @options_browser_info = {
      three_ds_2: {
        browser_info:  {
          width: 390,
          height: 400,
          depth: 24,
          timezone: 300,
          user_agent: 'Spreedly Agent',
          java: false,
          javascript: true,
          language: 'en-US',
          browser_size: '05',
          accept_header: 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
        }
      }
    }
  end

  def test_successful_purchase
    assert response = @gateway_3ds.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
    assert_equal @options[:order_id], response.order_id
  end

  def test_successful_purchase_with_utf8_encoding_1
    assert response = @gateway_3ds.purchase(@amount, credit_card('4000100011112224', first_name: 'Rémy', last_name: 'Fröåïør'), @options)
    assert_success response
    assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
  end

  def test_successful_purchase_with_utf8_encoding_2
    assert response = @gateway_3ds.purchase(@amount, credit_card('4000100011112224', first_name: 'ワタシ', last_name: 'ёжзийклмнопрсуфхцч'), @options)
    assert_success response
    assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
  end

  # This test is commented out since it is mutually exclusive with the other signature tests.
  # NOTE: You have to set the "Hash algorithm" to "SHA-1" in the "Technical information"->"Global security parameters"
  #       section of your account admin on https://secure.ogone.com/ncol/test/frame_ogone.asp before running this test
  # def test_successful_purchase_with_signature_encryptor_to_sha1
  #   gateway = OgoneGateway.new(fixtures(:ogone).merge(:signature_encryptor => 'sha1'))
  #   assert response = gateway.purchase(@amount, @credit_card, @options)
  #   assert_success response
  #   assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
  # end

  # This test is commented out since it is mutually exclusive with the other signature tests.
  # NOTE: You have to set the "Hash algorithm" to "SHA-256" in the "Technical information"->"Global security parameters"
  #       section of your account admin on https://secure.ogone.com/ncol/test/frame_ogone.asp before running this test
  # def test_successful_purchase_with_signature_encryptor_to_sha256
  #   gateway = OgoneGateway.new(fixtures(:ogone).merge(:signature_encryptor => 'sha256'))
  #   assert response = gateway.purchase(@amount, @credit_card, @options)
  #   assert_success response
  #   assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
  # end

  # NOTE: You have to set the "Hash algorithm" to "SHA-512" in the "Technical information"->"Global security parameters"
  #       section of your account admin on https://secure.ogone.com/ncol/test/frame_ogone.asp before running this test
  def test_successful_purchase_with_signature_encryptor_to_sha512
    gateway = OgoneGateway.new(fixtures(:ogone).merge(signature_encryptor: 'sha512'))
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
  end

  # NOTE: You have to contact Ogone to make sure your test account allow 3D Secure transactions before running this test
  def test_successful_purchase_with_3d_secure_v1
    assert response = @gateway_3ds.purchase(@amount, @credit_card_d3d, @options.merge(@options_browser_info, d3d: true))
    assert_success response
    assert_equal '46', response.params['STATUS']
    assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
    assert response.params['HTML_ANSWER']
    assert Base64.decode64(response.params['HTML_ANSWER'])
  end

  def test_successful_purchase_with_3d_secure_v2
    assert response = @gateway_3ds.purchase(@amount, @credit_card_d3d_2_challenge, @options_browser_info.merge(d3d: true))
    assert_success response
    assert_equal '46', response.params['STATUS']
    assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
    assert response.params['HTML_ANSWER']
    assert Base64.decode64(response.params['HTML_ANSWER'])
  end

  def test_successful_purchase_with_3d_secure_v2_flag_updated
    options = @options_browser_info.merge(three_d_secure: { required: true })
    assert response = @gateway_3ds.purchase(@amount, @credit_card_d3d, options)
    assert_success response
    assert_equal '46', response.params['STATUS']
    assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
    assert response.params['HTML_ANSWER']
    assert Base64.decode64(response.params['HTML_ANSWER'])
  end

  def test_successful_purchase_with_3d_secure_v2_frictionless
    assert response = @gateway_3ds.purchase(@amount, @credit_card_d3d_2_frictionless, @options_browser_info.merge(d3d: true))
    assert_success response
    assert_includes response.params, 'PAYID'
    assert_equal '0', response.params['NCERROR']
    assert_equal '9', response.params['STATUS']
    assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
  end

  def test_successful_purchase_with_3d_secure_v2_recomended_parameters
    options = @options.merge(@options_browser_info)
    assert response = @gateway_3ds.authorize(@amount, @credit_card_d3d_2_challenge, options.merge(d3d: true))
    assert_success response
    assert_equal '46', response.params['STATUS']
    assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
    assert response.params['HTML_ANSWER']
    assert Base64.decode64(response.params['HTML_ANSWER'])
  end

  def test_successful_purchase_with_3d_secure_v2_optional_parameters
    options = @options.merge(@options_browser_info).merge(mpi: { threeDSRequestorChallengeIndicator: '04' })
    assert response = @gateway_3ds.authorize(@amount, @credit_card_d3d_2_challenge, options.merge(d3d: true))
    assert_success response
    assert_equal '46', response.params['STATUS']
    assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
    assert response.params['HTML_ANSWER']
    assert Base64.decode64(response.params['HTML_ANSWER'])
  end

  def test_unsuccessful_purchase_with_3d_secure_v2
    @credit_card_d3d_2_challenge.number = '4419177274955460'
    assert response = @gateway_3ds.purchase(@amount, @credit_card_d3d_2_challenge, @options_browser_info.merge(d3d: true))
    assert_failure response
    assert_includes response.params, 'PAYID'
    assert_equal response.params['NCERROR'], '40001134'
    assert_equal response.params['STATUS'], '2'
    assert_equal response.params['NCERRORPLUS'], 'Authentication failed. Please retry or cancel.'
  end

  def test_successful_with_non_numeric_order_id
    @options[:order_id] = "##{@options[:order_id][0...26]}.12"
    assert response = @gateway_3ds.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
  end

  def test_successful_purchase_without_explicit_order_id
    @options.delete(:order_id)
    assert response = @gateway_3ds.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
  end

  def test_successful_purchase_with_custom_eci
    assert response = @gateway_3ds.purchase(@amount, @credit_card, @options.merge(eci: 4))
    assert_success response
    assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
  end

  # NOTE: You have to allow USD as a supported currency in the "Account"->"Currencies"
  #       section of your account admin on https://secure.ogone.com/ncol/test/frame_ogone.asp before running this test
  def test_successful_purchase_with_custom_currency_at_the_gateway_level
    assert response = @gateway_3ds.purchase(@amount, @credit_card)
    assert_success response
    assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
  end

  # NOTE: You have to allow USD as a supported currency in the "Account"->"Currencies"
  #       section of your account admin on https://secure.ogone.com/ncol/test/frame_ogone.asp before running this test
  def test_successful_purchase_with_custom_currency
    assert response = @gateway_3ds.purchase(@amount, @credit_card, @options.merge(currency: 'USD'))
    assert_success response
    assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway_3ds.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'No brand or invalid card number', response.message
  end

  def test_successful_authorize_with_mastercard
    assert auth = @gateway_3ds.authorize(@amount, @mastercard, @options)
    assert_success auth
    assert_equal BarclaysEpdqExtraPlusGateway::SUCCESS_MESSAGE, auth.message
  end

  def test_authorize_and_capture
    assert auth = @gateway_3ds.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal OgoneGateway::SUCCESS_MESSAGE, auth.message
    assert auth.authorization
    assert capture = @gateway_3ds.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_authorize_and_capture_with_custom_eci
    assert auth = @gateway_3ds.authorize(@amount, @credit_card, @options.merge(eci: 4))
    assert_success auth
    assert_equal OgoneGateway::SUCCESS_MESSAGE, auth.message
    assert auth.authorization
    assert capture = @gateway_3ds.capture(@amount, auth.authorization, @options)
    assert_success capture
  end

  def test_unsuccessful_capture
    assert response = @gateway_3ds.capture(@amount, '')
    assert_failure response
    assert_equal 'No card no, no exp date, no brand or invalid card number', response.message
  end

  def test_successful_void
    assert auth = @gateway_3ds.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert auth.authorization
    assert void = @gateway_3ds.void(auth.authorization)
    assert_equal OgoneGateway::SUCCESS_MESSAGE, auth.message
    assert_success void
  end

  def test_successful_store
    assert response = @gateway_3ds.store(@credit_card, billing_id: 'test_alias')
    assert_success response
    assert purchase = @gateway_3ds.purchase(@amount, 'test_alias')
    assert_success purchase
  end

  def test_successful_store_with_store_amount_at_the_gateway_level
    assert response = @gateway_3ds.store(@credit_card, billing_id: 'test_alias')
    assert_success response
    assert purchase = @gateway_3ds.purchase(@amount, 'test_alias')
    assert_success purchase
  end

  def test_successful_store_generated_alias
    assert response = @gateway_3ds.store(@credit_card)
    assert_success response
    assert purchase = @gateway_3ds.purchase(@amount, response.billing_id)
    assert_success purchase
  end

  def test_successful_refund
    assert purchase = @gateway_3ds.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert refund = @gateway_3ds.refund(@amount, purchase.authorization, @options)
    assert_success refund
    assert refund.authorization
    assert_equal OgoneGateway::SUCCESS_MESSAGE, refund.message
  end

  def test_unsuccessful_refund
    assert purchase = @gateway_3ds.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert refund = @gateway_3ds.refund(@amount + 1, purchase.authorization, @options) # too much refund requested
    assert_failure refund
    assert refund.authorization
    assert_equal 'Overflow in refunds requests', refund.message
  end

  def test_successful_credit
    assert credit = @gateway.credit(@amount, @credit_card, @options)
    assert_success credit
    assert credit.authorization
    assert_equal OgoneGateway::SUCCESS_MESSAGE, credit.message
  end

  def test_successful_verify
    response = @gateway_3ds.verify(@credit_card, @options)
    assert_success response
    assert_equal 'The transaction was successful', response.message
  end

  def test_failed_verify
    response = @gateway_3ds.verify(@declined_card, @options)
    assert_failure response
    assert_equal 'No brand or invalid card number', response.message
  end

  def test_reference_transactions
    # Setting an alias
    assert response = @gateway_3ds.purchase(@amount, credit_card('4000100011112224'), @options.merge(billing_id: 'awesomeman', order_id: "#{Time.now.to_i}1"))
    assert_success response
    # Updating an alias
    assert response = @gateway_3ds.purchase(@amount, credit_card('4111111111111111'), @options.merge(billing_id: 'awesomeman', order_id: "#{Time.now.to_i}2"))
    assert_success response
    # Using an alias (i.e. don't provide the credit card)
    assert response = @gateway_3ds.purchase(@amount, 'awesomeman', @options.merge(order_id: "#{Time.now.to_i}3"))
    assert_success response
  end

  def test_invalid_login
    gateway = OgoneGateway.new(
      login: 'login',
      user: 'user',
      password: 'password',
      signature: 'signature'
    )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end
end
