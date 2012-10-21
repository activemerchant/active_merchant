require 'test_helper'

class BogusTest < Test::Unit::TestCase
  SUCCESS_PLACEHOLDER = '4444333322221111'
  FAILURE_PLACEHOLDER = '4444333311112222'

  def setup
    @gateway = BogusGateway.new(
      :login => 'bogus',
      :password => 'bogus'
    )

    @creditcard = credit_card(SUCCESS_PLACEHOLDER)

    @response = ActiveMerchant::Billing::Response.new(true, "Transaction successful", :transid => BogusGateway::AUTHORIZATION)
  end

  def test_authorize
    assert  @gateway.authorize(1000, credit_card(SUCCESS_PLACEHOLDER)).success?
    assert !@gateway.authorize(1000, credit_card(FAILURE_PLACEHOLDER)).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.authorize(1000, credit_card('123'))
    end
  end

  def test_purchase
    assert  @gateway.purchase(1000, credit_card(SUCCESS_PLACEHOLDER)).success?
    assert !@gateway.purchase(1000, credit_card(FAILURE_PLACEHOLDER)).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.purchase(1000, credit_card('123'))
    end
  end

  def test_recurring
    assert  @gateway.recurring(1000, credit_card(SUCCESS_PLACEHOLDER)).success?
    assert !@gateway.recurring(1000, credit_card(FAILURE_PLACEHOLDER)).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.recurring(1000, credit_card('123'))
    end
  end

  def test_capture
    assert  @gateway.capture(1000, '1337').success?
    assert  @gateway.capture(1000, @response.params["transid"]).success?
    assert !@gateway.capture(1000, FAILURE_PLACEHOLDER).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.capture(1000, SUCCESS_PLACEHOLDER)
    end
  end

  def test_credit
    assert  @gateway.credit(1000, credit_card(SUCCESS_PLACEHOLDER)).success?
    assert !@gateway.credit(1000, credit_card(FAILURE_PLACEHOLDER)).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.credit(1000, credit_card('123'))
    end
  end

  def test_refund
    assert  @gateway.refund(1000, '1337').success?
    assert  @gateway.refund(1000, @response.params["transid"]).success?
    assert !@gateway.refund(1000, FAILURE_PLACEHOLDER).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.refund(1000, SUCCESS_PLACEHOLDER)
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
    assert !@gateway.void(FAILURE_PLACEHOLDER).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.void(SUCCESS_PLACEHOLDER)
    end
  end

  def test_store
    @gateway.store(@creditcard)
  end

  def test_unstore
    @gateway.unstore(SUCCESS_PLACEHOLDER)
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
end
