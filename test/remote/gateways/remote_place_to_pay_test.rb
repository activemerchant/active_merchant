require 'test_helper'

class RemotePlaceToPayTest < Test::Unit::TestCase
  def setup
    @default_gateway = PlaceToPayGateway.new(fixtures(:place_to_pay_default))
    #@default_gateway = PlaceToPayGateway.new(login: '11caf20f5cd408c9b22c7f0693e2f676', secret_key: 'yLb0x2IO2lO65zq7')
    
    @amount = 100

    @payer = {
      name: "Erika",
      surname: "Howe",
      email: "cwilliamson@hotmail.com",
      documentType: "CC",
      document: "3572264088",
      mobile: "3006108300"
    }
    payment = {
      description: 'Cum vitae et consequatur quas adipisci ut rem.',
      amount: {
        currency: @default_gateway.default_currency,
        total: @amount
      }
    }
    instrument = {
      card: {
        installments: 1
      }
    }

    @credit_card_approved_diners = credit_card('36545400000008', month: 12, year: 2023, verification_value: '123', first_name: @payer[:name], last_name: @payer[:surname])
    @credit_card_rejected_diners = credit_card('36545400000248', month: 12, year: 2023, verification_value: '123', first_name: @payer[:name], last_name: @payer[:surname])
    @credit_card_approved_visa = credit_card('4110760000000081', month: 12, year: 2023, verification_value: '123', first_name: @payer[:name], last_name: @payer[:surname])
    @credit_card_rejected_visa = credit_card('4110760000000016', month: 12, year: 2023, verification_value: '123', first_name: @payer[:name], last_name: @payer[:surname])
    @credit_card_approved_3DSC_visa = credit_card('4110760000000008', month: 12, year: 2023, verification_value: '123', first_name: @payer[:name], last_name: @payer[:surname])

    
    @purchase_options = {
      payer: @payer,
      payment: payment,
      instrument: instrument
    }
  end

  def test_successful_purchase_diners
    @purchase_options[:payment][:reference] = "TEST_" + Time.now.strftime("%Y%m%d_%H%M%S%3N")
    response = @default_gateway.purchase(@amount, @credit_card_approved_diners, @purchase_options)
    assert_success response
    assert_equal 'Aprobada', response.message
  end

  def test_failed_purchase_diners
    @purchase_options[:payment][:reference] = "TEST_" + Time.now.strftime("%Y%m%d_%H%M%S%3N")
    response = @default_gateway.purchase(@amount, @credit_card_rejected_diners, @purchase_options)
    assert_success response
    assert_equal 'Rechazada', response.message
  end

  def test_successful_purchase_visa
    @purchase_options[:payment][:reference] = "TEST_" + Time.now.strftime("%Y%m%d_%H%M%S%3N")
    response = @default_gateway.purchase(@amount, @credit_card_approved_visa, @purchase_options)
    assert_success response
    assert_equal 'Aprobada', response.message
  end

  def test_failed_purchase_visa
    @purchase_options[:payment][:reference] = "TEST_" + Time.now.strftime("%Y%m%d_%H%M%S%3N")
    response = @default_gateway.purchase(@amount, @credit_card_rejected_visa, @purchase_options)
    assert_success response
    assert_equal 'Rechazada', response.message
  end

  def test_partial_capture
    @purchase_options[:payment][:reference] = "TEST_" + Time.now.strftime("%Y%m%d_%H%M%S%3N")
    purchase = @default_gateway.purchase(@amount, @credit_card_approved_visa, @purchase_options)
    assert_success purchase
    assert_equal 'Aprobada', purchase.message

    capture_options = { 
      reference: @purchase_options[:payment][:reference],
      currency: @default_gateway.default_currency,
      total: @amount
    }

    assert capture = @default_gateway.capture(@amount, purchase.authorization, capture_options)
    assert_success capture
  end

  def test_failed_capture
    capture_options = { 
      reference: "TEST_NON_EXISTING_" + Time.now.strftime("%Y%m%d_%H%M%S%3N"),
      currency: @default_gateway.default_currency,
      total: @amount
    }

    assert capture = @default_gateway.capture(@amount, purchase.authorization, capture_options)
    assert_equal 'No se ha encontrado información con los datos proporcionados', capture.message
    #assert_failure capture
  end

  def test_successful_refund
    @purchase_options[:payment][:reference] = "TEST_" + Time.now.strftime("%Y%m%d_%H%M%S%3N")
    purchase = @default_gateway.purchase(@amount, @credit_card_approved_visa, @purchase_options)
    assert_success purchase
    assert_equal 'APPROVED', purchase.success

    #puts purchase.inspect

    refund_options =  { internalReference: purchase.network_transaction_id }
    assert refund = @default_gateway.refund(
      :money => purchase.params[:amount], 
      :authorization => purchase.authorization, 
      :options => refund_options
      )
    assert_success refund
    assert_equal 'REFUNDED', refund.success
  end

  def test_failed_refund
    refund_options =  { internalReference: -1 }
    assert refund = @default_gateway.refund(
      :money => "", 
      :authorization => -1, 
      :options => refund_options
      )
    assert_failure refund
    assert_equal 'FAILED', refund.success
  end

  def test_successful_void
    @purchase_options[:payment][:reference] = "TEST_" + Time.now.strftime("%Y%m%d_%H%M%S%3N")
    purchase = @default_gateway.purchase(@amount, @credit_card_approved_visa, @purchase_options)
    assert_success purchase
    assert_equal 'Aprobada', purchase.message

    assert void = @default_gateway.void(purchase.authorization, { internalReference: purchase.network_transaction_id })
    assert_success void
  end

  def test_failed_void
    assert void = @default_gateway.void('', { internalReference: '' })
    assert_equal 'Es necesario proveer el parametro internalReference', void.message
    #assert_failure void
  end

  # def test_dump_transcript
  #   # This test will run a purchase transaction on your gateway
  #   # and dump a transcript of the HTTP conversation so that
  #   # you can use that transcript as a reference while
  #   # implementing your scrubbing logic.  You can delete
  #   # this helper after completing your scrub implementation.
  #   dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  # end

  # def test_transcript_scrubbing
  #   transcript = capture_transcript(@gateway) do
  #     @gateway.purchase(@amount, @credit_card, @options)
  #   end
  #   transcript = @gateway.scrub(transcript)

  #   assert_scrubbed(@credit_card.number, transcript)
  #   assert_scrubbed(@credit_card.verification_value, transcript)
  #   assert_scrubbed(@gateway.options[:password], transcript)
  # end
end