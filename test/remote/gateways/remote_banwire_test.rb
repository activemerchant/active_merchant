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

def test_transcript_scrubbing
  transcript = capture_transcript(@gateway) do
    @gateway.purchase(@amount, @credit_card, @options)
  end
  clean_transcript = @gateway.scrub(transcript)

  assert_scrubbed(@credit_card.number, clean_transcript)
  assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
end

end
