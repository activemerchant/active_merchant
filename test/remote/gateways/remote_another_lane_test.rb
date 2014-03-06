require 'test_helper'

class RemoteAnotherLaneTest < Test::Unit::TestCase
  def setup
    fixtures = fixtures(:another_lane)

    @gateway = AnotherLaneGateway.new(fixtures)

    # Do not change this value because 210 JPY is specified by gatway company.
    @amount = 210

    # valid acctual credit card is needed for testing APIs
    credit_card_hash = fixtures[:acctual_credit_card]
    @credit_card = CreditCard.new({
      :number             => credit_card_hash[:number],
      :month              => credit_card_hash[:month],
      :year               => credit_card_hash[:year],
      :first_name         => credit_card_hash[:first_name],
      :last_name          => credit_card_hash[:last_name],
      :verification_value => credit_card_hash[:verification_value],
      :brand              => credit_card_hash[:brand],
    })


    @declined_card = credit_card('40000000000000001')


    @options = {
      billing_address: address,
      customer_id: 'customer_id',
      customer_password: 'password',
    }


    @options_quick = {
      customer_id: 'customer_id',
      customer_password: 'password',
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_quick_purchase
    response = @gateway.purchase(@amount, nil, @options_quick)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_match(/thanks/, response.message)
  end

  def test_successful_store_mail
    response = @gateway.store_mail(@credit_card, @options)
    assert_success response
    assert_match(/thanks/, response.message)
  end

  def test_successful_get_status
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    response = @gateway.get_status(response.authorization)
    assert_success response

  end

  def test_successful_void
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert void = @gateway.void(response.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
  end

  def test_invalid_login
    gateway = AnotherLaneGateway.new(
      site_id: 'test',
      site_password: 'test'
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
