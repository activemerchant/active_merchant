require File.join(File.dirname(__FILE__), '../../test_helper')

$time_string = Time.new.to_i.to_s()

class RemoteRocketgateTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test
    
    @gateway = RocketgateGateway.new(fixtures(:rocketgate))
    
    @credit_card = credit_card('4111111111111111',
                                              :month => '10',
                                              :year  => '2012',
                                              :verification_value => 123,
                                              :first_name => 'John',
                                              :last_name => 'Smith'
                                              )
    
    # RocketGate supports a few custom fields
    # merchantAccount, udf01, udf02, merchantCustomerID
    #
    # We are setting the order id and customer as the unix timestamp as a convienent sequencing value
    # We will prepend a test name to the order id in the tests below just to facilitate some clarity when reviewing the tests 
    #
    @options = { 
      :order_id => $time_string,
      :customer_id => 'RUBYT-' + $time_string,
      :billing_address => {
        :address1 => '123 Main St',
        :city => 'Las Vegas',
        :state => 'NV',
        :country => 'US',
        :zip => '90045',
        :phone => '702 111 1234'
      },
      :description => 'Store Purchase',
      :currency => 'USD',
      :email => 'bogus@fakedomain.com',
      :username => 'userusername',
      :ip => '1.2.3.4',
      :ignore_avs => 'false',
      :ignore_cvv => 'false',
      :scrub => 'false'
    }
    
    @amount = 100
    
  end
 
 
  def test_successful_purchase
    @options[:order_id] = 'PURCHASE-' + @options[:order_id]
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction Successful', response.message
  end

  def test_authorize_and_capture
    amount = @amount
    @options[:order_id] = 'AUTHCAP-' + @options[:order_id]
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Transaction Successful', auth.message
    
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
    assert_equal 'Transaction Successful', capture.message
  end

 
 def test_purchase_and_void
   @options[:order_id] = 'PURCHASE-VOID-' + @options[:order_id]
    assert auth = @gateway.purchase(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Transaction Successful', auth.message
    
    assert auth.authorization
    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Transaction Successful', void.message
  end
 
 
 def test_purchase_and_refund
   @options[:order_id] = 'PURCHASE-REFUND-' + @options[:order_id]
    assert auth = @gateway.purchase(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Transaction Successful', auth.message
    
    assert auth.authorization
    assert refund = @gateway.refund(@amount,auth.authorization, @options)
    assert_success refund
    assert_equal 'Transaction Successful', refund.message
  end
 
 def test_purchase_optional_fields
   @options[:order_id] = 'PURCHASE-OPTS-' + @options[:order_id]
   @options[:udf01] = 'Test supplying user defined field 1'
   @options[:udf02] = 'Test supplying user defined field 2'
   @options[:billing_type] = 'I' # Used by merchants who are doing their own membership management
   @options[:affiliate] = 'Affiliate 1'
   @options[:site_id] = 1 # Default site id is 0
   # Requires activation with RocketGate before dynamic descriptors can be activated.
   #@options[:descriptor] = 'dynamic descriptor.com 800.xxx.xxxx' # Dynamic descriptor placed on customers statement
   
    assert auth = @gateway.purchase(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Transaction Successful', auth.message
  end
   
   def test_recurring_without_trial
    # reucrring quarterly @29.95
    @options[:order_id] = 'RECUR_NO_TRIAL_' + @options[:order_id]
    
    amount = 2995
    @options[:rebill_frequency] = 'QUARTERLY' 
    
    assert recur = @gateway.recurring(amount, @credit_card, @options)
    assert_success recur
    assert_equal 'Transaction Successful', recur.message
  end
  
   def test_recurring_with_trial
    # 5.99 3-day trial, reucrring monthly @19.95
    @options[:order_id] = 'RECUR_TRIAL_' + @options[:order_id]
    
    @options[:rebill_frequency] = 'MONTHLY' 

    amount = 599
    @options[:rebill_amount] = 19.95 # sets price in dollars different then initial bill
    @options[:rebill_start] = 3 # starts rebill 3 days from join
    
    assert recur = @gateway.recurring(amount, @credit_card, @options)
    assert_success recur
    assert_equal 'Transaction Successful', recur.message
  end

  def test_unmatched_capture
    assert response = @gateway.capture(@amount, "1000114CEBCE77E")
    assert_failure response
    assert_equal "No matching transaction", response.message
  end
  
  def test_invalid_capture
    assert response = @gateway.capture(@amount, "invalidGuid")
    assert_failure response
    assert_equal "Invalid Transact ID", response.message
  end

  def test_auth_more_then_capture
    amount = @amount
    amount_more = @amount + 10

    @options[:order_id] = 'AUTH_MORE_THAN_CAP-' + @options[:order_id]
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Transaction Successful', auth.message

    assert auth.authorization
    assert capture = @gateway.capture(amount_more, auth.authorization)
    assert_failure capture
    assert_equal 'The TICKET request was for an invalid amount. Please verify the TICKET for less then the AUTH_ONLY.', capture.message
  end
 
  def test_unsuccessful_overlimit
    @options[:order_id] = 'OVERLIMIT-' + @options[:order_id]
    amount = 2
    assert response = @gateway.purchase(amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The bank has declined the transaction because the account is over limit.', response.message
  end
  
  def test_unsuccessful_avs
    @options[:order_id] = 'BAD_AVS-' + @options[:order_id]
    @options[:billing_address][:zip] = '00008'
    @options[:ignore_avs] = false
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The transaction was declined because the address could not be verified.', response.message
  end

  def test_unsuccessful_cvv
    @options[:order_id] = 'BAD_CVV-' + @options[:order_id]
    @options[:ignore_cvv] = false
    
    credit_card = @credit_card
    credit_card.verification_value = '0001'
    credit_card.number = '371100001000131'
    
    assert response = @gateway.purchase(@amount, credit_card, @options)
    assert_failure response
    assert_equal 'The transaction was declined because the security code (CVV) supplied was invalid.', response.message
  end

  def test_invalid_login
    gateway = RocketgateGateway.new(
                :login => '1',
                :password => 'INVALID_PASSWORD'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid Access Code', response.message
  end

end
