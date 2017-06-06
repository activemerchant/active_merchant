require 'test_helper'

class RemoteCcavenueMcpgTest < Test::Unit::TestCase
  def setup
    @gateway = CcavenueMcpgGateway.new(fixtures(:ccavenue_mcpg))

    @amount = 100
    @credit_card = CreditCard.new(        
	     :month              => '',
         :year               => '',
         :brand              => '',
         :number             => '',
         :verification_value => ''
       )
    
    @options = {
     :order_id=> '24891549',        
        :email=> 'john@example.com',
        :billing_address=> {
          :name=> 'John Snow',
          :address1=> '111 Road',
          :address2=> 'Suite 111',
          :city=> 'Somewhere',
          :state=> 'XX',
          :country=> 'India',
          :zip=> '12345',
          :phone=> '12223334444'
        }
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Your order is Successful', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
     :order_id=> '24891549',        
        :email=> 'john@example.com',
        :billing_address=> {
          :name=> 'John Snow',
          :address1=> '111 Road',
          :address2=> 'Suite 111',
          :city=> 'Somewhere',
          :state=> 'XX',
          :country=> 'India',
          :zip=> '12345',
          :phone=> '12223334444'
        },
        :shipping_address=> {
          :name=> 'John Snow',
          :address1=> '222 Street',
          :address2=> 'Suite 222',
          :city=> 'Anyplace',
          :state=> 'YY',
          :country=> 'India',
          :zip=> '12346',
          :phone=> '1234567898'
        }
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Your order is Successful', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Your order is Unsuccessful', response.message
  end

end
