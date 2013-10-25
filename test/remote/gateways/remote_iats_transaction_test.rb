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
      assert result.message =~ /OK: 678594/
      assert result.success?
      assert result.params['transaction_id'] =~ /\d/
    end
  end

  def test_process_cc_rej
    [2, 4, 5].each do |total|
      result = @gateway.purchase(total, @card, { zip_code: 'ww' })
      assert !result.success?
      assert result.message  == 'General decline code. Please have client call the number on the back of credit card'
    end
  end

  def test_process_cc
    result = @gateway.purchase(3, @card, { zip_code: 'ww' })
    assert result.message =~ /OK: 678594/
    assert result.success?
    assert result.params['transaction_id'] =~ /\d/
  end

  def test_process_cc_16
    result = @gateway.purchase(16, @card, { zip_code: 'ww' })
    assert !result.success?
    assert result.message  == 'Unable to process transaction. Verify and re-enter credit card information.'
  end

  def test_process_cc_17
    result = @gateway.purchase(17, @card, { zip_code: 'ww' })
    assert !result.success?
    assert result.message  == 'Bank timeout. Bank lines may be down or busy. Re-try transaction later.'
    assert result.params['status_code'] =~ /REJECT: 22/
  end

  def test_process_cc_100
    result = @gateway.purchase(100, @card, { zip_code: 'ww' })
    assert result.params['status_code'] =~ /REJECT: 15/
    assert !result.success?
    assert result.message  == 'General decline code. Please have client call the number on the back of credit card'
  end

  def test_refund
    result = @gateway.refund(1, { total: '-100' })
    assert result.params['status_code'] =~ /REJECT: 39/
    assert !result.success?
    assert result.message  == 'Contact IATS 1-888-955-5455.'
  end
end
