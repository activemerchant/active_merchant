require 'test_helper'

class NullTest < Test::Unit::TestCase
  CC_PLACEHOLDER = "9999888877776666"
  CHECK_PLACEHOLDER = "99999999999"

  def setup
    @gateway = NullGateway.new(
      :login => 'null',
      :password => 'null'
    )

    @creditcard = credit_card(CC_PLACEHOLDER)

    @response = ActiveMerchant::Billing::Response.new(true, "Transaction successful", :transid => NullGateway::AUTHORIZATION)
  end

  def test_authorize
    assert  @gateway.authorize(1000, credit_card(CC_PLACEHOLDER)).success?
  end

  def test_purchase
    assert  @gateway.purchase(1000, credit_card(CC_PLACEHOLDER)).success?
  end

  def test_capture
    assert  @gateway.capture(1000, '1337').success?
    assert  @gateway.capture(1000, @response.params["transid"]).success?
  end

  def test_credit
    assert  @gateway.credit(1000, credit_card(CC_PLACEHOLDER)).success?
  end

  def test_refund
    assert  @gateway.refund(1000, '1337').success?
    assert  @gateway.refund(1000, @response.params["transid"]).success?
  end

  def test_credit_uses_refund
    options = {:foo => :bar}
    @gateway.expects(:refund).with(1000, '1337', options)
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE) do
      @gateway.credit(1000, '1337', options)
    end
  end

  def test_void
    assert  @gateway.void('1337').success?
    assert  @gateway.void(@response.params["transid"]).success?
  end

  def test_store
    assert  @gateway.store(credit_card(CC_PLACEHOLDER)).success?
  end

  def test_unstore
    assert @gateway.unstore(CC_PLACEHOLDER).success?
  end

  def test_store_then_purchase
    reference = @gateway.store(@creditcard)
    assert @gateway.purchase(1000, reference.authorization).success?
  end

  def test_supported_countries
    assert_equal [], NullGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:null], NullGateway.supported_cardtypes
  end

  def test_authorize_with_check
    assert  @gateway.authorize(1000, check(:account_number => CHECK_PLACEHOLDER, :number => nil)).success?
  end

  def test_purchase_with_check
    # use account number if number isn't given
    assert  @gateway.purchase(1000, check(:account_number => CHECK_PLACEHOLDER, :number => nil)).success?
  end

  def test_store_with_check
    assert  @gateway.store(check(:account_number => CHECK_PLACEHOLDER, :number => nil)).success?
  end

  def test_credit_with_check
    assert  @gateway.credit(1000, check(:account_number => CHECK_PLACEHOLDER, :number => nil)).success?
  end

  def test_store_then_purchase_with_check
    reference = @gateway.store(check(:account_number => CHECK_PLACEHOLDER, :number => nil))
    assert @gateway.purchase(1000, reference.authorization).success?
  end
end
