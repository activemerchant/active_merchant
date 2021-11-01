require 'test_helper'

class RemoteFourCsOnlineTest < Test::Unit::TestCase
  def setup
    @gateway = FourCsOnlineGateway.new(fixtures(:four_cs_online))

    @amount = 100
    @credit_card = credit_card('4444111122223333')
    @declined_card = credit_card('4444111122221113')
    @incomplete_card = credit_card('4444111122225551')
    @expired_card = credit_card('4444111122223333', year: Time.now.year - 1)
    @options = {
      invoice: Time.now.to_i,
      transaction_id: Time.now.to_i,
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_more_options
    invoice = Time.now.to_i.to_s
    transaction_id = invoice

    options = {
      invoice: invoice,
      transaction_id: transaction_id
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal invoice, response.params['invoice']
    assert_equal transaction_id, response.params['tran_id']
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_expired_card
    response = @gateway.authorize(@amount, @expired_card, @options)
    assert_failure response
    assert_equal 'Incomplete', response.message
    assert_equal 'ParameterError', response.params['result_code']
    assert_equal 'Bad Parameter: ExpiryMMYY', response.error_code
  end

  def test_invalid_login
    gateway = FourCsOnlineGateway.new(merchant_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Incomplete', response.message
    assert_equal 'Bad Parameter: MerchantKey', response.error_code
  end
end
