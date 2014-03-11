require 'test_helper'

class RemoteWepayTest < Test::Unit::TestCase

  def setup
    @gateway = WepayGateway.new(fixtures(:wepay))

    # cents
    @amount = 2000
    @credit_card = credit_card('5496198584584769', mock_creditcard)
    @declined_card = credit_card('')

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
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_successful_purchase_with_token
    assert response = @gateway.add_card(@credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
    payment_method = "#{response.authorization}"
    assert response = @gateway.purchase(@amount, payment_method, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_unsuccessful_purchase_with_token
    payment_method = "12345"
    assert response = @gateway.purchase(@amount, payment_method, @options)
    assert_failure response
  end

  def test_successful_add_card
    assert response = @gateway.add_card(@credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_unsuccessful_add_card
    options = @options.dup
    assert response = @gateway.add_card(@declined_card, @options)
    assert_failure response
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    # Need to wait for the payment to go to captured state
    sleep 30
    assert response = @gateway.refund(@amount - 100, response.authorization, { :refund_reason => "Refund" })
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '123')
    assert_failure response
  end

  def test_failed_void
    assert response = @gateway.void('123')
    assert_failure response
  end

  def test_authorize_and_capture
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    # Need to wait for the payment to go to captured state
    sleep 30
    assert capture = @gateway.capture(response.authorization)
    assert_success capture
    assert_equal "Success", capture.message
  end

  def test_authorize_and_void
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert void = @gateway.void(response.authorization, { :cancel_reason => "Cancel" })
    assert_success void
    assert_equal "Success", void.message
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
