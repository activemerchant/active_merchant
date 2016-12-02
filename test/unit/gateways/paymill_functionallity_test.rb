require 'test_helper'
require 'active_merchant'
class PaymillTest < Test::Unit::TestCase
  def setup
    @gateway = PaymillGateway.new(:public_key => 'PUBLIC', :private_key => 'PRIVATE')
    @credit_card = ActiveMerchant::Billing::CreditCard.new(
        :number => '4111111111111111',
        :month => '12',
        :year => Time.now.year+1,
        :first_name => 'Longbob',
        :last_name => 'Longsen',
        :verification_value => '123',
        :email => 'Longbob.Longse@example.com',
        :brand => 'visa'
    )
    @amount = 5
  end


  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal "Operation successful", response.message
    assert_equal 20000, response.params['data']['response_code']
    assert_equal 'pay_b8e6a28fc5e5e1601cdbefbaeb8a', response.params['data']['payment']['id']
    assert_equal '5100', response.params['data']['payment']['last4']
    assert_nil response.cvv_result["message"]
    assert_nil response.avs_result["message"]
    assert response.test?
  end

end
