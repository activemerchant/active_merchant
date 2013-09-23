# encoding: utf-8

require 'test_helper'

# test iats gateway
class IatsTransactionTest < Test::Unit::TestCase

  def setup
    Base.mode = :test
    @gateway = IatsTransactionGateway.new(region: 'uk',
                                          login: 'TEST88',
                                          password: 'TEST88')
    @card = ActiveMerchant::Billing::CreditCard.new(
      month: '03',
      year: '2015',
      brand: 'visa',
      number: '4111111111111111'
    )
  end

  def test_expiration_validation
    @card.year = 2010
    assert_raises(ArgumentError) do
      @gateway.purchase(100, @card, { zip_code: 'ww' })
    end
  end

  def test_zip_require_field
    assert_raises(ArgumentError) do
      @gateway.purchase(100, @card)
    end
  end

  def test_region_and_host
    assert @gateway.current_host ==
      ActiveMerchant::Billing::IatsTransactionGateway::UK_HOST
    @gateway = IatsTransactionGateway.new(region: 'us',
                                          login: 'TEST88',
                                          password: 'TEST88')
    assert @gateway.current_host ==
      ActiveMerchant::Billing::IatsTransactionGateway::NA_HOST
  end

end