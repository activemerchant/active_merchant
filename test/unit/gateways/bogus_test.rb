require 'test_helper'

class BogusTest < Test::Unit::TestCase
  SUCCESS_PLACEHOLDER = '1111111111111111'
  FAILURE_PLACEHOLDER = '2222222222222222'

  def setup
    @gateway = BogusGateway.new(
      :login => 'bogus',
      :password => 'bogus'
    )

    @creditcard = credit_card(SUCCESS_PLACEHOLDER)

    @response = ActiveMerchant::Billing::Response.new(true, "Transaction successful", :transid => SUCCESS_PLACEHOLDER)
  end

  def test_authorize
    assert  @gateway.authorize(1000, credit_card(SUCCESS_PLACEHOLDER)).success?
    assert !@gateway.authorize(1000, credit_card(FAILURE_PLACEHOLDER)).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.authorize(1000, credit_card('111111113'))
    end
  end

  def test_purchase
    assert  @gateway.purchase(1000, credit_card(SUCCESS_PLACEHOLDER)).success?
    assert !@gateway.purchase(1000, credit_card(FAILURE_PLACEHOLDER)).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.purchase(1000, credit_card('111111131'))
    end
  end

  def test_recurring
    assert  @gateway.recurring(1000, credit_card(SUCCESS_PLACEHOLDER)).success?
    assert !@gateway.recurring(1000, credit_card(FAILURE_PLACEHOLDER)).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.recurring(1000, credit_card('111111311'))
    end
  end

  def test_capture
    assert  @gateway.capture(1000, SUCCESS_PLACEHOLDER).success?
    assert !@gateway.capture(1000, FAILURE_PLACEHOLDER).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.capture(1000, '111311111')
    end
  end

  def test_credit
    assert  @gateway.credit(1000, credit_card(SUCCESS_PLACEHOLDER)).success?
    assert !@gateway.credit(1000, credit_card(FAILURE_PLACEHOLDER)).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.credit(1000, credit_card('111113111'))
    end
  end

  def test_refund
    assert  @gateway.refund(1000, SUCCESS_PLACEHOLDER).success?
    assert !@gateway.refund(1000, FAILURE_PLACEHOLDER).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.refund(1000, '111131111')
    end
  end

  def test_credit_uses_refund
    options = {:foo => :bar}
    @gateway.expects(:refund).with(1000, '111111111', options)
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE, @gateway) do
      @gateway.credit(1000, '111111111', options)
    end
  end

  def test_void
    assert  @gateway.void(SUCCESS_PLACEHOLDER).success?
    assert !@gateway.void(FAILURE_PLACEHOLDER).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.void('113111111')
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

    reference = @gateway.store(credit_card('1111111111111121'))
    assert !@gateway.purchase(1000, reference.authorization).success?

    reference = @gateway.store(credit_card('1111111111111131'))
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.purchase(1000, reference.authorization)
    end
  end

  def test_store_then_authorize
    reference = @gateway.store(@creditcard)
    assert @gateway.authorize(1000, reference.authorization).success?

    reference = @gateway.store(credit_card('1111111111111112'))
    assert !@gateway.authorize(1000, reference.authorization).success?

    reference = @gateway.store(credit_card('1111111111111113'))
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.authorize(1000, reference.authorization)
    end
  end

  def test_supported_countries
    assert_equal ['US'], BogusGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:bogus], BogusGateway.supported_cardtypes
  end
end
