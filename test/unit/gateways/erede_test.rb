require 'test_helper'

class EredeTest < Test::Unit::TestCase
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
        },
        :instalments => {
          type: :zero_interest,
          number: 2
        }
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).once.returns(successful_authorize_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal '4600903000000002', response.authorization[:gateway_reference]
    assert response.test?
  end

  def test_successful_boleto_purchase
    @gateway.expects(:ssl_request).once.returns(successful_boleto_authorize_response)
    options = {}
    options[:expiry_date] = '2013-04-01'
    options[:instructions] = 'Wops'
    options[:last_name] = 'Wops'
    options[:first_name] = 'Wops'

    assert response = @gateway.purchase(@amount, :boleto_bancario, @options.merge(options))

    assert_success response
    assert_equal 'http://www.domain.com/generatedurl456', response.authorization[:boleto_url]
    assert response.test?
  end

  def test_boleto_query
    @gateway.expects(:ssl_request).once.returns(boleto_query)

    assert response = @gateway.query('536')

    assert_equal 'PENDING', response.message
    assert_success response
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

  def successful_boleto_authorize_response
    <<-XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Response version="2">
          <BoletoTxn>
              <method>payment</method>
              <language>es</language>
              <customer_email>john@mail.com</customer_email>
              <customer_ip>127.0.0.1</customer_ip>
              <title>MR</title>
              <first_name>JOHN</first_name>
              <last_name>CAIXA</last_name>
              <country>BR</country>
              <billing_street1>Address Line 1</billing_street1>
              <billing_city>JA</billing_city>
              <billing_postcode>12345</billing_postcode>
              <billing_country>BR</billing_country>
              <customer_telephone>00000000000</customer_telephone>
              <interest_per_day>0.1</interest_per_day>
              <overdue_fine>0.05</overdue_fine>
              <expiry_date>2013-04-01</expiry_date>
              <processor_id>11</processor_id>
              <instructions>Não aceitar pagamento em cheques. Inadimplente - Percentual Juros Dia: 10%. Percentual Multa: 5%.</instructions>
              <boleto_url>http://www.domain.com/generatedurl456</boleto_url>
              <order_id>7F000001:013829A1C09E:8DE9:016891F0</order_id>
              <transaction_id>1418605</transaction_id>
              <txn_status>PENDING</txn_status>
              <barcode_number>23791234056000000000401000123404856240000010000</barcode_number>
          </BoletoTxn>
          <gateway_reference>4200000027950077</gateway_reference>
          <merchantreference>boleto1234</merchantreference>
          <mode>LIVE</mode>
          <reason>ACCEPTED</reason>
          <status>1</status>
          <time>1341312709</time>
        </Response>
    XML
  end

  def boleto_query
    <<-XML
      <Response version="2">
          <QueryTxnResult>
              <BoletoTxn>
                  <amount>100.00</amount>
                  <billing_city>SP</billing_city>
                  <billing_country>BR</billing_country>
                  <billing_postcode>12949-110</billing_postcode>
                  <billing_street1>Av. Paulista 1111</billing_street1>
                  <boleto_number>536</boleto_number>
                  <boleto_url>https://testboletos.maxipago.net/redirection_service/boleto?ref=LmO9fsnOXyUgTcRusHkbMQFQxVkk9OBmXEK5CanaeV8JEVxxqROSI7%2Bawb9qrL8ZTSC4pnEbe8iF%0AmHp1r%2FX7Vg%3D%3D</boleto_url>
                  <customer_email>jojojo@dominio.com.br</customer_email>
                  <customer_ip>127.0.0.1</customer_ip>
                  <customer_telephone>1135938203</customer_telephone>
                  <expiry_date>2013-04-01</expiry_date>
                  <first_name>Daniel</first_name>
                  <instructions>Não aceitar pagamento em cheques. Percentual Juros Dia: 1%. Percentual Multa: 1%.</instructions>
                  <interest_per_day>0.01</interest_per_day>
                  <last_name>Lucats</last_name>
                  <merchant_id>3701</merchant_id>
                  <order_id>536</order_id>
                  <overdue_fine>0.01</overdue_fine>
                  <payment_status>PENDING</payment_status>
                  <processor_id>11</processor_id>
                  <transaction_id>543966</transaction_id>
              </BoletoTxn>
              <gateway_reference>3600900010035659</gateway_reference>
              <merchantreference>Teste28061003</merchantreference>
              <reason>Boleto Bancario payment pending</reason>
              <status>1911</status>
          </QueryTxnResult>
          <mode>LIVE</mode>
          <reason>ACCEPTED</reason>
          <status>1</status>
          <time>1372424737</time>
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
