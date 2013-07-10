require 'test_helper'

class RemoteApp55Test < Test::Unit::TestCase


  def setup
  # Need to match setup in the account under test
    @gateway = App55Gateway.new(fixtures(:app55))
    @user_id = 3
    @card_token = "uPfuV"

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @duff_card = credit_card('400030001111222')

    @options = {
      :customer => @user_id,      #id - (name not supported yet)
      :billing_address => address,
      :description => 'app55 active merchant remote test',
      :currency => "GBP"
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.params["sig"]
    assert response.params["transaction"]["auth_code"]

    assert_equal @options[:description], response.params["transaction"]["description"]
    assert_equal @options[:currency], response.params["transaction"]["currency"]
    assert_equal "%.2f" % (@amount / 100), response.params["transaction"]["amount"]

  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @duff_card, @options)
    assert_failure response
    # check failure code
    assert_equal "Invalid card number supplied.", response.message
  end

  def test_successful_purchase_token
    assert response = @gateway.purchase(@amount, @card_token, @options)
    assert_success response
    assert response.params["sig"]
    assert response.params["transaction"]["auth_code"]
  end

  def test_unsuccessful_purchase_token
    assert response = @gateway.purchase(@amount,"NotOk", @options)
    assert_failure response
    # check failure code
    assert_equal "The requested transaction failed.", response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert response = @gateway.authorize(amount, @credit_card, @options)
    assert_success response
    assert response.params["transaction"]
    assert_equal @options[:description], response.params["transaction"]["description"]
    assert_equal @options[:currency], response.params["transaction"]["currency"]
    assert_equal "%.2f" % (@amount / 100), response.params["transaction"]["amount"]

    assert capture = @gateway.capture(amount, response.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert !response.params["transaction"]
  end

  def test_invalid_login
    gateway = App55Gateway.new(
                :ApiKey => 'xNSACPYP9ZDUr4860gV9vqvR7TxmVMJP',
                :ApiSecret => 'Gw3IK8Ywrofb36PYcZyXK5bT28ONElV3'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The credentials supplied did not match an API account.', response.message
  end

  def test_store_card
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert response.params["sig"]
    assert response.params["card"]["token"]
    assert_equal @credit_card.number.to_s.last(4), response.params["card"]["number"].to_s.last(4)
  end

  def test_unstore_card
    #create card
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert response.params["sig"]
    assert response.params["card"]["token"]
    authorization =  response.params["card"]["token"]

    #remove it
    assert response = @gateway.unstore(authorization, @options)
    assert_success response
    assert response.params["sig"]
  end

  def test_unstore_nocard
    #Currently the app5 api returns a success - will improve this in future iterations
    assert response = @gateway.unstore("NotOK", @options)
    # TBD assert_failure response
    assert response.params["sig"]
  end
end
