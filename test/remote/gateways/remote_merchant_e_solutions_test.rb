require 'test_helper'

class RemoteMerchantESolutionTest < Test::Unit::TestCase


	def setup
	  Base.gateway_mode = :test

		@gateway = MerchantESolutionsGateway.new(fixtures(:merchant_esolutions))

		@amount = 100
		@credit_card = credit_card('4111111111111111')
		@declined_card = credit_card('4111111111111112')

		@options = {
		:billing_address => {
			:name     => 'John Doe',
			:address1 => '123 State Street',
			:address2 => 'Apartment 1',
			:city     => 'Nowhere',
			:state    => 'MT',
			:country  => 'US',
			:zip      => '55555',
			:phone    => '555-555-5555'
		}
	}
	end

	def test_successful_purchase
		assert response = @gateway.purchase(@amount, @credit_card, @options)
		assert_success response
    assert_equal 'This transaction has been approved', response.message
	end

	def test_unsuccessful_purchase
		assert response = @gateway.purchase(@amount, @declined_card, @options)
		assert_failure response
		assert_equal 'Card No. Error', response.message
		p response
	end

	def test_authorize_and_capture
		amount = @amount
		assert auth = @gateway.authorize(amount, @credit_card, @options)
		assert_success auth
		assert_equal 'This transaction has been approved', auth.message
		assert auth.authorization
		sleep 15  # I have found that it is best to wait a few seconds to capture an authorized transaction
		assert capture = @gateway.capture(amount, auth.authorization)
		assert_success capture
		assert_equal 'This transaction has been approved', capture.message
	end

	def test_failed_capture
		assert response = @gateway.capture(@amount, '')
		assert_failure response
		assert_equal 'Invalid Transaction ID', response.message
	end

	def test_store_purchase_unstore
		assert store = @gateway.store(@credit_card)
		assert_success store
		assert_equal 'This transaction has been approved', store.message
		assert purchase = @gateway.purchase(@amount, store.authorization, @options)
		assert_success purchase
		assert_equal 'This transaction has been approved', purchase.message
		assert unstore = @gateway.unstore(store.authorization)
		assert_success unstore
		assert_equal 'This transaction has been approved', unstore.message
		assert purchase_after_unstore = @gateway.purchase(@amount, store.authorization, @options)
		assert_failure purchase_after_unstore
		assert_equal 'Invalid Card ID', purchase_after_unstore.message
	end

	def test_authorize_and_void
		assert auth = @gateway.authorize(@amount, @credit_card, @options)
		assert_success auth
		assert_equal 'This transaction has been approved', auth.message
		assert auth.authorization
		assert void = @gateway.void(auth.authorization)
		assert_success void
		assert_equal 'This transaction has been approved', void.message
	end

	def test_unsuccessful_unstore
		assert unstore = @gateway.unstore('')
		assert_failure unstore
		assert_equal 'Invalid Card ID', unstore.message
	end

	def test_unsuccessful_void
		assert void = @gateway.void('')
		assert_failure void
		assert_equal 'Invalid Transaction ID', void.message
	end

	def test_successful_avs_check
    assert response = @gateway.purchase(@amount, @credit_card, @options)
		assert_equal 'Y', response.avs_result['code']
		assert_equal 'Street address and 5-digit postal code match.', response.avs_result['message']
		assert_equal 'Y', response.avs_result['street_match']
		assert_equal 'Y', response.avs_result['postal_match']
	end

	def test_unsuccessful_avs_check_with_bad_street_address
		options = {
		:billing_address => {
			:name     => 'John Doe',
			:address1 => '124 State Street',
			:address2 => 'Apartment 1',
			:city     => 'Nowhere',
			:state    => 'MT',
			:country  => 'US',
			:zip      => '55555',
			:phone    => '555-555-5555'
		}
	}
    assert response = @gateway.purchase(@amount, @credit_card, options)
		assert_equal 'Z', response.avs_result['code']
		assert_equal 'Street address does not match, but 5-digit postal code matches.', response.avs_result['message']
		assert_equal 'N', response.avs_result['street_match']
		assert_equal 'Y', response.avs_result['postal_match']
	end

	def test_unsuccessful_avs_check_with_bad_zip
		options = {
		:billing_address => {
			:name     => 'John Doe',
			:address1 => '123 State Street',
			:address2 => 'Apartment 1',
			:city     => 'Nowhere',
			:state    => 'MT',
			:country  => 'US',
			:zip      => '55554',
			:phone    => '555-555-5555'
		}
	}
    assert response = @gateway.purchase(@amount, @credit_card, options)
		assert_equal 'A', response.avs_result['code']
		assert_equal 'Street address matches, but 5-digit and 9-digit postal code do not match.', response.avs_result['message']
		assert_equal 'Y', response.avs_result['street_match']
		assert_equal 'N', response.avs_result['postal_match']
	end

	def test_successful_cvv_check
    assert response = @gateway.purchase(@amount, @credit_card, @options)
		assert_equal 'M', response.cvv_result['code']
		assert_equal 'Match', response.cvv_result['message']
	end

	def test_unsuccessful_cvv_check
		credit_card = ActiveMerchant::Billing::CreditCard.new({
										:first_name => 'John',
										:last_name  => 'Doe',
										:number => '4111111111111111',
										:month      => '11',
										:year       => (Time.now.year + 1).to_s,
										:verification_value => '555'
									})
    assert response = @gateway.purchase(@amount, credit_card, @options)
		assert_equal 'N', response.cvv_result['code']
		assert_equal 'No Match', response.cvv_result['message']
	end

	def test_invalid_login
		gateway = MerchantESolutionsGateway.new(
							:login => '',
							:password => ''
						)
		assert response = gateway.purchase(@amount, @credit_card, @options)
		assert_failure response
		assert_equal 'Invalid ID or Key', response.message
	end

  # On 03/14/2013 MeS has problems with the test enviroment.
  # Every time you wanted to access the API, it answered 404 NOT FOUND. 
  # That error message was not rescue anywhere.
  #
  # Exmaple of the output generated
  # test_unsuccessful_void(RemoteMerchantESolutionTest):
  # ActiveMerchant::ResponseError: Failed with 404 Not Found
  #     /home/carla/.rvm/gems/ruby-1.9.3-p327@activemerchant/gems/active_utils-1.0.5/lib/active_utils/common/posts_data.rb:64:in `handle_response'
  #     /home/carla/.rvm/gems/ruby-1.9.3-p327@activemerchant/gems/active_utils-1.0.5/lib/active_utils/common/posts_data.rb:30:in `ssl_request'
  #     /home/carla/.rvm/gems/ruby-1.9.3-p327@activemerchant/gems/active_utils-1.0.5/lib/active_utils/common/posts_data.rb:26:in `ssl_post'
  #     /active_merchant_xagax/lib/active_merchant/billing/gateways/merchant_e_solutions.rb:136:in `commit'
  #     /active_merchant_xagax/lib/active_merchant/billing/gateways/merchant_e_solutions.rb:87:in `void'
  #     /active_merchant_xagax/test/remote/gateways/remote_merchant_e_solutions_test.rb:92:in `test_unsuccessful_void'
  #     /home/carla/.rvm/gems/ruby-1.9.3-p327@activemerchant/gems/mocha-0.11.4/lib/mocha/integration/mini_test/version_230_to_262.rb:28:in `run'
  def test_connection_failure_404_notfound_with_purchase
    @gateway.test_url = 'https://cert.merchante-solutions.com/mes-api/tridentApiasdasd'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Failed with 404 Not Found', response.message    
  end

end
