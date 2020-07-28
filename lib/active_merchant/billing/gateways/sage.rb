module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SageGateway < Gateway
      include Empty

      self.display_name = 'http://www.sagepayments.com'
      self.homepage_url = 'Sage Payment Solutions'
      self.live_url = 'https://www.sagepayments.net/cgi-bin'

      self.supported_countries = %w[US CA]
      self.supported_cardtypes = %i[visa master american_express discover jcb diners_club]

      TRANSACTIONS = {
        purchase:       '01',
        authorization:  '02',
        capture:        '11',
        void:           '04',
        credit:         '06',
        refund:         '10'
      }

      SOURCE_CARD   = 'bankcard'
      SOURCE_ECHECK = 'virtual_check'

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def authorize(money, credit_card, options = {})
        post = {}
        add_credit_card(post, credit_card)
        add_transaction_data(post, money, options)
        commit(:authorization, post, SOURCE_CARD)
      end

      def purchase(money, payment_method, options = {})
        post = {}
        if card_brand(payment_method) == 'check'
          source = SOURCE_ECHECK
          add_check(post, payment_method)
          add_check_customer_data(post, options)
        else
          source = SOURCE_CARD
          add_credit_card(post, payment_method)
        end
        add_transaction_data(post, money, options)
        commit(:purchase, post, source)
      end

      # The +money+ amount is not used. The entire amount of the
      # initial authorization will be captured.
      def capture(money, reference, options = {})
        post = {}
        add_reference(post, reference)
        commit(:capture, post, SOURCE_CARD)
      end

      def void(reference, options = {})
        post = {}
        add_reference(post, reference)
        source = reference.split(';').last
        commit(:void, post, source)
      end

      def credit(money, payment_method, options = {})
        post = {}
        if card_brand(payment_method) == 'check'
          source = SOURCE_ECHECK
          add_check(post, payment_method)
          add_check_customer_data(post, options)
        else
          source = SOURCE_CARD
          add_credit_card(post, payment_method)
        end
        add_transaction_data(post, money, options)
        commit(:credit, post, source)
      end

      def refund(money, reference, options={})
        post = {}
        add_reference(post, reference)
        add_transaction_data(post, money, options)
        commit(:refund, post, SOURCE_CARD)
      end

      def store(credit_card, options = {})
        vault.store(credit_card, options)
      end

      def unstore(identification, options = {})
        vault.unstore(identification, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        force_utf8(transcript).
          gsub(%r((M_id=)[^&]*), '\1[FILTERED]').
          gsub(%r((M_key=)[^&]*), '\1[FILTERED]').
          gsub(%r((C_cardnumber=)[^&]*), '\1[FILTERED]').
          gsub(%r((C_cvv=)[^&]*), '\1[FILTERED]').
          gsub(%r((C_rte=)[^&]*), '\1[FILTERED]').
          gsub(%r((C_acct=)[^&]*), '\1[FILTERED]').
          gsub(%r((C_ssn=)[^&]*), '\1[FILTERED]').
          gsub(%r((<ns1:CARDNUMBER>).+(</ns1:CARDNUMBER>)), '\1[FILTERED]\2').
          gsub(%r((<ns1:M_ID>).+(</ns1:M_ID>)), '\1[FILTERED]\2').
          gsub(%r((<ns1:M_KEY>).+(</ns1:M_KEY>)), '\1[FILTERED]\2')
      end

      private

      # use the same method as in pay_conex
      def force_utf8(string)
        return nil unless string

        binary = string.encode('BINARY', invalid: :replace, undef: :replace, replace: '?') # Needed for Ruby 2.0 since #encode is a no-op if the string is already UTF-8. It's not needed for Ruby 2.1 and up since it's not a no-op there.
        binary.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      end

      def add_credit_card(post, credit_card)
        post[:C_name]       = credit_card.name
        post[:C_cardnumber] = credit_card.number
        post[:C_exp]        = expdate(credit_card)
        post[:C_cvv]        = credit_card.verification_value if credit_card.verification_value?
      end

      def add_check(post, check)
        post[:C_first_name]   = check.first_name
        post[:C_last_name]    = check.last_name
        post[:C_rte]          = check.routing_number
        post[:C_acct]         = check.account_number
        post[:C_check_number] = check.number
        post[:C_acct_type]    = account_type(check)
      end

      def add_check_customer_data(post, options)
        # Required  Customer Type – (NACHA Transaction Class)
        # CCD for Commercial, Merchant Initiated
        # PPD for Personal, Merchant Initiated
        # WEB for Internet, Consumer Initiated
        # RCK for Returned Checks
        # ARC for Account Receivable Entry
        # TEL for TelephoneInitiated
        post[:C_customer_type] = 'WEB'

        # Optional  10  Digit Originator  ID – Assigned  By for  each transaction  class  or  business  purpose. If  not provided, the default Originator ID for the specific  Customer Type will be applied. 
        post[:C_originator_id] = options[:originator_id]

        # Optional  Transaction Addenda
        post[:T_addenda] = options[:addenda]

        # Required  Check  Writer  Social  Security  Number  (  Numbers Only, No Dashes ) 
        post[:C_ssn] = options[:ssn].to_s.gsub(/[^\d]/, '')

        post[:C_dl_state_code] = options[:drivers_license_state]
        post[:C_dl_number]     = options[:drivers_license_number]
        post[:C_dob]           = format_birth_date(options[:date_of_birth])
      end

      def format_birth_date(date)
        date.respond_to?(:strftime) ? date.strftime('%m/%d/%Y') : date
      end

      # DDA for Checking
      # SAV for Savings 
      def account_type(check)
        case check.account_type
        when 'checking' then 'DDA'
        when 'savings'  then 'SAV'
        else raise ArgumentError, "Unknown account type #{check.account_type}"
        end
      end

      def parse(data, source)
        source == SOURCE_ECHECK ? parse_check(data) : parse_credit_card(data)
      end

      def parse_check(data)
        response = {}
        response[:success]          = data[1, 1]
        response[:code]             = data[2, 6].strip
        response[:message]          = data[8, 32].strip
        response[:risk]             = data[40, 2]
        response[:reference]        = data[42, 10]

        extra_data = data[53...-1].split("\034")
        response[:order_number] = extra_data[0]
        response[:authentication_indicator] = extra_data[1]
        response[:authentication_disclosure] = extra_data[2]
        response
      end

      def parse_credit_card(data)
        response = {}
        response[:success]          = data[1, 1]
        response[:code]             = data[2, 6]
        response[:message]          = data[8, 32].strip
        response[:front_end]        = data[40, 2]
        response[:cvv_result]       = data[42, 1]
        response[:avs_result]       = data[43, 1].strip
        response[:risk]             = data[44, 2]
        response[:reference]        = data[46, 10]

        response[:order_number], response[:recurring] = data[57...-1].split("\034")
        response
      end

      def add_invoice(post, options)
        post[:T_ordernum] = (options[:order_id] || generate_unique_id).slice(0, 20)
        post[:T_tax] = amount(options[:tax]) unless empty?(options[:tax])
        post[:T_shipping] = amount(options[:shipping]) unless empty?(options[:shipping])
      end

      def add_reference(post, reference)
        ref, = reference.to_s.split(';')
        post[:T_reference] = ref
      end

      def add_amount(post, money)
        post[:T_amt] = amount(money)
      end

      def add_customer_data(post, options)
        post[:T_customer_number] = options[:customer] if Float(options[:customer]) rescue nil
      end

      def add_addresses(post, options)
        billing_address = options[:billing_address] || options[:address] || {}

        post[:C_address]    = billing_address[:address1]
        post[:C_city]       = billing_address[:city]
        post[:C_state]      = empty?(billing_address[:state]) ? 'Outside of US' : billing_address[:state]
        post[:C_zip]        = billing_address[:zip]
        post[:C_country]    = billing_address[:country]
        post[:C_telephone]  = billing_address[:phone]
        post[:C_fax]        = billing_address[:fax]
        post[:C_email]      = options[:email]

        if shipping_address = options[:shipping_address]
          post[:C_ship_name]    = shipping_address[:name]
          post[:C_ship_address] = shipping_address[:address1]
          post[:C_ship_city]    = shipping_address[:city]
          post[:C_ship_state]   = shipping_address[:state]
          post[:C_ship_zip]     = shipping_address[:zip]
          post[:C_ship_country] = shipping_address[:country]
        end
      end

      def add_transaction_data(post, money, options)
        add_amount(post, money)
        add_invoice(post, options)
        add_addresses(post, options)
        add_customer_data(post, options)
      end

      def commit(action, params, source)
        url = url(params, source)
        response = parse(ssl_post(url, post_data(action, params)), source)

        Response.new(success?(response), response[:message], response,
          test: test?,
          authorization: authorization_from(response, source),
          avs_result: { code: response[:avs_result] },
          cvv_result: response[:cvv_result]
        )
      end

      def url(params, source)
        if source == SOURCE_ECHECK
          "#{live_url}/eftVirtualCheck.dll?transaction"
        else
          "#{live_url}/eftBankcard.dll?transaction"
        end
      end

      def authorization_from(response, source)
        "#{response[:reference]};#{source}"
      end

      def success?(response)
        response[:success] == 'A'
      end

      def post_data(action, params = {})
        params[:M_id]  = @options[:login]
        params[:M_key] = @options[:password]
        params[:T_code] = TRANSACTIONS[action]

        params.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join('&')
      end

      def vault
        @vault ||= SageVault.new(@options, self)
      end

      class SageVault
        def initialize(options, gateway)
          @live_url = 'https://www.sagepayments.net/web_services/wsVault/wsVault.asmx'
          @options = options
          @gateway = gateway
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
          year  = sprintf('%.4i', credit_card.year)
          month = sprintf('%.2i', credit_card.month)

          "#{month}#{year[-2..-1]}"
        end

        def commit(action, request)
          response = parse(
            @gateway.ssl_post(
              @live_url,
              build_soap_request(action, request),
              build_headers(action)
            )
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
          'xmlns:SOAP-ENV' => 'http://schemas.xmlsoap.org/soap/envelope/',
          'xmlns:ns1' => 'https://www.sagepayments.net/web_services/wsVault/wsVault'
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
            'SOAPAction' => SOAP_ACTIONS[action],
            'Content-Type' => 'text/xml; charset=utf-8'
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
          xml.elements.each('//Table1/*') do |node|
            response[node.name.underscore.to_sym] = node.text
          end

          # Unstore
          xml.elements.each('//DELETE_DATAResponse/*') do |node|
            response[node.name.underscore.to_sym] = node.text
          end
        end
      end
    end
  end
end
