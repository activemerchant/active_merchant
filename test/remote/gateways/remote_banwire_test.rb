# encoding: utf-8
require 'test_helper'

class RemoteBanwireTest < Test::Unit::TestCase
  def setup
    @gateway = BanwireGateway.new(fixtures(:banwire))

    @amount = 100
    @credit_card = credit_card('5204164299999999', :verification_value => '999', :brand => 'mastercard')
    @visa_credit_card = credit_card('4485814063899108', :verification_value => '434')

    @declined_card = credit_card('4000300011112220')
    @options = {
      billing_address: address,
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_visa_purchase
    assert response = @gateway.purchase(@amount, @visa_credit_card, @options)
    assert_success response
  end

  def test_successful_purchase_with_extra_options
    options = {
      order_id: '1',
      email: "test@email.com",
      billing_address: address,
      description: 'Store Purchase'
    }
    assert response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end


  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Pago Denegado.', response.message
  end

  def test_invalid_login
    gateway = BanwireGateway.new(
                :login => 'fakeuser',
                :currency => 'MXN'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'ID de cuenta invalido', response.message
  end

  def test_successful_store
    assert response = @gateway.store(credit_card, @options)
    assert_success = response
    assert response.authorization =~ /crd\./
  end

  def test_unsuccessful_store
    assert response = @gateway.store(credit_card('4000300011112220', month: 13), @options)
    assert_failure = response
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    # we force the check on the param name since the test card number from Banwire contains the
    # same digits we are trying to verify are not present, the response from the gateway
    # contains the last few digits from the card, which are the same as the CVV.
    # If we supply a different CVV, say 888, Banwire fails the test transactions.
    assert_scrubbed("card_ccv2=#{@credit_card.verification_value.to_s}", clean_transcript)
  end

end
