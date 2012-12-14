require 'test_helper'

class EwayTest < Test::Unit::TestCase
  def setup
    @gateway = EwayGateway.new(fixtures(:eway))
    @credit_card_success = credit_card('4444333322221111')
    @credit_card_fail = credit_card('1234567812345678',
      :month => Time.now.month,
      :year => Time.now.year
    )

    @params = {
      :order_id => '1230123',
      :email => 'bob@testbob.com',
      :billing_address => { :address1 => '47 Bobway',
                            :city => 'Bobville',
                            :state => 'WA',
                            :country => 'AU',
                            :zip => '2000'
                          } ,
      :description => 'purchased items'
    }
  end

  def test_invalid_amount
    assert response = @gateway.purchase(101, @credit_card_success, @params)
    assert_failure response
    assert response.test?
    assert_equal EwayGateway::MESSAGES["01"], response.message
  end

  def test_purchase_success_with_verification_value
    assert response = @gateway.purchase(100, @credit_card_success, @params)
    assert response.authorization
    assert_success response
    assert response.test?
    assert_equal EwayGateway::MESSAGES["00"], response.message
  end

  def test_purchase_success_without_verification_value
    @credit_card_success.verification_value = nil

    assert response = @gateway.purchase(100, @credit_card_success, @params)
    assert response.authorization
    assert_success response
    assert response.test?
    assert_equal EwayGateway::MESSAGES["00"], response.message
  end

  def test_purchase_error
    assert response = @gateway.purchase(100, @credit_card_fail, @params)
    assert_equal false, response.success?
    assert response.test?
  end

  def test_successful_refund
    assert response = @gateway.purchase(100, @credit_card_success, @params)
    assert_success response

    assert response = @gateway.refund(40, response.authorization)
    assert_success response
    assert_equal 'Transaction Approved', response.message
  end

  def test_failed_refund
    assert response = @gateway.purchase(100, @credit_card_success, @params)
    assert_success response

    assert response = @gateway.refund(200, response.authorization)
    assert_failure response
    assert_match /Error.*Your refund could not be processed./, response.message
  end
end
