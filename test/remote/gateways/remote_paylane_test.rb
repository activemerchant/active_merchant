require 'test_helper'

class RemotePaylaneTest < Test::Unit::TestCase
  def setup
    @credentials = fixtures(:paylane)
    @gateway = PaylaneGateway.new(@credentials)

    @amount = 10000 # 100.00$ ActiveMerchant accepts all amounts as Integer values in cents
    @failed_amount_303 = 30300 # 303.00$ ActiveMerchant accepts all amounts as Integer values in cents
    @failed_message_303 = 'Direct debit declined.'
    @failed_amount_313 = 31300 # 313.00$ ActiveMerchant accepts all amounts as Integer values in cents
    @failed_message_313 = 'Customer name is not valid.'

    # test framework tries to run multiple tests simultaneously,
    # so we need to use different cards in different tests or we get following message from Paylane:
    # "Multiple same transactions lock triggered. Wait 6 s and try again."
    @credit_card = credit_card('4111111111111111')
    @credit_card2 = credit_card('4200000000000000')
    @credit_card3 = credit_card('5500000000000004')
    @credit_card4 = credit_card('4055018123456780')
    @credit_card5 = credit_card('4012001037167778')
    @credit_card6 = credit_card('4012001038443335')
    @credit_card7 = credit_card('4055019123456788')

    @credit_card_fail1 = credit_card('4012001036275556')
    @credit_card_fail2 = credit_card('4012001038488884')
    @credit_card_fail3 = credit_card('4012001037461114')

    @token_url = 'https://direct.paylane.com/rest.js/'

    @options = {
      billing_address: address,
      description: 'Store Purchase',
      email: "joe@example.com",
      ip: "127.0.0.1"
    }
  end

  def helper_fill_card_data(payment)
    post = {}
    post[:card_number] = payment.number
    post[:expiration_month] = sprintf('%02d', payment.month)
    post[:expiration_year] = payment.year.to_s
    post[:name_on_card] = "#{payment.first_name} #{payment.last_name}"
    post[:card_code] = payment.verification_value
    post[:public_api_key] = @credentials[:apikey]
    post
  end

  def helper_prepare_request(uri, post)
    request = Net::HTTP::Post.new(uri.request_uri)
    request["content-type"] = "application/json"
    request.basic_auth(@credentials[:login], @credentials[:password])
    request.body = post.to_json
    request
  end

  def helper_get_token(payment, _options)
    post = helper_fill_card_data(payment)
    uri = URI.parse("#{@token_url}cards/generateToken")
    request = helper_prepare_request(uri, post)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.request(request)
    response_json = JSON.parse(response.body)
    response_json['token']
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_purchase_by_token
    # get token is a helper method, because generateToken enpoint is only for JS client
    # token must be generated in it and then passed to PaylaneGateway module
    token = helper_get_token(@credit_card7, @options)
    response = @gateway.purchase(@amount, token, @options)
    assert_success response
  end

  def test_successful_purchase_by_account
    direct_debit = {}
    direct_debit[:account] = {}
    direct_debit[:account][:account_holder] = 'Hans Muller'
    direct_debit[:account][:account_country] =  'DE'
    direct_debit[:account][:iban] = 'BE68844010370034'
    direct_debit[:account][:bic] = 'BICBICDE'
    direct_debit[:account][:mandate_id] = '54321'
    response = @gateway.purchase(@amount, direct_debit, @options)
    assert_success response
  end

  def test_failed_purchase
    response = @gateway.purchase(@failed_amount_303, @credit_card_fail1, @options)
    assert_failure response
    assert_equal @failed_message_303, response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card2, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@failed_amount_303, @credit_card_fail2, @options)
    assert_failure response
    assert_equal @failed_message_303, response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card3, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Sale authorization ID 0 not found.', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card4, @options)
    assert_success purchase

    options = {
        reason: 'Refund Purchase'
    }
    assert refund = @gateway.refund(@amount, purchase.authorization, options)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card6, @options)
    assert_success purchase

    options = {
        reason: 'Refund Purchase'
    }
    assert refund = @gateway.refund(@amount-1, purchase.authorization, options)
    assert_success refund
  end

  def test_failed_refund
    options = {
        reason: 'Refund Purchase'
    }
    response = @gateway.refund(@amount, '', options)
    assert_failure response
    assert_equal 'Sale ID 0 not found.', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card5, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'Sale authorization ID 0 not found.', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match 'success', response.message
  end

  def test_failed_verify
    options = {
        billing_address: address,
        description: 'Store Purchase',
        email: "joe@example.com",
        ip: "127.0.0.1",
        amount: @failed_amount_313
    }
    response = @gateway.verify(@credit_card_fail3, options)
    assert_failure response
    assert_match @failed_message_313, response.message
  end

  def test_invalid_login
    gateway = PaylaneGateway.new(login: 'aa', password: 'bb')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Unauthorized [Wrong login or password or the account is disabled]', response.message
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
