require File.dirname(__FILE__) + '/../test_helper'

class RemoteBrainTreeTest < Test::Unit::TestCase
  AMOUNT = 10000

  def setup
    @gateway = BrainTreeGateway.new(fixtures(:brain_tree))

    @creditcard = credit_card('4111111111111111',
                   :type => 'visa'
                  )

    @declined_amount = rand(99)
    @amount = rand(10000)+1001

    @options = {  :order_id => generate_order_id,
                  :address => { :address1 => '1234 Shady Brook Lane',
                                :zip => '90210'
                              }
               }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @creditcard, @options)
    assert_equal 'This transaction has been approved', response.message
    assert_success response
  end
  
  def test_successful_purchase_with_echeck
    check = ActiveMerchant::Billing::Check.new(:name => 'Fredd Bloggs',
                                               :routing_number => '111000025', # Valid ABA # - Bank of America, TX
                                               :account_number => '999999999999',
                                               :account_holder_type => 'personal',
                                               :account_type => 'checking')
    assert response = @gateway.purchase(@amount, check, @options)
    assert_equal 'This transaction has been approved', response.message
    assert_success response
  end
  
  def test_successful_add_to_vault
    @options[:store] = true
    assert response = @gateway.purchase(@amount, @creditcard, @options)
    assert_equal 'This transaction has been approved', response.message
    assert_success response
    assert_not_nil response.params["customer_vault_id"]
  end

  def test_successful_add_to_vault_and_use
    @options[:store] = true
    assert response = @gateway.purchase(@amount, @creditcard, @options)
    assert_equal 'This transaction has been approved', response.message
    assert_success response
    assert_not_nil customer_id = response.params["customer_vault_id"]
    
    assert second_response = @gateway.purchase(@amount*2, customer_id, @options)
    assert_equal 'This transaction has been approved', second_response.message
    assert second_response.success?  
  end

  def test_declined_purchase
    assert response = @gateway.purchase(@declined_amount, @creditcard, @options)
    assert_equal 'This transaction has been declined', response.message
    assert_failure response
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @creditcard, @options)
    assert_success auth
    assert_equal 'This transaction has been approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_equal 'This transaction has been approved', capture.message
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert  response.message.match(/Invalid Transaction ID \/ Object ID specified:/)
  end

  def test_invalid_login
    gateway = BrainTreeGateway.new(
        :login => '',
        :password => ''
    )
    assert response = gateway.purchase(@amount, @creditcard, @options)
    assert_equal 'Invalid Username', response.message
    assert_failure response
  end
end
