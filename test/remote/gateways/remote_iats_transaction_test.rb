# encoding: utf-8
require 'test_helper'

class RemoteIatsTransactionTest < Test::Unit::TestCase
def setup
    Base.mode = :test
    @gateway = IatsTransactionGateway.new(fixtures(:iats_transaction))
    @card = ActiveMerchant::Billing::CreditCard.new(
      month: '03',
      year: Time.now.year + 1,
      brand: 'visa',
      number: '4111111111111111'
    )
    
    @options = {
		:ip => '123.123.123.123',
		:email => 'iats@example.com',
		:billing_address => {
		  :name => 'Test UK',
        	  :phone => '555-555-5555',
		  :address1 => 'example address1',
	          :address2 => 'example address2',
	          :city => 'xyz',
	          :state => 'AP',
		  :country => 'FR',
	          :zip => '1312423'
	       },
	       :zip_code => 'ww'
	     }	

  end

  def test_process_cc_ok
    %w(1 3 6 7 8 9 10).each do |total|
      result = @gateway.purchase(total, @card, @options)
      assert result.message =~ /OK: 678594/
      assert result.success?
      assert result.params['transaction_id'] =~ /\d/
    end
  end

  def test_process_cc_rej
    [2, 4, 5].each do |total|
      result = @gateway.purchase(total, @card, @options)
      assert !result.success?
      assert result.message  == 'General decline code. Please have client call the number on the back of credit card'
    end
  end

  def test_process_cc
    result = @gateway.purchase(3, @card, @options)
    assert result.message =~ /OK: 678594/
    assert result.success?
    assert result.params['transaction_id'] =~ /\d/
  end

  def test_process_cc_16
    result = @gateway.purchase(16, @card, @options)
    assert !result.success?
    assert result.message  == 'Unable to process transaction. Verify and re-enter credit card information.'
  end

  def test_process_cc_17
    result = @gateway.purchase(17, @card, @options)
    assert !result.success?
    assert result.message  == 'Bank timeout. Bank lines may be down or busy. Re-try transaction later.'
    assert result.params['status_code'] =~ /REJECT: 22/
  end

  def test_process_cc_100
    result = @gateway.purchase(100, @card, @options)
    assert result.params['status_code'] =~ /REJECT: 15/
    assert !result.success?
    assert result.message  == 'General decline code. Please have client call the number on the back of credit card'
  end

  def test_refund
    @options.update(:total => '-100')
    result = @gateway.refund(1, @options)
    assert result.params['status_code'] =~ /REJECT: 39/
    assert !result.success?
    assert result.message  == 'Contact IATS 1-888-955-5455.'
  end

  def test_validate_cvv2_1234
     @options.update(:cvv2 => 1234)
     result = @gateway.purchase(15, @card, @options)
     assert result.params['status_code'] =~ /OK: 678594/
     assert result.success?
     assert result.params['transaction_id'] =~ /\d/
  end
 
  def test_validate_cvv2
     result = @gateway.purchase(15, @card, @options)
     assert result.params['status_code'] =~ /REJECT: 19/
     assert !result.success?
     assert result.params['transaction_id'] =~ /\d/
  end
end
