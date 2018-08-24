require 'test_helper'

class RemoteCtPaymentCertificationTest < Test::Unit::TestCase
  def setup
    @gateway = CtPaymentGateway.new(fixtures(:ct_payment))

    @amount = 100
    @declined_card = credit_card('4502244713161718')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      merchant_terminal_number: '     ',
      order_id: generate_unique_id[0,11]
    }
  end

  def test1
    @credit_card = credit_card('4501161107217214', month: '07', year: 2025)
    response = @gateway.purchase(@amount, @credit_card, @options)
    print_result(1, response)
  end

  def test2
    @credit_card = credit_card('5194419000000007', month: '07', year: 2025)
    @credit_card.brand = 'master'
    response = @gateway.purchase(@amount, @credit_card, @options)
    print_result(2, response)
  end

  def test3
    @credit_card = credit_card('341400000000000', month: '07', year: 2025, verification_value: '1234')
    @credit_card.brand = 'american_express'
    response = @gateway.purchase(@amount, @credit_card, @options)
    print_result(3, response)
  end

  def test6
    @credit_card = credit_card('341400000000000', month: '07', year: 2025, verification_value: '1234')
    @credit_card.brand = 'american_express'
    response = @gateway.credit(@amount, @credit_card, @options)
    print_result(6, response)
  end

  def test4
    @credit_card = credit_card('4501161107217214', month: '07', year: 2025)
    response = @gateway.credit(@amount, @credit_card, @options)
    print_result(4, response)
  end

  def test5
    @credit_card = credit_card('5194419000000007', month: '07', year: 2025)
    @credit_card.brand = 'master'
    response = @gateway.credit(@amount, @credit_card, @options)
    print_result(5, response)
  end

  def test7
    @credit_card = credit_card('4501161107217214', month: '07', year: 2025)
    response = @gateway.authorize(@amount, @credit_card, @options)
    print_result(7, response)

    capture_response = @gateway.capture(@amount, response.authorization, @options.merge(order_id: generate_unique_id[0,11]))
    print_result(10, capture_response)
  end

  def test8
    @credit_card = credit_card('5194419000000007', month: '07', year: 2025)
    @credit_card.brand = 'master'
    response = @gateway.authorize(@amount, @credit_card, @options)
    print_result(8, response)

    capture_response = @gateway.capture(@amount, response.authorization, @options.merge(order_id: generate_unique_id[0,11]))
    print_result(11, capture_response)
  end

  def test9
    @credit_card = credit_card('341400000000000', month: '07', year: 2025, verification_value: '1234')
    @credit_card.brand = 'american_express'
    response = @gateway.authorize(@amount, @credit_card, @options.merge(order_id: generate_unique_id[0,11]))
    print_result(9, response)

    capture_response = @gateway.capture(@amount, response.authorization, @options)
    print_result(12, capture_response)
  end

  def test13
    @credit_card = credit_card('4501161107217214', month: '07', year: 2025)
    response = @gateway.purchase('000', @credit_card, @options)
    print_result(13, response)
  end

  def test14
    @credit_card = credit_card('4501161107217214', month: '07', year: 2025)
    response = @gateway.purchase(-100, @credit_card, @options)
    print_result(14, response)
  end

  def test15
    @credit_card = credit_card('4501161107217214', month: '07', year: 2025)
    response = @gateway.purchase('-1A0', @credit_card, @options)
    print_result(15, response)
  end

  def test16
    @credit_card = credit_card('5194419000000007', month: '07', year: 2025)
    @credit_card.brand = 'visa'
    response = @gateway.purchase(@amount, @credit_card, @options)
    print_result(16, response)
  end

  def test17
    @credit_card = credit_card('4501161107217214', month: '07', year: 2025)
    @credit_card.brand = 'master'
    response = @gateway.purchase(@amount, @credit_card, @options)
    print_result(17, response)
  end

  def test18
    @credit_card = credit_card('', month: '07', year: 2025)
    response = @gateway.purchase(@amount, @credit_card, @options)
    print_result(18, response)
  end

  def test19
    @credit_card = credit_card('4501123412341234', month: '07', year: 2025)
    response = @gateway.purchase(@amount, @credit_card, @options)
    print_result(19, response)
  end

  def test20
    #requires editing the model to run with a 3 digit expiration date
    @credit_card = credit_card('4501161107217214', month: '07', year: 2)
    response = @gateway.purchase(@amount, @credit_card, @options)
    print_result(20, response)
  end

  def test21
    @credit_card = credit_card('4501161107217214', month: 17, year: 2017)
    response = @gateway.purchase(@amount, @credit_card, @options)
    print_result(21, response)
  end

  def test22
    @credit_card = credit_card('4501161107217214', month: '01', year: 2016)
    response = @gateway.purchase(@amount, @credit_card, @options)
    print_result(22, response)
  end

  def test24
    @credit_card = credit_card('4502244713161718', month: '07', year: 2025)
    response = @gateway.purchase(@amount, @credit_card, @options)
    print_result(24, response)
  end

  def test25
    # Needs an edit to the Model to run
    @credit_card = credit_card('4501161107217214', month: '07', year: 2025)
    response = @gateway.purchase(@amount, @credit_card, @options)
    print_result(25, response)
  end

  def test26
    @credit_card = credit_card('4501161107217214', month: '07', year: 2025)
    response = @gateway.credit('000', @credit_card, @options)
    print_result(26, response)
  end

  def test27
    @credit_card = credit_card('4501161107217214', month: '07', year: 2025)
    response = @gateway.credit(-100, @credit_card, @options)
    print_result(27, response)
  end

  def test28
    @credit_card = credit_card('4501161107217214', month: '07', year: 2025)
    response = @gateway.credit('-1A0', @credit_card, @options)
    print_result(28, response)
  end

  def test29
    @credit_card = credit_card('5194419000000007', month: '07', year: 2025)
    @credit_card.brand = 'visa'
    response = @gateway.credit(@amount, @credit_card, @options)
    print_result(29, response)
  end

  def test30
    @credit_card = credit_card('4501161107217214', month: '07', year: 2025)
    @credit_card.brand = 'master'
    response = @gateway.credit(@amount, @credit_card, @options)
    print_result(30, response)
  end

  def test31
    @credit_card = credit_card('', month: '07', year: 2025)
    response = @gateway.purchase(@amount, @credit_card, @options)
    print_result(31, response)
  end

  def test32
    @credit_card = credit_card('4501123412341234', month: '07', year: 2025)
    response = @gateway.credit(@amount, @credit_card, @options)
    print_result(32, response)
  end

  def test33
    #requires edit to model to make 3 digit expiration date
    @credit_card = credit_card('4501161107217214', month: '07', year: 2)
    response = @gateway.credit(@amount, @credit_card, @options)
    print_result(33, response)
  end

  def test34
    @credit_card = credit_card('4501161107217214', month: 17, year: 2017)
    response = @gateway.credit(@amount, @credit_card, @options)
    print_result(34, response)
  end

  def test35
    @credit_card = credit_card('4501161107217214', month: '01', year: 2016)
    response = @gateway.credit(@amount, @credit_card, @options)
    print_result(35, response)
  end

  def test37
    @credit_card = credit_card('4502244713161718', month: '07', year: 2025)
    response = @gateway.purchase(@amount, @credit_card, @options)
    print_result(37, response)
  end

  def test38
    # Needs an edit to the Model to run
    @credit_card = credit_card('4501161107217214', month: '07', year: 2025)
    response = @gateway.purchase(@amount, @credit_card, @options)
    print_result(38, response)
  end

  def print_result(test_number, response)
    puts "Test #{test_number} | transaction number: #{response.params['transactionNumber']}, invoice number #{response.params['invoiceNumber']}, timestamp: #{response.params['timeStamp']}, result: #{response.params['returnCode']}"
    puts response.inspect
  end

end
