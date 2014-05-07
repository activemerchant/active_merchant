require 'test_helper'

class BogusTest < Test::Unit::TestCase
  CC_SUCCESS_PLACEHOLDER = '4444333322221111'
  CC_FAILURE_PLACEHOLDER = '4444333311112222'
  CHECK_SUCCESS_PLACEHOLDER = '111111111111'
  CHECK_FAILURE_PLACEHOLDER = '222222222222'

  def setup
    @gateway = BogusGateway.new(
      :login => 'bogus',
      :password => 'bogus'
    )

    @creditcard = credit_card(CC_SUCCESS_PLACEHOLDER)

    @response = ActiveMerchant::Billing::Response.new(true, "Transaction successful", :transid => BogusGateway::AUTHORIZATION)
  end

  def test_authorize
    assert  @gateway.authorize(1000, credit_card(CC_SUCCESS_PLACEHOLDER)).success?
    assert !@gateway.authorize(1000, credit_card(CC_FAILURE_PLACEHOLDER)).success?
    e = assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.authorize(1000, credit_card('123'))
    end
    assert_equal("Bogus Gateway: Use CreditCard number ending in 1 for success, 2 for exception and anything else for error", e.message)
  end

  def test_purchase
    assert  @gateway.purchase(1000, credit_card(CC_SUCCESS_PLACEHOLDER)).success?
    assert !@gateway.purchase(1000, credit_card(CC_FAILURE_PLACEHOLDER)).success?
    e = assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.purchase(1000, credit_card('123'))
    end
    assert_equal("Bogus Gateway: Use CreditCard number ending in 1 for success, 2 for exception and anything else for error", e.message)
  end

  def test_capture
    assert  @gateway.capture(1000, '1337').success?
    assert  @gateway.capture(1000, @response.params["transid"]).success?
    assert !@gateway.capture(1000, CC_FAILURE_PLACEHOLDER).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.capture(1000, CC_SUCCESS_PLACEHOLDER)
    end
  end

  def test_credit
    assert  @gateway.credit(1000, credit_card(CC_SUCCESS_PLACEHOLDER)).success?
    assert !@gateway.credit(1000, credit_card(CC_FAILURE_PLACEHOLDER)).success?
    e = assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.credit(1000, credit_card('123'))
    end
    assert_equal("Bogus Gateway: Use CreditCard number ending in 1 for success, 2 for exception and anything else for error", e.message)
  end

  def test_refund
    assert  @gateway.refund(1000, '1337').success?
    assert  @gateway.refund(1000, @response.params["transid"]).success?
    assert !@gateway.refund(1000, CC_FAILURE_PLACEHOLDER).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.refund(1000, CC_SUCCESS_PLACEHOLDER)
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
    assert !@gateway.void(CC_FAILURE_PLACEHOLDER).success?
    assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.void(CC_SUCCESS_PLACEHOLDER)
    end
  end

  def test_store
    assert  @gateway.store(credit_card(CC_SUCCESS_PLACEHOLDER)).success?
    assert !@gateway.store(credit_card(CC_FAILURE_PLACEHOLDER)).success?
    e = assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.store(credit_card('123'))
    end
    assert_equal("Bogus Gateway: Use CreditCard number ending in 1 for success, 2 for exception and anything else for error", e.message)
  end

  def test_unstore
    @gateway.unstore(CC_SUCCESS_PLACEHOLDER)
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

  def test_authorize_with_check
    assert  @gateway.authorize(1000, check(:account_number => CHECK_SUCCESS_PLACEHOLDER, :number => nil)).success?
    assert !@gateway.authorize(1000, check(:account_number => CHECK_FAILURE_PLACEHOLDER, :number => nil)).success?
    e = assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.authorize(1000, check(:account_number => '123', :number => nil))
    end
    assert_equal("Bogus Gateway: Use bank account number ending in 1 for success, 2 for exception and anything else for error", e.message)
  end

  def test_purchase_with_check
    # use account number if number isn't given
    assert  @gateway.purchase(1000, check(:account_number => CHECK_SUCCESS_PLACEHOLDER, :number => nil)).success?
    assert !@gateway.purchase(1000, check(:account_number => CHECK_FAILURE_PLACEHOLDER, :number => nil)).success?
    # give priority to number over account_number if given
    assert !@gateway.purchase(1000, check(:account_number => CHECK_SUCCESS_PLACEHOLDER, :number => CHECK_FAILURE_PLACEHOLDER)).success?
    assert  @gateway.purchase(1000, check(:account_number => CHECK_FAILURE_PLACEHOLDER, :number => CHECK_SUCCESS_PLACEHOLDER)).success?
    e = assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.purchase(1000, check(:account_number => '123', :number => nil))
    end
    assert_equal("Bogus Gateway: Use bank account number ending in 1 for success, 2 for exception and anything else for error", e.message)
  end

  def test_store_with_check
    assert  @gateway.store(check(:account_number => CHECK_SUCCESS_PLACEHOLDER, :number => nil)).success?
    assert !@gateway.store(check(:account_number => CHECK_FAILURE_PLACEHOLDER, :number => nil)).success?
    e = assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.store(check(:account_number => '123', :number => nil))
    end
    assert_equal("Bogus Gateway: Use bank account number ending in 1 for success, 2 for exception and anything else for error", e.message)
  end

  def test_credit_with_check
    assert  @gateway.credit(1000, check(:account_number => CHECK_SUCCESS_PLACEHOLDER, :number => nil)).success?
    assert !@gateway.credit(1000, check(:account_number => CHECK_FAILURE_PLACEHOLDER, :number => nil)).success?
    e = assert_raises(ActiveMerchant::Billing::Error) do
      @gateway.credit(1000, check(:account_number => '123', :number => nil))
    end
    assert_equal("Bogus Gateway: Use bank account number ending in 1 for success, 2 for exception and anything else for error", e.message)
  end

  def test_store_then_purchase_with_check
    reference = @gateway.store(check(:account_number => CHECK_SUCCESS_PLACEHOLDER, :number => nil))
    assert @gateway.purchase(1000, reference.authorization).success?
  end
end
