require 'test_helper'
require 'securerandom'

class RemoteNuveiTest < Test::Unit::TestCase
  def setup
    @gateway = NuveiGateway.new(fixtures(:nuvei))

    @amount = 100

    @bank_account = check(account_number: '123456789', routing_number: '121000358')

    @declined_bank_account = check(account_number: '123456789', routing_number: '121000348')

    @general_bank_account = check(name: 'A. Klaassen', account_number: '123456789', routing_number: 'NL13TEST0123456789')

    @credit_card = credit_card('4111111111111111')

    @amount = 1
    
    @options = {
      order_id: 1,
      billing_address: address,
      description: 'Fake purchase',
      ip: '127.0.0.1',
      email: 'test@test.com'
    }

    @declined_card = credit_card('4008370896662369')
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_authorize_fail_with_gwError_limit_exceeded
    response = @gateway.authorize(999999999, @declined_card, @options)
    assert_failure response
    assert_equal 'Limit exceeding amount', response.message
  end

  def test_successful_purchase
    options = @options.dup
    options[:order_id] = generate_unique_id
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
    # assert_equal 'There is another transaction with this clientRequestId.', response.message
  end

  def test_failure_missing_card_number
    options = @options.dup
    options[:order_id] = generate_unique_id
    bad_credit_card = credit_card(number: nil)

    response = @gateway.purchase(@amount, bad_credit_card, options)
    assert_failure response
    assert_equal 'Missing or invalid CardData data. Missing card number.', response.message
  end

  def test_failure_missing_cvv
    options = @options.dup
    options[:order_id] = generate_unique_id
    bad_credit_card = credit_card(options: {:verification_value => nil})
    response = @gateway.purchase(@amount, bad_credit_card, options)
    assert_failure response
    assert_equal 'Missing or invalid CardData data. Missing card number.', response.message
  end

  def test_failure_duplicate_order_id
    options = @options.dup
    options[:order_id] = SecureRandom.uuid
    response1 = @gateway.purchase(@amount, @credit_card, options)
    assert_success response1
    assert_equal 'Succeeded', response1.message

    response2 = @gateway.purchase(@amount, @credit_card, options)
    assert_failure response2
    assert_equal 'There is another transaction with this clientRequestId.', response2.message
  end

end
