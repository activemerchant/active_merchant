require File.dirname(__FILE__) + '/../../test_helper'

class PaypalNvTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test

    @gateway = PaypalNvGateway.new(fixtures(:paypal_certificate))
  
    @credit_card = credit_card("4683075410516684")

    @options = {
      :order_id => generate_unique_id,
      :email => 'tester@esdlc.com',
      :billing_address => {
        :name => 'Fred Brooks',
        :address1 => '1234 Penny Lane',
        :city => 'Jonsetown',
        :state => 'NC',
        :country => 'US',
        :zip => '23456',
        } ,
      :description => 'Stuff that you purchased, yo!',
      :ip => '10.0.0.1'
    }
    
    @line_items = [
      { :sku => 1, :description => "foo", :quantity => 3, :amount => 500 },
      { :sku => 2, :description => "bar", :quantity => 2, :tax => 20, :amount => 500 }
    ]
    

    @subtotal = @line_items.inject(0){ |sum, item| sum += (item[:quantity] * item[:amount]) }
    @tax = @line_items.inject(0){ |sum, item| sum += (item[:quantity] * item[:tax].to_i) }
    @amount = @subtotal + @tax
    
    # test re-authorization, auth-id must be more than 3 days old.
    # each auth-id can only be reauthorized and tested once.
    # leave it commented if you don't want to test reauthorization.
    #
    #@three_days_old_auth_id  = "9J780651TU4465545"
    #@three_days_old_auth_id2 = "62503445A3738160X"
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_false response.authorization.blank?
    assert_equal '25.40', response.params['amt']
    assert_equal 'X', response.avs_result['code']
    assert_equal 'M', response.cvv_result['code']
    assert_equal 'USD', response.params['currencycode']
  end
  
  def test_successful_purchase_in_cad
    @options[:currency] = 'CAD'
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_false response.authorization.blank?
    assert_equal '25.40', response.params['amt']
    assert_equal 'X', response.avs_result['code']
    assert_equal 'M', response.cvv_result['code']
    assert_equal 'CAD', response.params['currencycode']
  end
  
  def test_successful_authorization
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_false response.authorization.blank?
    assert_equal '25.40', response.params['amt']
    assert_equal 'X', response.avs_result['code']
    assert_equal 'M', response.cvv_result['code']
    assert_equal 'USD', response.params['currencycode']
  end

  def test_successful_purchase_with_line_items
    add_line_items(@options)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_false response.authorization.blank?
  end

  def test_successful_purchase_details_with_line_items_shipping_and_handling
    add_line_items(@options)

    @shipping = 100
    @handling = 200
    @amount += (@shipping + @handling)

    @options[:subtotal] = @subtotal
    @options[:shipping] = @shipping
    @options[:handling] = @handling
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_false response.authorization.blank?
  end

  def test_successful_purchase_no_shipping
    @options[:no_shipping] = true
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_false response.authorization.blank?
  end

  def test_successful_purchase_with_api_signature
    gateway = PaypalNvGateway.new(fixtures(:paypal_signature))
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_false response.authorization.blank?
  end

  def test_failed_purchase
    @credit_card.number = '234234234234'
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_nil response.authorization
    assert_equal "This transaction cannot be processed. Please enter a valid credit card number and type.", response.message
  end

  def test_failed_authorization
    @credit_card.number = '234234234234'
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_nil response.authorization
  end

  def test_successful_authorization_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_false capture.authorization.blank?
    assert_equal "25.40", capture.params["amt"]
  end
  
  def test_failed_capture
    response = @gateway.capture(@amount, 'invalid')
    assert_failure response
    assert_nil response.authorization
    assert_equal "The transaction id is not valid", response.message
  end

  def test_successful_voiding
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    
    void = @gateway.void(auth.authorization, :description => 'Cancelled')
    assert_success void
    assert_false void.authorization.blank?
  end

  def test_purchase_and_full_credit
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    credit = @gateway.credit(@amount, purchase.authorization, :description => 'Sorry')
    assert_success credit
    assert_equal '25.40', credit.params['grossrefundamt']
  end

  def test_failed_voiding
    response = @gateway.void('foo')
    assert_failure response
  end

  def test_successful_transfer
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    response = @gateway.transfer(@amount, 'joe@example.com', :subject => 'Your money', :note => 'Thanks for taking care of that')
    assert_success response
  end

  def test_failed_transfer
     # paypal allows a max transfer of $10,000
    response = @gateway.transfer(1000001, 'joe@example.com')
    assert_failure response
  end

  def test_successful_multiple_transfer
    response = @gateway.purchase(900, @credit_card, @options)
    assert_success response

    response = @gateway.transfer([@amount, 'joe@example.com'],
      [600, 'jane@example.com', {:note => 'Thanks for taking care of that'}],
      :subject => 'Your money')
    assert_success response
  end
  
  def test_maximum_multiple_transfer
    response = @gateway.purchase(25100, @credit_card, @options)
    assert_success response
    
    # You can only include up to 250 recipients
    recipients = (1..250).collect {|i| [100, "person#{i}@example.com"]}
    response = @gateway.transfer(*recipients)
    assert_success response
  end

  def test_successful_reauthorization
    return unless @three_days_old_auth_id
    auth = @gateway.reauthorize(1000, @three_days_old_auth_id)
    assert_success auth
    assert auth.authorization

    response = @gateway.capture(1000, auth.authorization)
    assert_success response
    assert response.params['transactionid']
    assert_equal '10.00', response.params['gross_amount']
    assert_equal 'USD', response.params['gross_amount_currency_id']
  end

  def test_failed_reauthorization
    return unless @three_days_old_auth_id2  # was authed for $10, attempt $20
    auth = @gateway.reauthorize(2000, @three_days_old_auth_id2)
    assert_false auth?
    assert !auth.authorization
  end
  
  private
  def add_line_items(options)
    options[:line_items] = @line_items
    options[:tax] = @tax
    options[:subtotal] = @subtotal
  end
end
