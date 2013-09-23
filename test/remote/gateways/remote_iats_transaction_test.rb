# encoding: utf-8

require 'test_helper'

# test remote calls
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

  def test_process_cc_ok
    %w(1 3 6 7 8 9 10).each do |total|
      result = @gateway.purchase(total, @card, { zip_code: 'ww' })
      assert result.xpath('//AUTHORIZATIONRESULT').text =~ /OK: 678594/
    end
  end

  def test_process_cc_rej
    [2, 4, 5].each do |total|
      result = @gateway.purchase(total, @card, { zip_code: 'ww' })
      assert result.xpath('//AUTHORIZATIONRESULT').text =~ /REJECT: 15/
    end
  end

  def test_process_cc
    result = @gateway.purchase(3, @card, { zip_code: 'ww' })
    assert result.xpath('//AUTHORIZATIONRESULT').text =~ /OK: 678594/
  end

  def test_process_cc_16
    result = @gateway.purchase(16, @card, { zip_code: 'ww' })
    assert result.xpath('//AUTHORIZATIONRESULT').text =~ /REJECT: 2/
  end

  def test_process_cc_17
    result = @gateway.purchase(17, @card, { zip_code: 'ww' })
    assert result.xpath('//AUTHORIZATIONRESULT').text =~ /REJECT: 22/
  end

  def test_process_cc_100
    result = @gateway.purchase(100, @card, { zip_code: 'ww' })
    assert result.xpath('//AUTHORIZATIONRESULT').text =~ /REJECT: 15/
  end

  def test_refund
    result = @gateway.refund(1, { total: '-100' })
    assert result.xpath('//AUTHORIZATIONRESULT').text =~ /REJECT: 39/
  end
end