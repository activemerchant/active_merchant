require 'test_helper'

class RemoteRapydTest < Test::Unit::TestCase
  def setup
    @gateway = XpayGateway.new(fixtures(:xpay))
    @amount = 100
    @credit_card = credit_card(
      '5186151650005008',
      month: 12,
      year: 2026,
      verification_value: '123',
      brand: 'master'
    )

    @options = {
      order_id: SecureRandom.alphanumeric(10),
      billing_address: address,
      order: {
        currency: 'EUR',
        amount: @amount
      }
    }
  end

  def test_successful_purchase
    response = @gateway.preauth(@amount, @credit_card, @options)
    assert_success response
    assert_true response.params.has_key?('threeDSAuthUrl')
    assert_true response.params.has_key?('threeDSAuthRequest')
    assert_match 'PENDING', response.message
  end

  def test_failed_purchase
    init = @gateway.purchase(@amount, @credit_card, {})
    assert_failure init
    assert_equal 'GW0001', init.error_code
  end

  # def test_successful_verify  ## test not working
  #   response = @gateway.verify(@credit_card, @options)
  #   assert_success response
  #   assert_match 'PENDING', response.message
  # end

  # def test_successful_refund ## test requires set up (purchase or auth through 3ds)
  #   options = {
  #     order: {
  #       currency: 'EUR',
  #       description: 'refund operation message'
  #     },
  #     operation_id: '168467730273233329'
  #   }
  #   response = @gateway.refund(@amount, options)
  #   assert_success response
  # end

  # def test_successful_void ## test requires set up (purchase or auth through 3ds)
  #   options = {
  #     description: 'void operation message',
  #     operation_id: '168467730273233329'
  #   }
  #   response = @gateway.void(@amount, options)
  #   assert_success response
  # end
end
