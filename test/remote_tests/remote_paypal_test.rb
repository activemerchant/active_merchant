require File.dirname(__FILE__) + '/../test_helper'

class PaypalTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test
    
    #cert = File.read(File.join(File.dirname(__FILE__), 'certificate.pem'))
    
     @gateway = PaypalGateway.new(
        :login     => 'login',
        :password  => 'password',
        :subject => 'third_party_account',
        :pem => '' #cert
     )

     @creditcard = CreditCard.new(
       :type                => "Visa",
       :number              => "4381258770269608", # Use a generated CC from the paypal Sandbox
       :verification_value => "000",
       :month               => 1,
       :year                => 2008,
       :first_name          => 'Fred',
       :last_name           => 'Brooks'
      )
       
      @params = {
        :order_id => generate_order_id,
        :email => 'buyer@jadedpallet.com',
        :address => { :name => 'Fred Brooks',
                      :address1 => '1234 Penny Lane',
                      :city => 'Jonsetown',
                      :state => 'NC',
                      :country => 'US',
                      :zip => '23456'
                    } ,
        :description => 'Stuff that you purchased, yo!',
        :ip => '10.0.0.1',
        :return_url => 'http://example.com/return',
        :cancel_return_url => 'http://example.com/cancel'
      }
      
      # test re-authorization, auth-id must be more than 3 days old.
      # each auth-id can only be reauthorized and tested once.
      # leave it commented if you don't want to test reauthorization.
      # 
      #@three_days_old_auth_id  = "9J780651TU4465545" 
      #@three_days_old_auth_id2 = "62503445A3738160X" 
  end

  def test_successful_purchase
    response = @gateway.purchase(300, @creditcard, @params)
    assert response.success?
    assert response.params['transaction_id']
  end
  
  def test_failed_purchase
    @creditcard.number = '234234234234'
    response = @gateway.purchase(300, @creditcard, @params)
    assert !response.success?
    assert_nil response.params['transaction_id']
  end

  def test_successful_authorization
    response = @gateway.authorize(300, @creditcard, @params)
    assert response.success?
    assert response.params['transaction_id']
    assert_equal '3.00', response.params['amount']
    assert_equal 'USD', response.params['amount_currency_id']
  end
  
  def test_failed_authorization
    @creditcard.number = '234234234234'
    response = @gateway.authorize(300, @creditcard, @params)
    assert !response.success?
    assert_nil response.params['transaction_id']
  end

  def test_successful_reauthorization
    return if not @three_days_old_auth_id
    auth = @gateway.reauthorize(1000, @three_days_old_auth_id)
    assert auth.success?
    assert auth.authorization
    
    response = @gateway.capture(1000, auth.authorization)
    assert response.success?
    assert response.params['transaction_id']
    assert_equal '10.00', response.params['gross_amount']
    assert_equal 'USD', response.params['gross_amount_currency_id']
  end
  
  def test_failed_reauthorization
    return if not @three_days_old_auth_id2  # was authed for $10, attempt $20
    auth = @gateway.reauthorize(2000, @three_days_old_auth_id2)
    assert !auth.success?
    assert !auth.authorization
  end
      
  def test_successful_capture
    auth = @gateway.authorize(300, @creditcard, @params)
    assert auth.success?
    response = @gateway.capture(300, auth.authorization)
    assert response.success?
    assert response.params['transaction_id']
    assert_equal '3.00', response.params['gross_amount']
    assert_equal 'USD', response.params['gross_amount_currency_id']
  end
  
  def test_successful_voiding
    auth = @gateway.authorize(300, @creditcard, @params)
    assert auth.success?
    response = @gateway.void(auth.authorization)
    assert response.success?
  end
  
  def test_purchase_and_full_credit
    amount = 300
    
    purchase = @gateway.purchase(amount, @creditcard, @params)
    assert purchase.success?
    
    credit = @gateway.credit(amount, purchase.authorization, :note => 'Sorry')
    assert credit.success?
    assert credit.test?
    assert_equal 'USD',  credit.params['net_refund_amount_currency_id']
    assert_equal '2.61', credit.params['net_refund_amount']
    assert_equal 'USD',  credit.params['gross_refund_amount_currency_id']
    assert_equal '3.00', credit.params['gross_refund_amount']
    assert_equal 'USD',  credit.params['fee_refund_amount_currency_id']
    assert_equal '0.39', credit.params['fee_refund_amount']
  end
  
  def test_failed_voiding
    response = @gateway.void('foo')
    assert !response.success?
  end
  
  def test_successful_transfer
    response = @gateway.purchase(300, @creditcard, @params)
    assert response.success?, response.message
    
    response = @gateway.transfer(300, 'joe@example.com', :subject => 'Your money', :note => 'Thanks for taking care of that')
    assert response.success?, response.message
  end

  def test_failed_transfer
     # paypal allows a max transfer of $10,000
    response = @gateway.transfer(1000001, 'joe@example.com')
    assert !response.success?, response.message
  end
  
  def test_successful_multiple_transfer
    response = @gateway.purchase(900, @creditcard, @params)
    assert response.success?, response.message
    
    response = @gateway.transfer([300, 'joe@example.com'],
      [600, 'jane@example.com', {:note => 'Thanks for taking care of that'}],
      :subject => 'Your money')
    assert response.success?, response.message
  end
  
  def test_failed_multiple_transfer
    response = @gateway.purchase(25100, @creditcard, @params)
    assert response.success?, response.message

    # You can only include up to 250 recipients
    recipients = (1..251).collect {|i| [100, "person#{i}@example.com"]}
    response = @gateway.transfer(*recipients)
    assert !response.success?, response.message
  end
end
