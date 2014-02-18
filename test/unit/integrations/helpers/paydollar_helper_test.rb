require 'test_helper'

class PaydollarHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @orderReference = 'order-500'
    @merchantId = '0987654321'
    @amount = '123.45'
    @currencyCode = 'HKD'
    @helper = Paydollar::Helper.new(@orderReference, @merchantId, :amount => @amount, :currency => @currencyCode)
  end

  def test_basic_helper_fields
    assert_field 'merchantId', @merchantId
    assert_field 'amount', @amount
    assert_field 'orderRef', @orderReference
    assert_field 'currCode', '344'
  end

  def test_unknown_mapping
    assert_nothing_raised do
      @helper.company_address :address => '500 Dwemthy Fox Road'
    end
  end

end
