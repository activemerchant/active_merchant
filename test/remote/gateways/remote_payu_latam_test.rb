#encoding: utf-8
require 'test_helper'

class RemotePayuLatamTest < Test::Unit::TestCase
  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
  def setup    
    @gateway = PayuCoGateway.new(fixtures(:payu_latam))

    @amount = 10000
    @credit_card = credit_card('4000100011112224', {first_name: "APPROVED", last_name: ""})
    @declined_card = credit_card('4000300011112220', {first_name: "REJECTED", last_name: ""})
    @options = {
      user: {
        identification: "123", 
        full_name: "APPROVED", 
        email: "test@test.com"
      }, 
      billing_address: {
        street1: "123", 
        street2: "", 
        city: "Barranquilla", 
        state: "Atlantico", 
        country: "CO", 
        zip: "080020", 
        phone: "1234"
      }
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal nil, response.message
  end

  def test_failed_purchase
    options = {
      user: {
        identification: "123", 
        full_name: "REJECTED", 
        email: "test@test.com"
      }, 
      billing_address: {
        street1: "123", 
        street2: "", 
        city: "Barranquilla", 
        state: "Atlantico", 
        country: "CO", 
        zip: "080020", 
        phone: "1234"
      }
    }
    response = @gateway.purchase(@amount, @declined_card, options)    
    
    assert_equal 'DECLINED', response.params["transactionResponse"]["state"]
  end

  # these methods cannot be remotely tested because they need a real credit card and a real order_id due that they does not have
  # a testing environment for these methods

  # def test_successful_refund
  #   purchase = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success purchase

  #   transaction = purchase.params["transactionResponse"]    

  #   refund_options = {order_id: transaction["orderId"], reason: "reson for the refund", transaction_id: transaction["transactionId"]}

  #   assert refund = @gateway.refund(refund_options)
  #   assert_success refund
  #   assert_equal '', refund.params
  # end

  # def test_failed_refund
  #   response = @gateway.refund({})   
    
  #   assert_match "property: parentTransactionId, message: No puede ser vacio", response.message
  # end

  # def test_successful_void
  #   purchase = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success purchase

  #   transaction = purchase.params["transactionResponse"]    

  #   assert void = @gateway.void({order_id: transaction["orderId"], reason: "testing", transaction_id: transaction["transactionId"]})
  #   assert_success void
  #   assert_equal '', void.params
  # end

  # def test_failed_void
  #   response = @gateway.void({})
    
  #   assert_match /property: parentTransactionId, message: No puede ser vacio/, response.message
  # end

  # def test_order_status
  #   purchase = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success purchase

  #   transaction = purchase.params["transactionResponse"]    

  #   refund_options = {order_id: transaction["orderId"], reason: "reson for the refund", transaction_id: transaction["transactionId"]}
  #   assert refund = @gateway.refund(refund_options)
  #   assert_success refund

  #   assert order_status = @gateway.order_status(transaction["orderId"])
  #   assert_success order_status
  #   assert_equal '', order_status.params
  # end

  # def test_invalid_login
  #   gateway = PayuCoGateway.new({login: '', key: '', merchant_id: '', account_id: ''})

  #   response = gateway.purchase(@amount, @credit_card, @options)
    
  #   assert_match %r{El parámetro api login no puede estar vacío.}, response.message
  # end

end
