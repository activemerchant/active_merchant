require 'test_helper'

class RemoteAlfabankTest < Test::Unit::TestCase

  def setup
    @gateway = AlfabankGateway.new(fixtures(:alfabank))
    @amount = 12
    @description = 'remote activemerchant test'
    @return_url = 'http://activemerchant.org'
  end

  def test_successful_make_order
    assert response = @gateway.make_order(:order_number => Time.now.to_i,
                                          :amount => @amount,
                                          :description => @description,
                                          :return_url => @return_url)
    assert_success response
    order_id = response.params['order_id']
    assert_not_nil order_id
    assert response.params['form_url'] =~ /https:\/\/test.paymentgate.ru\/testpayment\/merchants\/[A-Za-z0-9]+\/payment_ru.html\?mdOrder=#{order_id}/

    # Verify by order id
    assert response = @gateway.get_order_status(:order_id => order_id)
    assert_valid_response response

    # Verify by order number
    assert response = @gateway.get_order_status(:order_number => response.params['order_number'])
    assert_valid_response response
  end

  def test_unsuccessful_make_same_order_twice
    order_number = Time.now.to_i

    assert_success @gateway.make_order(:order_number => order_number,
                                       :amount => @amount,
                                       :description => @description,
                                       :return_url => @return_url)
    assert_failure @gateway.make_order(:order_number => order_number,
                                       :amount => @amount,
                                       :description => @description,
                                       :return_url => @return_url)
  end

  private

  def assert_valid_response(response)
    assert_not_nil response.params['order_number']
    assert_equal @amount, response.params['amount']
    assert_equal '810', response.params['currency']
    assert_equal @description, response.params['order_description']
  end
end
