require 'test_helper'

class RemoteWepayTest < Test::Unit::TestCase

  def setup
    @gateway = WepayGateway.new(fixtures(:wepay))

    # cents
    @amount = 1000000
    @credit_card = credit_card('5496198584584769', mock_creditcard)
    @declined_card = credit_card('4000300011112220')

    @options = {
      :order_id => '1',
      :billing_address => address(mock_address),
      :description => 'Store Purchase',
      :type => "GOODS"
    }

    @options.merge!(mock_user)
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_unsuccessful_purchase
    options = @options.dup
    options[:type] = "TOTO"
    assert response = @gateway.purchase(@amount, @declined_card, options)
    assert_failure response
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    sleep 30
    assert response = @gateway.refund(@amount, response.authorization, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert_raise(NotImplementedError) { @gateway.authorize(@amount, @declined_card, @options) }
  end

  def test_failed_capture
    assert_raise(NotImplementedError) { @gateway.capture(@amount, '') }
  end

  def test_invalid_login
    gateway = WepayGateway.new(
                           :client_id => 12515,
                           :account_id => 'abc',
                           :access_token => 'def',
                           :use_staging => true
                           )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  private

  def mock_creditcard
    creditcard = {
      :brand              => "visa",
      :month              => "4",
      :year               => "15",
      :verification_value => "123",
      :first_name         => "Smith",
      :last_name          => "John"
    }
    creditcard
  end

  def mock_address
    address = {
      :address1  => "1 Main St.",
      :city      => "Burlington",
      :state     => "MA",
      :zip       => "01803",
      :country   => "US"
    }
    address
  end

  def mock_user
    user = {
      :email  => "test@example.com",
      :ip     => "10.10.73.61"
    }
  end

end
