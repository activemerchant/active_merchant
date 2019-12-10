require 'test_helper'

class RemoteMerchantSuiteTest < Test::Unit::TestCase
  def setup
    @gateway = MerchantSuiteGateway.new(fixtures(:merchant_suite))

    @amount = 100
    @declined_amount = 105100
    approved_year = '00'
    declined_year = '54'
    @credit_card = credit_card('4987654321098769', month: '99', year: approved_year)
    @expired_card = credit_card('4987654321098769', month: '99', year: declined_year)
    @error_card = credit_card('498765432109', month: '99', year: approved_year)

    @options = {
      order_id: '1',
      address: address,
      description: 'Store Purchase',
      first_name: 'John',
      last_name: 'Smith',
      salutation: 'Mr',
      email: "john.smith@test.com",
      reference_1: '134'
    }
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)

    assert_success response
    assert_equal "Success", response.message
    assert_not_nil response.authorization
    assert_match %r(^\d{16}+$), response.authorization
  end

  def test_failed_store
    response = @gateway.store(@error_card)
    assert_failure response
    assert_equal "Invalid card number", response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_search_transaction
    reference_3 = "TokenToSearch-#{SecureRandom.uuid}"
    @options = @options.merge(reference_3: reference_3)
    @gateway.purchase(@amount, @credit_card, @options)

    response = @gateway.search_transaction({ reference_3: reference_3 })

    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_search_transaction
    response = @gateway.search_transaction({ reference_3: 'nonexistent token' })

    assert_failure response
    assert_equal 'Search returned no results', response.message
  end

  def test_successful_purchase_with_token
    store_response = @gateway.store(@credit_card, { email: "john.smith@test.com" })

    token = store_response.authorization
    @credit_card.number = token
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
  end

  def test_invalid_login
    gateway = MerchantSuiteGateway.new(
      username: 'abc',
      password: '123',
      membershipid: 'xyz'
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Invalid login details', response.message
    assert_failure response
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    credentials = @gateway.options[:username] + '|'
      + @gateway.options[:membershipid] + ':'
      + @gateway.options[:password]

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(Base64.strict_encode64(credentials), transcript)
  end
end
