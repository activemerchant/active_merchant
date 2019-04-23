require 'test_helper'

class RemoteFlo2cashRestTest < Test::Unit::TestCase
  def setup
    @gateway = Flo2cashRestGateway.new(fixtures(:flo2cash_rest))

    @amount = 1000
    @card_declined_amount = 1751
    @credit_card = credit_card('4000100011112224')

    @auth_options = {
      api_key: fixtures(:flo2cash_rest)[:api_key],
      merchant_id: fixtures(:flo2cash_rest)[:merchant_id],
    }

    @payment_options = {
      start_date: Date.today.next_month.to_s(:ymd),
      initial_date: Date.today.next_month.to_s(:ymd),
      amount: @amount,
      currency: 'NZD',
      email: 'john.doe@test.com',
      first_name: 'John',
      last_name: 'Doe',
      title: 'Mr.',
      address: address.merge({ state: 'VIC', country: 'NZ' }),
      frequency: 'monthly'
    }

    @debit_options = @payment_options.merge({
      start_date: Date.today.next_month.to_s(:ymd),
      initial_date: Date.today.next_month.to_s(:ymd),
      bank_name: 'BNZ',
      bank_address1: '123 Street',
      bank_address2: 'Suburb, City',
      account_name: 'Account Name',
      account_number: '4411000000000000'
    })

    @options = @auth_options.merge(@payment_options)
  end

  def test_success_store
    response = @gateway.store(@credit_card, @auth_options)
    assert_success response
  end

  def test_fail_store
    invalid_card = credit_card('1')
    response = @gateway.store(invalid_card, @auth_options)
    assert_failure response
    assert_equal 'Card number is not valid', response.message
  end

  def test_success_create_card_plan
    store = @gateway.store(@credit_card, @auth_options)
    assert_success store

    response = @gateway.create_card_plan(store.authorization, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_fail_create_card_plan
    store = @gateway.store(@credit_card, @auth_options)
    assert_success store

    fail_options = @options.except(:frequency)
    response = @gateway.create_card_plan(store.authorization, fail_options)
    assert_failure response
    assert_equal 'Frequency can not be empty', response.message
  end

  def test_success_update_card_plan
    # Tokenize
    store = @gateway.store(@credit_card, @auth_options)
    assert_success store

    # Create an active Card Plan
    card_plan = @gateway.create_card_plan(store.authorization, @options)
    assert_success card_plan
    assert_equal 'Succeeded', card_plan.message

    # Change the Card Plan Status
    response = @gateway.update_card_plan(card_plan.authorization, 'cancelled', @options)
    assert_success response

    assert_equal 'cancelled', response.params['status']
  end

  def test_success_retrieve_card_plan
    # Tokenize
    store = @gateway.store(@credit_card, @auth_options)
    assert_success store

    # Create an active Card Plan
    card_plan = @gateway.create_card_plan(store.authorization, @options)
    assert_success card_plan
    assert_equal 'Succeeded', card_plan.message

    # Retrieve Card Plan
    response = @gateway.retrieve_card_plan(card_plan.authorization, @options)
    assert_success response
  end

  def test_fail_retrieve_card_plan
    response = @gateway.retrieve_card_plan('1', @options)
    assert_failure response

    assert_equal 'Card Plan not found', response.message
  end

  def test_successful_purchase_with_credit_card
    options = @options.merge(@auth_options)
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_successful_purchase_with_token
    store = @gateway.store(@credit_card, @auth_options)
    assert_success store

    response = @gateway.purchase(@amount, store.authorization, @options)
    assert_success response
  end

  def test_fail_purchase
    response = @gateway.purchase(@card_declined_amount, @credit_card, @options)
    assert_failure response

    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
    assert_equal 'declined - insufficient funds', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
    assert_equal 'Succeeded', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization, @options)
    assert_success refund
  end

  def test_fail_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount * 2, purchase.authorization, @options)
    assert_failure refund
    assert_equal 'This Refund would exceed the amount of the original transact', refund.message
  end

  def test_success_card_payment
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    response = @gateway.retrieve_card_payment(purchase.authorization, @options)
    assert_success response
  end

  def test_fail_card_payment
    response = @gateway.retrieve_card_payment('1', @options)
    assert_failure response
    assert_equal 'Payment not found', response.message
  end

  def test_success_create_direct_debit_plan
    options = @debit_options.merge(@auth_options)
    response = @gateway.create_direct_debit_plan(options)
    assert_success response
  end

  def test_fail_create_direct_debit_plan
    options = @debit_options.merge(@auth_options).except(:account_number)
    response = @gateway.create_direct_debit_plan(options)
    assert_failure response
    assert_equal "'Bank Details. Account. Number' must not be empty.", response.message
  end

  def test_success_retrieve_direct_debit_plan
    options = @debit_options.merge(@auth_options)
    direct_debit = @gateway.create_direct_debit_plan(options)
    assert_success direct_debit

    response = @gateway.retrieve_direct_debit_plan(direct_debit.authorization, @auth_options)
    assert_success response
  end

  def test_fail_retrieve_direct_debit_plan
    response = @gateway.retrieve_direct_debit_plan('1', @auth_options)
    assert_failure response
    assert_equal 'Direct Debit Plan not found', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@gateway.options[:merchant_id], transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
  end
end
