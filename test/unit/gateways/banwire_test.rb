require 'test_helper'

class BanwireTest < Test::Unit::TestCase
  def setup
    @gateway = BanwireGateway.new(
                 :login => 'desarrollo',
                 :currency => 'MXN')

    @credit_card = credit_card('5204164299999999',
                               :month => 11,
                               :year => 2012,
                               :verification_value => '999')
    @amount = 100

    @options = {
      :order_id => '1',
      :email => 'test@email.com',
      :billing_address => address,
      :description => 'Store purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'test12345', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private

  def failed_purchase_response
    <<-RESPONSE
    {"user":"desarrollo","id":"20120627190025","referencia":"12345","date":"27-06-2012 19:00:25","card":"9999","response":"ko","code":700,"message":"Pago Denegado."}
    RESPONSE
  end

  def successful_purchase_response
    <<-RESPONSE
    {"user":"desarrollo","id":"20120627190025","referencia":"12345","date":"27-06-2012 19:00:25","card":"9999","response":"ok","code_auth":"test12345","monto":"100", "cliente":"Roberto I Ramirez N"}
    RESPONSE
  end
end
