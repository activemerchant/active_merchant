require 'test_helper'

class RemoteStripeConnectTest < Test::Unit::TestCase
  def setup
    @gateway = StripeGateway.new(fixtures(:stripe))

    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @declined_card = credit_card('4000000000000002')
    @new_credit_card = credit_card('5105105105105100')

    @options = {
      :currency => 'USD',
      :description => 'ActiveMerchant Test Purchase',
      :email => 'wow@example.com',
      :stripe_account => fixtures(:stripe_destination)[:stripe_user_id]
    }
  end

  def test_application_fee_for_stripe_connect
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:application_fee => 12))
    assert_success response
  end

  def test_successful_refund_with_application_fee
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:application_fee => 12))
    assert refund = @gateway.refund(@amount, response.authorization, @options.merge(:refund_application_fee => true))
    assert_success refund

    # Verify the application fee is refunded
    fetch_fee_id = @gateway.send(:fetch_application_fee, response.authorization, @options)
    fee_id = @gateway.send(:application_fee_from_response, fetch_fee_id)
    refund_check = @gateway.send(:refund_application_fee, 10, fee_id, @options)
    assert_equal 'Application fee could not be refunded: Refund amount ($0.10) is greater than unrefunded amount on fee ($0.00)', refund_check.message
  end

  def test_refund_partial_application_fee
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:application_fee => 12))
    assert refund = @gateway.refund(@amount-20, response.authorization, @options.merge(:refund_fee_amount => '10'))
    assert_success refund

    # Verify the application fee is partially refunded
    fetch_fee_id = @gateway.send(:fetch_application_fee, response.authorization, @options)
    fee_id = @gateway.send(:application_fee_from_response, fetch_fee_id)
    refund_check = @gateway.send(:refund_application_fee, 10, fee_id, @options)
    assert_equal 'Application fee could not be refunded: Refund amount ($0.10) is greater than unrefunded amount on fee ($0.02)', refund_check.message
  end

  def test_refund_application_fee_amount_zero
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:application_fee => 12))
    assert refund = @gateway.refund(@amount-20, response.authorization, @options.merge(:refund_fee_amount => '0'))
    assert_success refund

    # Verify the application fee is not refunded
    fetch_fee_id = @gateway.send(:fetch_application_fee, response.authorization, @options)
    fee_id = @gateway.send(:application_fee_from_response, fetch_fee_id)
    refund_check = @gateway.send(:refund_application_fee, 14, fee_id, @options)
    assert_equal 'Application fee could not be refunded: Refund amount ($0.14) is greater than fee amount ($0.12)', refund_check.message
  end
end
