require 'test_helper'

class RemoteFirstGivingTest < Test::Unit::TestCase


  def setup
    @gateway = FirstGivingGateway.new(fixtures(:first_giving))

    @amount = 100
    @credit_card = credit_card("4457010000000009", mock_creditcard)
    @declined_card = credit_card("445701000000000", mock_creditcard)

    @options = {
      :order_id => '1',
      :billing_address => address(mock_address),
      :description => "Test transaction",
      :charity_id => "1234",
      :currency  => "USD"
    }

    @options.merge!(mock_user)
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_unsuccessful_purchase
    assert_raise(ActiveMerchant::ResponseError) { @gateway.purchase(@amount, @declined_card, @options) }
  end

  def test_invalid_login
    gateway = FirstGivingGateway.new(
                :application_key => '',
                :security_token  => ''
              )
    assert_raise(ActiveMerchant::ResponseError) { gateway.purchase(@amount, @credit_card, @options) }
  end

  private

  def mock_creditcard
    creditcard = {
      :brand              => "visa",
      :month              => "01",
      :year               => "14",
      :verification_value => "349",
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
