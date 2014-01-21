require 'test_helper'

class RemoteBalancedTest < Test::Unit::TestCase

  def setup
    @gateway = BalancedGateway.new(fixtures(:balanced))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @invalid_card = credit_card('4222222222222220')
    @declined_card = credit_card('4444444444444448')

    @options = {
        :email =>  'john.buyer@example.org',
        :billing_address => address,
        :description => 'Shopify Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction approved', response.message
    assert_equal @amount, response.params['debits'][0]['amount']
  end

  def test_invalid_card
    assert response = @gateway.purchase(@amount, @invalid_card, @options)
    assert_failure response
    assert_match /Customer call bank/, response.params['errors'][0]['description']
  end

  def test_invalid_email
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:email => 'invalid_email'))
    assert_failure response
    assert_match /Invalid field.*email/, response.params['errors'][0]['description']
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match /Account Frozen/, response.params['errors'][0]['description']
  end

  def test_passing_appears_on_statement
    options = @options.merge(appears_on_statement_as: "Homer Electric")
    assert response = @gateway.purchase(@amount, @credit_card, options)

    assert_success response
    assert_equal "BAL*Homer Electric", response.params['debits'][0]['appears_on_statement_as']
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Transaction approved', auth.message

    hold_id = auth.params["card_holds"][0]["id"]
    capture_url = auth.params["links"]["card_holds.debits"].gsub("{card_holds.id}", hold_id)

    assert capture = @gateway.capture(amount, capture_url)
    assert_success capture
    assert_equal amount, capture.params['debits'][0]['amount']

    auth_card_id = auth.params['card_holds'][0]['links']['card']
    capture_source_id = capture.params['debits'][0]['links']['source']

    assert_equal auth_card_id, capture_source_id
  end

  def test_authorize_and_capture_partial
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Transaction approved', auth.message

    hold_id = auth.params["card_holds"][0]["id"]
    capture_url = auth.params["links"]["card_holds.debits"].gsub("{card_holds.id}", hold_id)

    assert capture = @gateway.capture(amount / 2, capture_url)
    assert_success capture
    assert_equal amount / 2, capture.params['debits'][0]['amount']

    auth_card_id = auth.params['card_holds'][0]['links']['card']
    capture_source_id = capture.params['debits'][0]['links']['source']

    assert_equal auth_card_id, capture_source_id
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
  end

  def test_void_authorization
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    number = auth.params["card_holds"][0]["href"]
    assert void = @gateway.void(number)
    assert_success void
    assert void.params['is_void']
  end

  def test_refund_purchase
    assert debit = @gateway.purchase(@amount, @credit_card, @options)
    assert_success debit

    debit_id = debit.params["debits"][0]["id"]
    capture_url = debit.params["links"]["debits.refunds"].gsub("{debits.id}", debit_id)

    assert refund = @gateway.refund(@amount, capture_url)
    assert_success refund
    assert_equal @amount, refund.params['refunds'][0]['amount']
  end

  def test_refund_partial_purchase
    assert debit = @gateway.purchase(@amount, @credit_card, @options)
    assert_success debit
    assert refund = @gateway.refund(@amount / 2, debit.authorization)
    assert_success refund
    assert_equal @amount / 2, refund.params['amount']
  end

  def test_store
    new_email_address = '%d@example.org' % Time.now
    assert card_uri = @gateway.store(@credit_card, {
        :email => new_email_address
    })
    assert_instance_of String, card_uri
  end

  def test_invalid_login
    begin
      BalancedGateway.new(
        :login => ''
      )
    rescue BalancedGateway::Error => ex
      msg = ex.message
    else
      msg = nil
    end
    assert_equal 'Invalid login credentials supplied', msg
  end
end
