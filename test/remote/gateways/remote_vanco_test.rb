require 'test_helper'

class RemoteVancoTest < Test::Unit::TestCase
  SECONDS_PER_DAY = 3600 * 24

  def setup
    @gateway = VancoGateway.new(fixtures(:vanco))

    @amount = 10005
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4111111111111111', year: 2011)
    @check = check

    @options = {
      order_id: '1',
      billing_address: address(country: "US", state: "NC", zip: "06085"),
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Success", response.message
  end

  def test_successful_purchase_with_fund_id
    response = @gateway.purchase(@amount, @credit_card, @options.merge(fund_id: "TheFund"))
    assert_success response
    assert_equal "Success", response.message
  end

  def test_successful_purchase_with_ip_address
    response = @gateway.purchase(@amount, @credit_card, @options.merge(ip: "192.168.19.123"))
    assert_success response
    assert_equal "Success", response.message
  end

  def test_successful_purchase_with_existing_session_id
    previous_login_response = @gateway.send(:login)

    response = @gateway.purchase(
      @amount,
      @credit_card,
      @options.merge(
        session_id:
          {
            id: previous_login_response.params['response_sessionid'],
            created_at: Time.parse(previous_login_response.params['auth_requesttime'])
          }
      )
    )
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_expired_session_id
    two_days_from_now = Time.now - (2 * SECONDS_PER_DAY)
    previous_login_response = @gateway.send(:login)

    response = @gateway.purchase(
      @amount,
      @credit_card,
      @options.merge(
        session_id: {
          id: previous_login_response.params['response_sessionid'],
          created_at: two_days_from_now
        }
      )
    )
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_sans_minimal_options
    response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal "Success", response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card)
    assert_failure response
    assert_equal("Invalid Expiration Date", response.message)
    assert_equal("183", response.params["error_codes"])
  end

  def test_successful_echeck_purchase
    response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert response.test?
    assert_equal 'Success', response.message
  end

  def test_failed_echeck_purchase
    response = @gateway.purchase(@amount, check(routing_number: "121042883"), @options)
    assert_failure response
    assert_equal 'Invalid Routing Number', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal "Success", refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount+500, purchase.authorization)
    assert_failure refund
    assert_match(/Amount Cannot Be Greater Than/, refund.message)
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

  def test_account_number_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @check, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@check.account_number, clean_transcript)
  end

  def test_invalid_login
    gateway = VancoGateway.new(
      user_id: 'unknown_id',
      password: 'unknown_pwd',
      client_id: ''
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Invalid Login Key", response.message
  end
end
