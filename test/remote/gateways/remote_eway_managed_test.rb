require 'test_helper'

class RemoteEwayManagedTest < Test::Unit::TestCase
  def setup
    @gateway = EwayManagedGateway.new(fixtures(:eway_managed).merge({ :test => true }))

    @valid_card='4444333322221111'
    @valid_customer_id='9876543211000'

    @credit_card = credit_card(@valid_card)

    @options = {
      :billing_address => {
        :country => 'au',
        :title => 'Mr.'
      }
    }

    @amount = 100
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @valid_customer_id, @options)
    assert_equal "00,Transaction Approved(Test Gateway)", response.message
    assert_success response
    assert response.test?
    assert_not_nil response.authorization
  end

  def test_invalid_login
    gateway = EwayManagedGateway.new(
      :login => '',
      :password => '',
      :username => ''
    )
    assert response = gateway.purchase(@amount, @valid_customer_id, @options)
    assert_equal 'Login failed. ', response.message
    assert_failure response
  end

  def test_store_credit_card
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "OK", response.message
    assert !response.token.blank?
    assert_not_nil response.token
  end

  def test_update_credit_card
    assert response = @gateway.update(@valid_customer_id, @credit_card, @options)
    assert_success response
    assert_equal "OK", response.message
    assert response.token.blank?
  end

  # Eway seems to accept an invalid card by default
  def test_store_invalid_credit_card
    @credit_card.number = 2

    assert response = @gateway.store(@credit_card, @options)
    assert_success response
  end

  def test_retrieve
    assert response = @gateway.retrieve(@valid_customer_id)
    assert_success response
    assert_equal "OK", response.message
    assert response.test?
  end
end
