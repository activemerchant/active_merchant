require 'test_helper'

class BogusTest < Test::Unit::TestCase
  def setup
    @gateway = BogusGateway.new(
      :login => 'bogus',
      :password => 'bogus'
    )
    
    @creditcard = credit_card('1')

    @response = ActiveMerchant::Billing::Response.new(true, "Transaction successful", :transid => BogusGateway::AUTHORIZATION)
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
  
  def test_supported_countries
    assert_equal ['US'], BogusGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:bogus], BogusGateway.supported_cardtypes
  end
end
