require 'test_helper'

class RemoteMerchantWarriorTest < Test::Unit::TestCase

  def setup
    test_values = fixtures(:merchant_warrior)

    test_values[:test] = true
    @gateway = MerchantWarriorGateway.new(test_values)

    @success_amount = '100.00'
    @failure_amount = '100.33'
    @credit_card = credit_card('5123456789012346',
                               :month => 5,
                               :year => 2013,
                               :verification_value => '123',
                               :type => 'master')

    @token_credit_card = credit_card('5123456789012346',
                               :month => 05,
                               :year => 13,
                               :verification_value => '123',
                               :type => 'master')

    @options = {
      :address => {
        :name => 'Longbob Longsen',
        :country => 'AU',
        :state => 'Queensland',
        :city => 'Brisbane',
        :address1 => '123 test st',
        :zip => '4000'
      },
      :transaction_product => 'TestProduct',
      :credit_amount => @success_amount
    }

  end

  def test_successful_purchase
    assert response = @gateway.purchase(@success_amount, @credit_card, @options)
    assert_equal 'Transaction approved', response.params["response_message"]
    assert_success response
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@failure_amount, @credit_card, @options)
    assert_equal 'Card has expired', response.params["response_message"]
    assert_failure response
  end

  def test_successful_credit
    #first make a purchase, to be credited
    assert response = @gateway.purchase(@success_amount, @credit_card, @options)
    transaction_id = response.params["transaction_id"]

    assert response = @gateway.credit(@success_amount, transaction_id,
                                      @options)

    assert_instance_of Response, response
    assert_equal 'Transaction approved', response.params["response_message"]
    assert_success response
  end

  def test_unsuccessful_credit
    assert response = @gateway.credit(@success_amount, 'invalid-transaction-id',
                                      @options)
    assert_instance_of Response, response
    assert_equal 'MW - 011:Invalid transactionID', response.params["response_message"]
    assert_failure response
  end

  def test_successful_token_purchase
    assert response = @gateway.token_addcard(@token_credit_card)
    assert_instance_of Response, response
    assert_equal 'Operation successful', response.params["response_message"]
    assert_success response

		card_id = response.params["card_id"]
		card_key = response.params["card_key"]
		card_replace = @gateway.card_replace_key
		puts card_replace
		
		assert response = @gateway.token_processcard(@success_amount, card_id, card_key, card_replace, @options)
  end

end