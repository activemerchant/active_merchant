module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SageVaultGateway < Gateway #:nodoc:
      self.live_url = 'https://www.sagepayments.net/web_services/wsVault/wsVault.asmx'

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def store(credit_card, options = {})
        request = build_store_request(credit_card, options)
        commit(:store, request)
      end

      def unstore(identification, options = {})
        request = build_unstore_request(identification, options)
        commit(:unstore, request)
      end

      private

      # A valid request example, since the Sage docs have none:
      #
      # <?xml version="1.0" encoding="UTF-8" ?>
      # <SOAP-ENV:Envelope
      #   xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"
      #   xmlns:ns1="https://www.sagepayments.net/web_services/wsVault/wsVault">
      #   <SOAP-ENV:Body>
      #     <ns1:INSERT_CREDIT_CARD_DATA>
      #       <ns1:M_ID>279277516172</ns1:M_ID>
      #       <ns1:M_KEY>O3I8G2H8V6A3</ns1:M_KEY>
      #       <ns1:CARDNUMBER>4111111111111111</ns1:CARDNUMBER>
      #       <ns1:EXPIRATION_DATE>0915</ns1:EXPIRATION_DATE>
      #     </ns1:INSERT_CREDIT_CARD_DATA>
      #   </SOAP-ENV:Body>
      # </SOAP-ENV:Envelope>
      def build_store_request(credit_card, options)
        xml = Builder::XmlMarkup.new
        add_credit_card(xml, credit_card, options)
        xml.target!
      end

      def build_unstore_request(identification, options)
        xml = Builder::XmlMarkup.new
        add_identification(xml, identification, options)
        xml.target!
      end

      def add_customer_data(xml)
        xml.tag! 'ns1:M_ID', @options[:login]
        xml.tag! 'ns1:M_KEY', @options[:password]
      end

      def add_credit_card(xml, credit_card, options)
        xml.tag! 'ns1:CARDNUMBER', credit_card.number
        xml.tag! 'ns1:EXPIRATION_DATE', exp_date(credit_card)
      end

      def add_identification(xml, identification, options)
        xml.tag! 'ns1:GUID', identification
      end

      def exp_date(credit_card)
        year  = sprintf("%.4i", credit_card.year)
        month = sprintf("%.2i", credit_card.month)

        "#{month}#{year[-2..-1]}"
      end

      def commit(action, request)
        response = parse(ssl_post(live_url,
          build_soap_request(action, request),
          build_headers(action))
        )

        case action
        when :store
          success = response[:success] == 'true'
          message = response[:message].downcase.capitalize if response[:message]
        when :unstore
          success = response[:delete_data_result] == 'true'
          message = success ? 'Succeeded' : 'Failed'
        end

        Response.new(success, message, response,
          authorization: response[:guid]
        )
      end

      ENVELOPE_NAMESPACES = {
        'xmlns:SOAP-ENV' => "http://schemas.xmlsoap.org/soap/envelope/",
        'xmlns:ns1' => "https://www.sagepayments.net/web_services/wsVault/wsVault"
      }

      ACTION_ELEMENTS = {
        store: 'INSERT_CREDIT_CARD_DATA',
        unstore: 'DELETE_DATA'
      }

      def build_soap_request(action, body)
        xml = Builder::XmlMarkup.new

        xml.instruct!
        xml.tag! 'SOAP-ENV:Envelope', ENVELOPE_NAMESPACES do
          xml.tag! 'SOAP-ENV:Body' do
            xml.tag! "ns1:#{ACTION_ELEMENTS[action]}" do
              add_customer_data(xml)
              xml << body
            end
          end
        end
        xml.target!
      end

      SOAP_ACTIONS = {
        store: 'https://www.sagepayments.net/web_services/wsVault/wsVault/INSERT_CREDIT_CARD_DATA',
        unstore: 'https://www.sagepayments.net/web_services/wsVault/wsVault/DELETE_DATA'
      }

      def build_headers(action)
        {
          "SOAPAction" => SOAP_ACTIONS[action],
          "Content-Type" => "text/xml; charset=utf-8"
        }
      end

      def parse(body)
        response = {}
        hashify_xml!(body, response)
        response
      end

      def hashify_xml!(xml, response)
        xml = REXML::Document.new(xml)

        # Store
        xml.elements.each("//Table1/*") do |node|
          response[node.name.underscore.to_sym] = node.text
        end

        # Unstore
        xml.elements.each("//DELETE_DATAResponse/*") do |node|
          response[node.name.underscore.to_sym] = node.text
        end
      end
    end
  end
end
