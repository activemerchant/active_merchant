require File.dirname(__FILE__) + '/../../test_helper'

class EfsnetTest < Test::Unit::TestCase
  AMOUNT = 100

  def setup
    @gateway = EfsnetGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @creditcard = credit_card('4242424242424242')

    @address = { :address1 => '1234 My Street',
                 :address2 => 'Apt 1',
                 :company => 'Widgets Inc',
                 :city => 'Ottawa',
                 :state => 'ON',
                 :zip => 'K1C2N6',
                 :country => 'Canada',
                 :phone => '(555)555-5555'
               }
   @options = {:order_id => 1}
  end
  
  def test_successful_request
    @creditcard.number = 1
    assert response = @gateway.purchase(AMOUNT, @creditcard, @options)
    assert_success response
    assert_equal '5555', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @creditcard.number = 2
    assert response = @gateway.purchase(AMOUNT, @creditcard, @options)
    assert_failure response
    assert response.test?
  end

  def test_request_error
    @creditcard.number = 3
    assert_raise(Error){ @gateway.purchase(AMOUNT, @creditcard, @options) }
  end

  def test_authorize_is_valid_xml
   params = {
     :order_id => "order1",
     :transaction_amount => "1.01",
     :account_number => "4242424242424242",
     :expiration_month => "12",
     :expiration_year => "2029",
   }

   assert data = @gateway.send(:post_data, :credit_card_authorize, params)
   assert REXML::Document.new(data)
  end

  def test_settle_is_valid_xml
   params = {
     :order_id => "order1",
     :transaction_amount => "1.01",
     :original_transaction_amount => "1.01",
     :original_transaction_id => "1",
   }

   assert data = @gateway.send(:post_data, :credit_card_settle, params)
   assert REXML::Document.new(data)
  end
end
