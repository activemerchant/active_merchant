require 'test_helper'

class RemotePayHubTest < Test::Unit::TestCase
  def setup
    @gateway = PayHubGateway.new(fixtures(:pay_hub))
    @amount = 100
    @credit_card = credit_card('5466410004374507', verification_value: "998")
    @invalid_card = credit_card('3714496353984', verification_value: "9997")
    @invalid_transaction_id = "10809"
    @options = {
      :first_name => 'Garrya',
      :last_name => 'Barrya',
      :email => 'payhubtest@mailinator.com',
      :address => {
        :address1 => '123a ahappy St.',
        :city => 'Happya City',
        :state => 'CA',
        :zip => '94901'
      },
      :record_format => "CREDIT_CARD",
      :schedule => {
        :schedule_type => 'S',
        :specific_dates_schedule => {
        :specific_dates => [
          (Date.today + 1.month).to_s,
          (Date.today + 2.month).to_s
          ]
        }
      }
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_unsuccessful_purchase
    response = @gateway.purchase(@amount, @invalid_card, @options)
    assert_failure response
    assert_equal "DECLINE", response.message
  end
  
  def test_successful_recurring
    response = @gateway.recurring(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end
  
  def test_unsuccessful_recurring
    @options[:schedule][:specific_dates_schedule][:specific_dates] = [(Date.today - 1.month).to_s]
    response =  @gateway.recurring(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "DECLINE", response.message
  end

  def test_unsuccessful_refund
    response = @gateway.refund(@invalid_transaction_id, @options )
    assert_failure response
    assert_equal "DECLINE", response.message
  end
  
  def test_successful_void
    purchase_response = @gateway.purchase(@amount, @credit_card, @options)
    response = @gateway.void(purchase_response.params["saleId"], @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_unsuccessful_void
    response = @gateway.void(@invalid_transaction_id, @options )
    assert_failure response
    assert_equal "DECLINE", response.message
  end
  
end
