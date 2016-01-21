
require 'active_merchant/billing/gateways/worldnet.rb'
require 'test_helper'
require 'active_merchant/billing/response.rb'
class RemoteWorldnetTest < Test::Unit::TestCase
      
      def setup
        @gateway = WorldnetGateway.new(fixtures(:worldnet))
        @approved_amount = 100.00
        @refund_amount = 60.00
        
        @declined_amount = 100.01
        @declined_card   = credit_card('1111111111111111')
        @partial_amount = 100.01
        @credit_card = credit_card('4000100011112224')
        @options = {
          order_id: generate_unique_order_id,
          billing_address: address,
          description: 'Store Purchase'
              
        }
            
      end
      ###Generate Random OrderID
     def generate_unique_order_id
           SecureRandom.hex(6)
         
     end
 
     def test_successful_purchase 
         assert response = @gateway.purchase(@approved_amount, @credit_card, @options)
         assert_success response
         assert_equal 'APPROVAL', response.message
            
    end
 
    def test_successful_authorization
        assert auth = @gateway.authorize(@approved_amount, @credit_card, @options)
        assert_success auth
        assert_equal 'APPROVAL', auth.message
    end

    def test_successful_refund
        purchase = @gateway.purchase(@approved_amount, @credit_card, @options)
        assert_success purchase
    
        assert refund = @gateway.refund(@approved_amount, purchase.authorization)
        assert_success refund
      assert_equal 'SUCCESS', refund.message
   end

   
   
    def test_successful_authorize_and_capture
        auth = @gateway.authorize(@approved_amount, @credit_card, @options)
        assert_success auth
        assert capture = @gateway.capture(@approved_amount, auth.authorization)
        assert_success capture
        assert_equal 'APPROVAL', capture.message
   end
    def test_successful_void
        auth = @gateway.authorize(@approved_amount, @credit_card, @options)
        assert_success auth
    
        assert void = @gateway.void(@approved_amount, auth.authorization)
        assert_success void
        assert_equal 'SUCCESS', void.message
      end
      
   # Commenting failed assertions
   # def test_failed_purchase
      ## assert_failure response
       # assert_equal 'REPLACE WITH FAILED PURCHASE MESSAGE', response.message
   # end
   
   #def test_failed_authorize
       # response = @gateway.authorize(@declined_amount, @declined_card, @options)
       # assert_failure response
       # assert_equal 'REPLACE WITH FAILED AUTHORIZE MESSAGE', response.message
   # end



  # def test_failed_capture
      #  response = @gateway.capture(@declined_amount, '')
       # assert_failure response
       # assert_equal 'REPLACE WITH FAILED CAPTURE MESSAGE', response.message
   # end



      #def test_failed_refund
      #  response = @gateway.refund(@amount, '')
      #  assert_failure response
      #  assert_equal 'REPLACE WITH FAILED REFUND MESSAGE', response.message
      #end
      
     # def test_failed_void
       # response = @gateway.void('')
       # assert_failure response
       # assert_equal 'REPLACE WITH FAILED VOID MESSAGE', response.message
      #end

     

      


end
