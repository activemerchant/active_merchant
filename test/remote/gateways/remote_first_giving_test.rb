require 'test_helper'

class RemoteFirstGivingTest < Test::Unit::TestCase


  def setup
    @gateway = FirstGivingGateway.new(fixtures(:first_giving))

    @amount = 100
    @credit_card = credit_card("4457010000000009", mock_creditcard)
    @declined_card = credit_card("445701000000000", mock_creditcard)
    @invalid_transaction_id = 0

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
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Unfortunately, we were unable to perform credit card number validation. The credit card number validator responded with the following message  ccNumber failed data validation for the following reasons :  creditcardLength: 445701000000000 contains an invalid amount of digits.", response.message
  end

  # TODO: Firstgiving not support refund API in Sandbox!
  #def test_successful_refund
    # donationId from report
  #  donation_id = 504614
  #  transaction_id = ""
  #  assert response = @gateway.refund(@amount, transaction_id, donation_id, @options)
  #  assert_equal 'Success', response.message
  #end

  def test_unsuccessful_refund
    assert response = @gateway.refund(@amount, @invalid_transaction_id, @options)
    assert_failure response
  end

  def test_invalid_login
    gateway = FirstGivingGateway.new(
                :application_key => '25151616',
                :security_token  => '63131jnkj'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "An error occurred. Please check your input and try again.", response.message
  end

  private

  def mock_creditcard
    creditcard = {
      :brand              => "visa",
      :month              => "01",
      :year               => "24",
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
