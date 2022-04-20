require 'test_helper'

module AuthorizeHelper
  def acceptjs_token(options = {})
    defaults = {
      opaque_data: {
        data_value: '1234567890ABCDEF1111AAAA2222BBBB3333CCCC4444DDDD5555EEEE6666FFFF7777888899990000',
        data_descriptor: 'COMMON.ACCEPT.INAPP.PAYMENT'
      }
    }.update(options)

    ActiveMerchant::Billing::AcceptJsToken.new(defaults)
  end

  def get_sandbox_acceptjs_token_for_credit_card(credit_card)
    sandbox_endpoint = 'https://apitest.authorize.net/xml/v1/request.api'
    sandbox_credentials = fixtures(:authorize_net)

    AcceptJsTestToken.new(
      credit_card,
      endpoint: sandbox_endpoint,
      credentials: sandbox_credentials
    ).token
  end

  class AcceptJsTestToken
    attr_reader :credit_card, :options

    def initialize(credit_card, options = {})
      @credit_card = credit_card
      @options = {
      }.merge(options)
    end

    def token
      xml = build_xml
      response = make_request xml
      opaque_data = parse_response response

      ActiveMerchant::Billing::AcceptJsToken.new(opaque_data: opaque_data)
    end

    private

    def build_xml
      xml = Builder::XmlMarkup.new(:indent => 2)
      xml.instruct!(:xml, :version => '1.0', :encoding => 'utf-8')
      xml.tag!('securePaymentContainerRequest', :xmlns => 'AnetApi/xml/v1/schema/AnetApiSchema.xsd') do
        xml.tag!('merchantAuthentication') do
          creds = options[:credentials]
          xml.tag!('name', creds[:login])
          xml.tag!('transactionKey', creds[:password])
        end
        xml.tag!('refId', options[:ref_id]) if options[:ref_id]
        xml.tag!('data') do
          xml.tag!('type', 'TOKEN')
          xml.tag!('id', SecureRandom.uuid)
          xml.tag!('token') do
            xml.tag!('cardNumber', credit_card.number)
            xml.tag!('expirationDate', ('%02d' % credit_card.month) + credit_card.year.to_s)
            xml.tag!('cardCode', credit_card.verification_value)
            xml.tag!('fullName', "#{credit_card.first_name} #{credit_card.last_name}")
          end
        end
      end

      xml
    end

    def make_request(xml)
      uri = URI.parse(options[:endpoint])
      req = Net::HTTP::Post.new(uri.path)
      req.body = xml.target!
      req.content_type = 'text/xml'

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      resp = http.request(req)

      raise "HTTP #{resp.code} response code tokenizing test card" if resp.code != '200'
      raise "HTTP incorrect content type #{resp.content_type} tokenizing test card" if resp.content_type != 'application/xml'

      resp
    end

    def parse_response(response)
      xml = REXML::Document.new(response.body)
      root = REXML::XPath.first(xml, '//securePaymentContainerResponse') ||
             REXML::XPath.first(xml, '//ErrorResponse')
      if root
        response = parse_element(root)
      end

      raise "Result code #{response['messages']['result_code']}: #{response['messages']['message']['code']}" if response['messages']['result_code'] != 'Ok'

      {
        data_descriptor: response['opaque_data']['data_descriptor'],
        data_value: response['opaque_data']['data_value']
      }
    end

    def parse_element(node)
      if node.has_elements?
        response = {}
        node.elements.each { |e|
          key = e.name.underscore
          value = parse_element(e)
          if response.has_key?(key)
            if response[key].is_a?(Array)
              response[key].push(value)
            else
              response[key] = [response[key], value]
            end
          else
            response[key] = parse_element(e)
          end
        }
      else
        response = node.text
      end

      response
    end
  end
end
