require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # See https://helpdesk.worldnettps.com/support/solutions/articles/1000167298-integrator-guide
    class WorldNetGateway < Gateway
      self.test_url = 'https://testpayments.worldnettps.com/merchant/xmlpayment'
      self.live_url = 'https://payments.worldnettps.com/merchant/xmlpayment'

      self.homepage_url = 'http://worldnettps.com/'
      self.display_name = 'WorldNet'

      self.supported_countries = %w(IE GB US)
      self.default_currency = 'EUR'

      CARD_TYPES = {
        visa:             'VISA',
        master:           'MASTERCARD',
        discover:         'DISCOVER',
        american_express: 'AMEX',
        maestro:          'MAESTRO',
        diners_club:      'DINERS',
        jcb:              'JCB',
        secure_card:      'SECURECARD'
      }.freeze
      self.supported_cardtypes = CARD_TYPES.keys

      def initialize(options = {})
        requires!(options, :terminal_id, :secret)
        options[:terminal_type] ||= 2 # eCommerce
        super
      end

      def purchase(money, payment, options = {})
        requires!(options, :order_id)

        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('PAYMENT', post)
      end

      def authorize(money, payment, options = {})
        requires!(options, :order_id)

        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('PREAUTH', post)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_invoice(post, money, options)
        post[:uniqueref] = authorization

        commit('PREAUTHCOMPLETION', post)
      end

      def refund(money, authorization, options = {})
        requires!(options, :operator, :reason)

        post = {}
        post[:uniqueref] = authorization
        add_invoice(post, money, options)
        post[:operator] = options[:operator]
        post[:reason] = options[:reason]

        commit('REFUND', post)
      end

      def void(authorization, _options = {})
        post = {}
        post[:uniqueref] = authorization
        commit('VOID', post)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def store(payment, options = {})
        requires!(options, :order_id)

        post = {}
        post[:merchantref] = options[:order_id]
        add_payment(post, payment)

        commit('SECURECARDREGISTRATION', post)
      end

      def unstore(payment, options = {})
        requires!(options, :order_id)

        post = {}
        post[:merchantref] = options[:order_id]
        add_card_reference(post, payment)

        commit('SECURECARDREMOVAL', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r{(<CARDNUMBER>\d{6})\d+(\d{4}</CARDNUMBER>)}, '\1...\2').
          gsub(%r{(<CVV>)\d+(</CVV)}, '\1...\2')
      end

      private

      def add_customer_data(post, options)
        post[:email] = options[:email]
        post[:ipaddress] = options[:ip]
      end

      def add_address(post, _creditcard, options)
        address = options[:billing_address] || options[:address]
        return unless address

        post[:address1] = address[:address1]
        post[:address2] = address[:address2]
        post[:city]     = address[:city]
        post[:country]  = address[:country] # ISO 3166-1-alpha-2 code.
        post[:postcode] = address[:zip]
      end

      def add_invoice(post, money, options)
        post[:orderid] = options[:order_id]
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
        post[:description] = options[:description]
      end

      def add_payment(post, payment)
        # a payment triggered with a secure_card (tokenised card) will not
        # respond to `:number`
        if payment.respond_to?(:number)
          post[:cardholdername] = cardholdername(payment)
          post[:cardtype]       = CARD_TYPES[payment.brand.to_sym]
          post[:cardnumber]     = payment.number
          post[:cvv]            = payment.verification_value if payment.verification_value
          post[:cardexpiry]     = expdate(payment)
        else
          post[:cardtype]       = CARD_TYPES[:secure_card]
          post[:cardnumber]     = payment
        end
      end

      def add_card_reference(post, payment)
        post[:cardreference] = payment
      end

      def cardholdername(payment)
        [payment.first_name, payment.last_name].join(' ').slice(0, 60)
      end

      def parse(action, body)
        results = {}
        xml = Nokogiri::XML(body)
        resp = xml.xpath("//#{action}RESPONSE | //ERROR")
        resp.children.each do |element|
          results[element.name.downcase.to_sym] = element.text
        end
        results
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        response = parse(action, ssl_post(url, post_data(action, parameters)))

        Response.new(
          success_from(action, response),
          message_from(response),
          response,
          authorization: authorization_from(action, response),
          avs_result: AVSResult.new(code: response[:avs_response]),
          cvv_result: CVVResult.new(response[:cvv_response]),
          test: test?,
          error_code: success_from(action, response) ? nil : message_to_standard_error_code_from(response)
        )
      end

      def success_from(action, response)
        case action
        when 'SECURECARDREGISTRATION'
          response[:cardreference].present?
        when 'SECURECARDREMOVAL'
          response[:datetime].present? && response[:hash].present?
        else
          response[:responsecode] == 'A'
        end
      end

      def message_to_standard_error_code_from(response)
        case message_from(response)
        when /DECLINED/
          STANDARD_ERROR_CODE[:card_declined]
        when /CVV FAILURE/
          STANDARD_ERROR_CODE[:incorrect_cvc]
        when /Invalid CARDEXPIRY field/
          STANDARD_ERROR_CODE[:invalid_expiry_date]
        else
          STANDARD_ERROR_CODE[:processing_error]
        end
      end

      def message_from(response)
        response[:responsetext] || response[:errorstring]
      end

      def authorization_from(action, response)
        case action
        when 'SECURECARDREGISTRATION'
          response[:cardreference]
        else
          response[:uniqueref]
        end
      end

      def post_data(action, parameters = {})
        parameters[:terminalid]       = @options[:terminal_id]
        parameters[:terminaltype]     = @options[:terminal_type]
        parameters[:transactiontype]  = 7 # eCommerce
        parameters[:datetime]         = create_time_stamp
        parameters[:hash]             = case action
                                        when 'SECURECARDREGISTRATION'
                                          build_store_signature(parameters)
                                        when 'SECURECARDREMOVAL'
                                          build_unstore_signature(parameters)
                                        else
                                          build_signature(parameters)
                                        end
        build_xml_request(action, fields(action), parameters)
      end

      def create_time_stamp
        Time.now.gmtime.strftime('%d-%m-%Y:%H:%M:%S:%L')
      end

      def build_signature(parameters)
        str = parameters[:terminalid]
        str += (parameters[:uniqueref] || parameters[:orderid])
        str += (parameters[:amount].to_s + parameters[:datetime])
        Digest::MD5.hexdigest(str + @options[:secret])
      end

      def build_store_signature(parameters)
        str = parameters[:terminalid]
        str += parameters[:merchantref]
        str += parameters[:datetime]
        str += parameters[:cardnumber]
        str += parameters[:cardexpiry]
        str += parameters[:cardtype]
        str += parameters[:cardholdername]
        Digest::MD5.hexdigest(str + @options[:secret])
      end

      def build_unstore_signature(parameters)
        str = parameters[:terminalid]
        str += parameters[:merchantref]
        str += parameters[:datetime]
        str += parameters[:cardreference]
        Digest::MD5.hexdigest(str + @options[:secret])
      end

      def fields(action)
        # Gateway expects fields in fixed order below.
        case action
        when 'PAYMENT', 'PREAUTH'
          %i[
            orderid
            terminalid
            amount
            datetime
            cardnumber cardtype cardexpiry cardholdername
            hash
            currency
            terminaltype
            transactiontype
            email
            cvv
            address1 address2
            postcode
            description
            city country
            ipaddress
          ]
        when 'PREAUTHCOMPLETION'
          %i[uniqueref terminalid amount datetime hash]
        when 'REFUND'
          %i[uniqueref terminalid amount datetime hash
             operator reason]
        when 'VOID'
          [:uniqueref]
        when 'SECURECARDREGISTRATION'
          %i[
            merchantref
            terminalid
            datetime
            cardnumber cardexpiry cardtype cardholdername
            hash
            dontchecksecurity
            cvv
            issueno
          ]
        when 'SECURECARDREMOVAL'
          %i[
            merchantref
            cardreference
            terminalid
            datetime
            hash
          ]
        end
      end

      def build_xml_request(action, fields, data)
        xml = Builder::XmlMarkup.new indent: 2
        xml.instruct!(:xml, version: '1.0', encoding: 'utf-8')
        xml.tag!(action) do
          fields.each do |field|
            xml.tag!(field.to_s.upcase, data[field]) if data[field]
          end
        end
        xml.target!
      end

      def expdate(credit_card)
        sprintf('%02d%02d', credit_card.month, credit_card.year % 100)
      end
    end
  end
end
