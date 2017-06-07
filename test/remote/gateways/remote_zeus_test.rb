require 'test_helper'

# Running remote tests -:
# NOTE: Please create a Zeus account to obtain a valid clientip. Add it to fixtures.yml file.
# Create a test card on Zeus Web GUI and update the +setup+ method to initialize the gateway properly.
class RemoteZeusTest < Test::Unit::TestCase
  def setup
    @gateway = ZeusGateway.new(fixtures(:zeus))
    @amount = 100
    @credit_card = credit_card('4348293542861948', { year: '20', month: '02' })
    @declined_card = credit_card('5614685177999992')

    @options = {
      telno: '9876787654',
      telnocheck: 'yes',
      sendid: 'fake_id',
      printord: 'yes'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Success_order', response.message[:status]
    assert_equal false, response.authorization.nil?
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)

    assert_failure response
    assert_equal 'failure_order', response.message[:status]
    assert_equal false, response.authorization.nil?
  end

  def test_successful_authorize
    initial_auth = @gateway.purchase(0, @credit_card, @options)
    response = @gateway.authorize(@amount, initial_auth.authorization, (Date.today + 2.days).to_s.gsub('-', ''))

    assert_success initial_auth
    assert_success response
    assert_equal false, response.authorization.nil?
  end

  def test_failed_authorize
    initial_auth = @gateway.purchase(0, @credit_card, @options)
    response = @gateway.authorize(@amount, initial_auth.authorization, (Date.today - 1.day).to_s.gsub('-', ''))

    assert_success initial_auth
    assert_failure response
    assert_equal false, response.authorization.nil?
  end

  def test_successful_capture
    initial_auth = @gateway.purchase(0, @credit_card, @options)
    auth = @gateway.authorize(@amount, initial_auth.authorization, (Date.today + 2.days).to_s.gsub('-', ''))
    response = @gateway.capture(@amount, initial_auth.authorization, (Date.today + 2.days).to_s.gsub('-', ''))

    assert_success initial_auth
    assert_success auth
    assert_success response
    assert_equal false, response.authorization.nil?
  end

  def test_failed_capture
    initial_auth = @gateway.purchase(0, @credit_card, @options)
    auth = @gateway.authorize(@amount, initial_auth.authorization, (Date.today + 2.days).to_s.gsub('-', ''))
    response = @gateway.capture(@amount, initial_auth.authorization, (Date.today - 1.day).to_s.gsub('-', ''))

    assert_success initial_auth
    assert_success auth
    assert_failure response
    assert_equal false, response.authorization.nil?
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    response = @gateway.refund(purchase.authorization)

    assert_success purchase
    assert_success response
    assert_equal false, response.authorization.nil?
  end

  def test_failed_refund
    response = @gateway.refund('Fake-Order-Id')

    assert_failure response
    assert_equal false, response.authorization.nil?
  end

end
