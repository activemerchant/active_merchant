require File.dirname(__FILE__) + '/../../test_helper'

class BogusTest < Test::Unit::TestCase
  include ActiveMerchant::Billing
  
  def setup
    @gateway = BogusGateway.new({ 
      :login => 'bogus',
      :password => 'bogus',
      :test => true,
    })
    
    @creditcard = CreditCard.new({
      :number => '1',
      :month => 8,
      :year => 2006,
      :first_name => 'Longbob',
      :last_name => 'Longsen'
    })
    
    @response = ActiveMerchant::Billing::Response.new(true, "Transaction successful", {:transid => '1'})
  end

  def test_authorize
    @gateway.capture(Money.new(1000), @creditcard)    
  end

  def test_purchase
    @gateway.purchase(Money.new(1000), @creditcard)    
  end

  def test_credit
    @gateway.credit(Money.new(1000), @response.params["transid"])
  end
  
  def  test_store
    @gateway.store(@creditcard)
  end
  
  def test_unstore
    @gateway.unstore('1')
  end
end
