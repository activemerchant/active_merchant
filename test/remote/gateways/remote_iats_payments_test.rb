require 'test_helper'

class IatsPaymentsTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = IatsPaymentsGateway.new(fixtures(:iats_payments))
    @amount = 100
    @credit_card = credit_card('4222222222222220')
    @check = check(routing_number: '111111111', account_number: '12345678')
    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => 'Store purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'Success', response.message
    assert response.authorization
  end

  def test_failed_purchase
    credit_card = credit_card('4111111111111111')
    assert response = @gateway.purchase(200, credit_card, @options)
    assert_failure response
    assert response.test?
    assert response.message.include?('REJECT')
  end

  def test_successful_check_purchase
    response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert response.test?
    assert_equal 'Success', response.message
    assert response.authorization
  end

  # Not possible to test failure case since tx failure is delayed from time of
  # submission w/ ACH, even for test txs.
  # def test_failed_check_purchase
  #   response = @gateway.purchase(125, @check, @options)
  #   assert_failure response
  #   assert response.test?
  #   assert_nil response.authorization
  # end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    credit_card = credit_card('4111111111111111')
    purchase = @gateway.purchase(@amount, credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_failure refund
  end

  def test_successful_check_refund
    purchase = @gateway.purchase(@amount, @check, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)

    # This is a dubious test. Basically testing that the refund failed b/c
    # the original purchase hadn't yet cleared. No way to test immediate failure
    # due to the delay in original tx processing, even for text txs.
    assert_failure refund
    assert_equal "REJECT: 3", refund.message
  end

  def test_failed_check_refund
    assert refund = @gateway.refund(@amount, "invalidref")
    assert_failure refund
    assert_equal "REJECT: 39", refund.message
  end

  def test_successful_store_and_unstore
    assert store = @gateway.store(@credit_card, @options)
    assert_success store
    assert store.authorization
    assert_equal "Success", store.message

    assert unstore = @gateway.unstore(store.authorization, @options)
    assert_success unstore
    assert_equal "Success", unstore.message
  end

  def test_failed_store
    credit_card = credit_card('4111')
    assert store = @gateway.store(credit_card, @options)
    assert_failure store
    assert_match /Invalid credit card number/, store.message
  end

  def test_invalid_login
    gateway = IatsPaymentsGateway.new(
      :agent_code => 'X',
      :password => 'Y',
      :region => 'na'
    )

    assert response = gateway.purchase(@amount, @credit_card)
    assert_failure response
  end

  def test_purchase_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(credit_card.number, transcript)
    assert_scrubbed(credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:agent_code], transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_check_purchase_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @check, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@check.routing_number, transcript)
    assert_scrubbed(@check.account_number, transcript)
    assert_scrubbed(@gateway.options[:agent_code], transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

end
