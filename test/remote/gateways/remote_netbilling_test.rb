require 'test_helper'
class RemoteNetbillingTest < Test::Unit::TestCase
 
  def setup
    @gateway = NetbillingGateway.new(fixtures(:netbilling))

    @credit_card = credit_card('4444111111111119',
                     :month => '9',
                     :year  => Time.now.year.to_i + 1,
                     :verification_value => nil
                   )

    @address = {  :address1 => '1600 Amphitheatre Parkway',
                  :city => 'Mountain View',
                  :state => 'CA',
                  :country => 'US',
                  :zip => '94043',
                  :phone => '650-253-0001'
                }
  
    @options = {  
      :billing_address => @address,
      :description => 'Internet purchase'
    }
               
    @amount = 100
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_false response.authorization.blank?
    assert_equal NetbillingGateway::SUCCESS_MESSAGE, response.message
    assert response.test?
  end

  def test_unsuccessful_purchase
    @credit_card.year = '2006'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'CARD EXPIRED', response.message
    assert_failure response
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal NetbillingGateway::SUCCESS_MESSAGE, auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    capture_exception = assert_raise ActiveMerchant::ResponseError, "Failed with 611 No Record Found For Specified ID" do
      @gateway.capture(@amount, '1111')
    end
    assert response = capture_exception.response
  end

  def test_invalid_login
   gateway = NetbillingGateway.new(
               :login => '',
               :password => ''
             )
   
   authentication_exception = assert_raise ActiveMerchant::ResponseError, 'Failed with 604 Missing Parameter (account_id)' do
     gateway.purchase(@amount, @credit_card, @options)
   end
   assert response = authentication_exception.response

  end
  
  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_false response.authorization.blank?
    assert_equal NetbillingGateway::SUCCESS_MESSAGE, response.message
    assert response.test?
    
    assert refund_response = @gateway.credit(@amount, response.authorization, @options)
    assert_success refund_response
    assert_false response.authorization.blank?
    assert_equal NetbillingGateway::SUCCESS_MESSAGE, response.message
    assert response.test?
  end
  
end
