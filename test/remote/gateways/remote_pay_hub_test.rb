require 'test_helper'

class RemotePayHubTest < Test::Unit::TestCase
  def setup
    @gateway = PayHubGateway.new(fixtures(:pay_hub))

    @amount = 100

    @credit_card = credit_card('5466410004374507', :month => '06', 
                               :year => '2020', :verification_value => '998')

    @invalid_amount_card = credit_card('371449635398431', :month => '06', 
                               :year => '2020', :verification_value => '9997')

    @options = {
      :first_name=> 'Garrya',
      :last_name => 'Barrya',
      :email => 'payhubtest@mailinator.com',
      :address => {
        :address1 => '123a ahappy St.',
        :city => 'Happya City',
        :state => 'CA',
        :zip => '94901'
      }
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.success?
    assert_equal 'Successful - Approved and completed', response.message
  end

  def test_failed_purchase
    @amount = 0.20
    response = @gateway.purchase(@amount, @invalid_amount_card, @options)
    assert !response.success?
    assert_equal 'INVALID AMOUNT', response.message
  end

  def test_successful_void
    response = @gateway.purchase(@amount, @credit_card, @options)
    response = @gateway.void(:trans_id => response.params['TRANSACTION_ID'])
    assert_success response
    assert response.success?
    assert_equal 'Successful - Approved and completed', response.message
  end

  def test_failed_void
    response = @gateway.void(:trans_id => 347)
    assert_failure response
    assert !response.success?
    assert_equal 'Unable to void previous transaction.', response.message
  end

  def test_successful_refund
    response = @gateway.refund(:trans_id => 123)
    assert_success response
    assert response.success?
    assert_equal 'Successful - Approved and completed', response.message
  end

  def test_failed_refund
    response = @gateway.refund(:trans_id => 981)
    assert_failure response
    assert !response.success?
    assert_equal 'Unable to refund the previous transaction.', response.message
  end
end
