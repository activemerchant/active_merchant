require 'test_helper'

class RemoteRapydTest < Test::Unit::TestCase
  def setup
    @gateway = XpayGateway.new(fixtures(:x_pay))
    @amount = 200
    @credit_card = credit_card(
      '4349940199004481',
      month: 5,
      year: 2026,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '250',
      brand: 'visa'
    )
    @options = {
      email: 'john.smith@test.com',            
      billing_address: address(country: 'US', state: 'CA'),
      order_id: '123',      
    }
  end

  def test_successful_authorize    
    transcript = capture_transcript(@gateway) do
      @gateway.authorize(@amount, @bank_account, @options)
    end    
    assert_success response
    assert_match 'The payment was paid', response.message
  end
end
