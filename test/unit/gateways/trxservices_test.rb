require 'test_helper'

class RemoteTrxservicesTest < Test::Unit::TestCase
  def setup
    @gateway = TrxservicesGateway.new(fixtures(:trxservices))
    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      :number             => '4111111111111111',
      :month              => 12,
      :year               => 2019,
      :first_name         => 'Tami',
      :last_name          => 'Fenwick'
    )
    @declined_card = ActiveMerchant::Billing::CreditCard.new(
      :number             => "4000300011112220",
      :month              => 12,
      :year               => 2014,
      :first_name         => 'Joe',
      :last_name          => 'Timmer'
    )
    @credit_card.verification_value = 346
    @amount = 14.12
    @address = { address1: '805 Hickory St', zip: 68108, city: 'Omaha', state: 'NE', country: 'USA' }
    @email = 'tami@hitfactory.co.nz'
  end

  def test_successful_purchase
    amount = rand(10..99).to_s + '.' + rand.to_s[2..3]
    response = @gateway.purchase(amount, @credit_card, address: @address, email: @email)

    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_purchase
    amount = rand(10..99).to_s + '.' + rand.to_s[2..3]
    response = @gateway.purchase(amount, @declined_card, address: @address, email: @email)
    assert_failure response
    assert_equal 'Validation Error (app business logic failure)', response.message
  end

  def test_successful_authorize_and_capture
    amount = rand(10..99).to_s + '.' + rand.to_s[2..3]
    auth = @gateway.authorize(amount, @credit_card, address: @address, email: @email)
    assert_success auth

    assert capture = @gateway.capture(amount, guid: auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_failed_authorize
    amount = rand(10..99).to_s + '.' + rand.to_s[2..3]
    response = @gateway.authorize(amount, @declined_card,  address: @address, email: @email)
    assert_failure response
    assert_equal 'Validation Error (app business logic failure)', response.message
  end

  def test_partial_capture
    amount = rand(10..99).to_s + '.' + rand.to_s[2..3]
    auth = @gateway.authorize(amount, @credit_card, address: @address, email: @email)
    assert_success auth

    assert capture = @gateway.capture(amount.to_f - 1, guid: auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    amount = rand(10..99).to_s + '.' + rand.to_s[2..3]
    response = @gateway.capture(@amount, guid: 'bad guid')
    assert_failure response
    assert_equal 'Validation Error (app business logic failure)', response.message
  end

  def test_successful_refund
    amount = rand(10..99).to_s + '.' + rand.to_s[2..3]
    purchase = @gateway.purchase(amount, @credit_card, address: @address, email: @email)
    assert_success purchase

    assert refund = @gateway.refund(amount, guid: purchase.authorization)
    assert_success refund
    assert_equal 'Approved', refund.message
  end

  def test_partial_refund
    amount = rand(10..99).to_s + '.' + rand.to_s[2..3]
    purchase = @gateway.purchase(amount, @credit_card, address: @address, email: @email)
    assert_success purchase

    assert refund = @gateway.refund(amount.to_f - 1, guid: purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    amount = rand(10..99).to_s + '.' + rand.to_s[2..3]
    response = @gateway.refund(amount, guid: 'bad guid')
    assert_failure response
    assert_equal 'Validation Error (app business logic failure)', response.message
  end

  def test_successful_void
    amount = rand(10..99).to_s + '.' + rand.to_s[2..3]
    purchase = @gateway.purchase(amount, @credit_card, address: @address, email: @email)
    assert_success purchase

    assert void = @gateway.void(amount, guid: purchase.authorization)
    assert_success void
    assert_equal 'Approved', void.message
  end

  def test_failed_void
    amount = rand(10..99).to_s + '.' + rand.to_s[2..3]
    response = @gateway.void(amount, guid: 'bad guid')
    assert_failure response
    assert_equal 'Validation Error (app business logic failure)', response.message
  end

end
