require 'test_helper'

class AuthorizeNetArbTest < Test::Unit::TestCase
  def setup
    @gateway = AuthorizeNetArbGateway.new(fixtures(:authorize_net))
    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @check = check

    @options = {
      :amount => 100,
      :subscription_name => 'Test Subscription 1',
      :credit_card => @credit_card,
      :billing_address => address.merge(:first_name => 'Jim', :last_name => 'Smith'),
      :interval => {
        :length => 1,
        :unit => :months
      },
      :duration => {
        :start_date => Date.today,
        :occurrences => 1
      }
    }
  end

  def test_successful_recurring
    assert response = @gateway.recurring(@amount, @credit_card, @options)
    assert_success response
    assert response.test?

    subscription_id = response.authorization

    assert response = @gateway.update_recurring(:subscription_id => subscription_id, :amount => @amount * 2)
    assert_success response

    assert response = @gateway.status_recurring(subscription_id)
    assert_success response

    assert response = @gateway.cancel_recurring(subscription_id)
    assert_success response
  end

  def test_recurring_should_fail_expired_credit_card
    @credit_card.year = 2004
    assert response = @gateway.recurring(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'E00018', response.params['code']
  end

  def test_bad_login
    gateway = AuthorizeNetArbGateway.new(
      :login => 'X',
      :password => 'Y'
    )

    assert response = gateway.recurring(@amount, @credit_card, @options)
    assert_failure response
  end
end
