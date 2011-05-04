require 'test_helper'

class DirectebankingReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_successful_purchase
    r = Directebanking::Return.new(successful_purchase)
    assert r.success?
    assert_equal "success", r.message
    assert_equal "39708-101654-4DA89F50-DCB1", r.transaction
  end
  
  def test_pending_purchase
    r = Directebanking::Return.new(failed_purchase)
    assert !r.success?
    assert_equal "abort", r.message
    assert_equal "XXXX", r.transaction    
  end

  private
  
  def successful_purchase
    'authResult=success&transaction=39708-101654-4DA89F50-DCB1&sender_holder=Max%20Mustermann'
  end
  
  def failed_purchase
    'authResult=abort&transaction=XXXX&sender_holder=Max%20Mustermann'
  end
end