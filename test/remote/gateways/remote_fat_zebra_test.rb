require 'test_helper'

class RemoteFatZebraTest < Test::Unit::TestCase
  def setup
    @gateway = FatZebraGateway.new(fixtures(:fat_zebra))

    @amount = 100
    @credit_card = credit_card('5123456789012346')
    @declined_card = credit_card('4557012345678902')

    @options = {
      :order_id => rand(100000).to_s,
      :ip => "123.1.2.3"
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_invalid_data
    @options.delete(:ip)
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Customer ip can't be blank", response.message
  end

  def test_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)

    assert response = @gateway.refund(@amount, purchase.authorization, rand(1000000).to_s)
    assert_success response
    assert_match %r{Approved}, response.message
  end

  def test_invalid_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)

    assert response = @gateway.refund(@amount, nil, rand(1000000).to_s)
    assert_failure response
    assert_match %r{Original transaction is required}, response.message
  end

  def test_store
    assert card = @gateway.store(@credit_card)

    assert_success card
    assert_false card.authorization.nil?
  end

  def test_purchase_with_token
    assert card = @gateway.store(@credit_card)
    assert purchase = @gateway.purchase(@amount, card.authorization, @options.merge(:cvv => 123))
    assert_success purchase
  end

  def test_invalid_login
    gateway = FatZebraGateway.new(
                :username => 'invalid',
                :token => 'wrongtoken'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid Login', response.message
  end
end
