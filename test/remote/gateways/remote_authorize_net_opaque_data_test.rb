require 'test_helper'

class RemoteAuthorizeNetOpaqueDataTest < Test::Unit::TestCase
  def setup
    @gateway = AuthorizeNetGateway.new(fixtures(:authorize_net))

    @amount = 100
    @opaque_data_payment_token = generate_opaque_data_payment_token

    @options = {
      order_id: '1',
      email: 'anet@example.com',
      duplicate_window: 0,
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_opaque_data_authorization
    response = @gateway.authorize(5, @opaque_data_payment_token, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_opaque_data_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @opaque_data_payment_token, @options)
    assert_success authorization

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert_equal 'This transaction has been approved', capture.message
  end

  def test_successful_opaque_data_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @opaque_data_payment_token, @options)
    assert_success authorization

    assert void = @gateway.void(authorization.authorization)
    assert_success void
    assert_equal 'This transaction has been approved', void.message
  end

  def test_failed_opaque_data_authorization
    opaque_data_payment_token = ActiveMerchant::Billing::AuthorizeNetGateway::OpaqueDataToken.new('garbage', data_descriptor: 'COMMON.ACCEPT.INAPP.PAYMENT')
    response = @gateway.authorize(@amount, opaque_data_payment_token, @options)
    assert_failure response
    assert_equal "OTS Service Error 'Field validation error.'", response.message
    assert_equal '117', response.params['response_reason_code']
  end

  def test_failed_opaque_data_purchase
    opaque_data_payment_token = ActiveMerchant::Billing::AuthorizeNetGateway::OpaqueDataToken.new('garbage', data_descriptor: 'COMMON.ACCEPT.INAPP.PAYMENT')
    response = @gateway.purchase(@amount, opaque_data_payment_token, @options)
    assert_failure response
    assert_equal "OTS Service Error 'Field validation error.'", response.message
    assert_equal '117', response.params['response_reason_code']
  end

  private

  def accept_js_gateway
    @accept_js_gateway ||= AcceptJsGateway.new(fixtures(:authorize_net))
  end

  def fetch_public_client_key
    @fetch_public_client_key ||= accept_js_gateway.public_client_key
  end

  def generate_opaque_data_payment_token
    cc = credit_card('4000100011112224')
    options = { public_client_key: fetch_public_client_key, name: address[:name] }
    opaque_data = accept_js_gateway.accept_js_token(cc, options)
    ActiveMerchant::Billing::AuthorizeNetGateway::OpaqueDataToken.new(opaque_data[:data_value], data_descriptor: opaque_data[:data_descriptor])
  end

  class AcceptJsGateway < ActiveMerchant::Billing::AuthorizeNetGateway
    # API calls to get a payment nonce from Authorize.net should only originate from javascript, usign authnet's accept.js library.
    # This gateway implements the API calls necessary to replicate accept.js client behavior, so that we can test authorizations and purchases using an accept.js payment nonce.
    # https://developer.authorize.net/api/reference/features/acceptjs.html

    def public_client_key
      response = commit(:merchant_details) {}
      response.params.dig('getMerchantDetailsResponse', 'publicClientKey')
    end

    def accept_js_token(credit_card, options={})
      request = accept_js_request_body(credit_card, options)
      raw_response = ssl_post(url, request, headers)
      opaque_data = parse(:accept_js_token_request, raw_response).dig('securePaymentContainerResponse', 'opaqueData')
      {
        data_descriptor: opaque_data['dataDescriptor'],
        data_value: opaque_data['dataValue']
      }
    end

    private

    def accept_js_request_body(credit_card, options={})
      Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.send('securePaymentContainerRequest', 'xmlns' => 'AnetApi/xml/v1/schema/AnetApiSchema.xsd') do
          xml.merchantAuthentication do
            xml.name(@options[:login])
            xml.clientKey(options[:public_client_key])
          end
          xml.data do
            xml.type('TOKEN')
            xml.id(SecureRandom.uuid)
            xml.token do
              xml.cardNumber(truncate(credit_card.number, 16))
              xml.expirationDate(format(credit_card.month, :two_digits) + '/' + format(credit_card.year, :four_digits))
              xml.fullName options[:name]
            end
          end
        end
      end.to_xml(indent: 0)
    end

    def root_for(action)
      if action == :merchant_details
        'getMerchantDetailsRequest'
      else
        super
      end
    end

    def parse_normal(action, body)
      doc = Nokogiri::XML(body)
      doc.remove_namespaces!
      Hash.from_xml(doc.to_s)
    end

  end

end
