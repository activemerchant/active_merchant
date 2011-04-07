require 'test_helper'

class RemoteMerchantWarriorTest < Test::Unit::TestCase

	def setup
		test_values = fixtures(:merchant_warrior)

		test_values[:test] = true
		@gateway = MerchantWarriorGateway.new(test_values)

		@success_amount = '100.00'
		# DO NOT USE DECIMALS FOR TOKEN TESTING
		@token_success_amount = '133.00'
		@failure_amount = '102.33'
		@credit_card = credit_card('4564710000000004',
															 :month => 2,
															 :year => 19,
															 :verification_value => '847',
															 :type => 'visa')
		@token_card = credit_card('4564710000000004',
															 :month => 2,
															 :year => 19,
															 :verification_value => '847',
															 :type => 'visa')
		@expired_card = credit_card('4564710000000012',
															 :month => 2,
															 :year => 5,
															 :verification_value => '963',
															 :type => 'visa')

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
		assert response = @gateway.process_card(@success_amount, @credit_card, @options)
		assert_equal 'Transaction approved', response.params["response_message"]
		assert_success response
	end

	def test_unsuccessful_purchase
		assert response = @gateway.process_card(@failure_amount, @expired_card, @options)
		# assert_equal 'Card has expired', response.params["response_message"]
		assert_equal "MW - 006:Field 'paymentCardExpiry' is invalid", response.params["response_message"]
		assert_failure response
	end

	def test_successful_credit
		#first make a purchase, to be credited
		assert response = @gateway.process_card(@success_amount, @credit_card, @options)
		transaction_id = response.params["transaction_id"]

		assert response = @gateway.refund_card(@success_amount, transaction_id,
																			@options)

		assert_instance_of Response, response
		assert_equal 'Transaction approved', response.params["response_message"]
		assert_success response
	end

	def test_unsuccessful_credit
		assert response = @gateway.refund_card(@success_amount, 'invalid-transaction-id',
																			@options)
		assert_instance_of Response, response
		assert_equal 'MW - 011:Invalid transactionID', response.params["response_message"]
		assert_failure response
	end

	def test_card_auth
		assert response = @gateway.process_auth('150.00', @credit_card, @options)
		assert_equal '0', response.params["response_code"]
		assert_equal 'Transaction approved', response.params["response_message"]
		# assert_equal '0', response.params["auth_response_code"]
		# assert_equal 'Approved', response.params["auth_message"]
		transaction_id = response.params["transaction_id"]
		auth_code = response.params["auth_code"]
		assert_success response
		
		assert response = @gateway.process_capture(@success_amount, transaction_id, @success_amount)
		assert_success response
	end


	def test_successful_token_purchase
		assert response = @gateway.token_add_card(@token_card)
		assert_instance_of Response, response
		assert_equal 'Operation successful', response.params["response_message"]
		assert_success response

		card_id = response.params["card_id"]
		card_key = response.params["card_key"]
		card_replace = @gateway.card_replace_key
		
		assert response = @gateway.token_process_card(@token_success_amount, card_id, card_key, card_replace, @options)
		assert_equal 'Transaction approved', response.params["response_message"]
	end

	def test_token_auth
		assert response = @gateway.token_add_card(@token_card)
		assert_instance_of Response, response
		assert_equal 'Operation successful', response.params["response_message"]
		assert_success response

		card_id = response.params["card_id"]
		card_key = response.params["card_key"]
		card_replace = @gateway.card_replace_key

		assert response = @gateway.token_process_auth(@token_success_amount, card_id, card_key, card_replace, @options)
		assert_equal '0', response.params["response_code"]
		assert_equal 'Transaction approved', response.params["response_message"]
		# assert_equal '0', response.params["auth_response_code"]
		# assert_equal 'Approved', response.params["auth_message"]
		transaction_id = response.params["transaction_id"]
		auth_code = response.params["auth_code"]
		assert_success response
		
		assert response = @gateway.process_capture(@token_success_amount, transaction_id, @token_success_amount)
		assert_success response
	end


end