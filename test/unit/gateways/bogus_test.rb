require 'test_helper'

class BogusTest < Test::Unit::TestCase
  def setup
    @gateway = BogusGateway.new(
      :login => 'bogus',
      :password => 'bogus'
    )
    
    @creditcard = credit_card('1')

    @response = ActiveMerchant::Billing::Response.new(true, "Transaction successful", :transid => BogusGateway::AUTHORIZATION)

    @profile = { :email => 'Up to 255 Characters' }
    @customer_profile_id = '53433'
    @customer_payment_profile_id = '1'
  end

  def test_authorize
    assert  @gateway.authorize(1000, credit_card('1')).success?
    assert !@gateway.authorize(1000, credit_card('2')).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.authorize(1000, credit_card('123'))
    end
  end

  def test_purchase
    assert  @gateway.purchase(1000, credit_card('1')).success?
    assert !@gateway.purchase(1000, credit_card('2')).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.purchase(1000, credit_card('123'))
    end
  end

  def test_recurring
    assert  @gateway.recurring(1000, credit_card('1')).success?
    assert !@gateway.recurring(1000, credit_card('2')).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.recurring(1000, credit_card('123'))
    end
  end

  def test_capture
    assert  @gateway.capture(1000, '1337').success?
    assert  @gateway.capture(1000, @response.params["transid"]).success?
    assert !@gateway.capture(1000, '2').success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.capture(1000, '1')
    end
  end

  def test_credit
    assert  @gateway.credit(1000, credit_card('1')).success?
    assert !@gateway.credit(1000, credit_card('2')).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.credit(1000, credit_card('123'))
    end
  end

  def test_refund
    assert  @gateway.refund(1000, '1337').success?
    assert  @gateway.refund(1000, @response.params["transid"]).success?
    assert !@gateway.refund(1000, '2').success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.refund(1000, '1')
    end
  end

  def test_credit_uses_refund
    options = {:foo => :bar}
    @gateway.expects(:refund).with(1000, '1337', options)
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE, @gateway) do
      @gateway.credit(1000, '1337', options)
    end
  end

  def test_void
    assert  @gateway.void('1337').success?
    assert  @gateway.void(@response.params["transid"]).success?
    assert !@gateway.void('2').success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.void('1')
    end
  end

  def test_store
    @gateway.store(@creditcard)
  end
  
  def test_unstore
    @gateway.unstore('1')
  end

  def test_store_then_purchase
    reference = @gateway.store(@creditcard)
    assert @gateway.purchase(1000, reference.authorization).success?
  end
  
  def test_supported_countries
    assert_equal ['US'], BogusGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:bogus], BogusGateway.supported_cardtypes
  end

  def test_create_customer_profile
    options = {:profile => @profile }
    assert response = @gateway.create_customer_profile(options)
    
    assert_success response
    assert response.test?
    
    assert_equal @customer_profile_id, response.authorization
    assert_equal 'Bogus Gateway: Forced success', response.message
  end

  def test_create_customer_payment_profile
    payment_profile = {:payment => {:credit_card => credit_card } }

    assert response = @gateway.create_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :payment_profile => payment_profile
    )

    assert_success response
    assert_nil response.authorization
    assert customer_payment_profile_id = response.params['customer_payment_profile_id']
    assert customer_payment_profile_id =~ /\d+/, "The customerPaymentProfileId should be numeric. It was #{customer_payment_profile_id}"
  end

  def test_create_customer_profile_transaction
    # success
    options = { :transaction => { :customer_profile_id => @customer_profile_id, :customer_payment_profile_id => '1' } }
    assert response = @gateway.create_customer_profile_transaction(options)

    assert_success response
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    
    # error
    options = { :transaction => { :customer_profile_id => @customer_profile_id, :customer_payment_profile_id => '2' } }
    assert response = @gateway.create_customer_profile_transaction(options)

    assert_failure response
    
    # exception
    options = { :transaction => { :customer_profile_id => @customer_profile_id, :customer_payment_profile_id => 'not a number' } }

    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.create_customer_profile_transaction(options)
    end
  end
end
