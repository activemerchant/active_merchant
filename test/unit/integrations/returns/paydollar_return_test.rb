require 'test_helper'

class PaydollarReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_valid_return
    r = Paydollar::Return.new('Ref=1')
    assert r.success?
  end

  def test_invalid_return
    r = Paydollar::Return.new('')
    assert !r.success?
  end

end