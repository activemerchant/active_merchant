require 'test_helper'

class KomerciTest < Test::Unit::TestCase
  def setup
    @gateway = EredeGateway.new(
      fixtures(:erede)
    )

    @credit_card = credit_card
    @amount = 1

    @options = {
        :order_id => generate_unique_id.slice(0, 15),
        :buyer_cpf => '99999999999',
        :billing_address => {
          :street => 'Avenida Brigadeiro Faria Lima',
          :number => '666',
          :neighborhood => 'Flamengo',
          :city => 'Rio de Janeiro',
          :country => '076',
          :state => 'Rio de Janeiro',
          :postcode => '99999999'
        }
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).once.returns(successful_authorize_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal '4444', response.authorization
    assert response.test?
  end

  def test_failed_cv2avs_purchase
    @gateway.expects(:ssl_request).once.returns(failed_authorize_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert response.test?
  end

  private

  def successful_authorize_response
    <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <Response version="2">
        <CardTxn>
          <authcode>4444</authcode>
          <card_scheme>VISA</card_scheme>
          <country>United Kingdom</country>
        </CardTxn>
          <acquirer>Rede</acquirer>
        <auth_host_reference>3</auth_host_reference>
        <gateway_reference>4600903000000002</gateway_reference>
        <extended_response_message>Sucesso</extended_response_message>
        <extended_status>00</extended_status>
        <merchantreference>123403</merchantreference>
        <mid>456732145</mid>
        <mode>TEST</mode>
        <reason>ACCEPTED</reason>
        <status>1</status>
        <time>1372847996</time>
      </Response>
    XML
  end

  def failed_authorize_response
    <<-XML
      ?xml version="1.0" encoding="UTF-8"?>
      <Response version='2'>
        <CardTxn>
          <Cv2Avs>
            <cv2avs_status reversal='1'>SECURITY CODE MATCH ONLY</cv2avs_status>
            <policy>3</policy>
          </Cv2Avs>
          <authcode>794408</authcode>
          <card_scheme>VISA</card_scheme>
          <country>Brazil</country>
          <issuer>banco santander s.a.</issuer>
        </CardTxn>
        <acquirer>Redecard</acquirer>
        <auth_host_reference>2008273</auth_host_reference>
        <gateway_reference>3000900010290935</gateway_reference>
        <extended_response_message>Sucesso</extended_response_message>
        <extended_status>00</extended_status>
        <merchantreference>12345test</merchantreference>
        <mid>050442546</mid>
        <mode>LIVE</mode>
        <reason>CV2AVS DECLINED</reason>
        <status>7</status>
        <time>1403619879</time>
      </Response>
    XML
  end
end
