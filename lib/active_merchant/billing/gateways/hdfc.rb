require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class HdfcGateway < Gateway
      self.display_name = 'HDFC'
      self.homepage_url = 'http://www.hdfcbank.com/sme/sme-details/merchant-services/guzh6m0i'

      self.test_url = 'https://securepgtest.fssnet.co.in/pgway/servlet/'
      self.live_url = 'https://securepg.fssnet.co.in/pgway/servlet/'

      self.supported_countries = ['IN']
      self.default_currency = 'INR'
      self.money_format = :dollars
      self.supported_cardtypes = %i[visa master discover diners_club]

      def initialize(options={})
        requires!(options, :login, :password)
        super
      end

      def purchase(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit('purchase', post)
      end

      def authorize(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit('authorize', post)
      end

      def capture(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)

        commit('capture', post)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)

        commit('refund', post)
      end

      private

      CURRENCY_CODES = Hash.new { |h, k| raise ArgumentError.new("Unsupported currency for HDFC: #{k}") }
      CURRENCY_CODES['AED'] = '784'
      CURRENCY_CODES['AUD'] = '036'
      CURRENCY_CODES['CAD'] = '124'
      CURRENCY_CODES['EUR'] = '978'
      CURRENCY_CODES['GBP'] = '826'
      CURRENCY_CODES['INR'] = '356'
      CURRENCY_CODES['OMR'] = '512'
      CURRENCY_CODES['QAR'] = '634'
      CURRENCY_CODES['SGD'] = '702'
      CURRENCY_CODES['USD'] = '840'

      def add_invoice(post, amount, options)
        post[:amt] = amount(amount)
        post[:currencycode] = CURRENCY_CODES[options[:currency] || currency(amount)]
        post[:trackid] = escape(options[:order_id], 40) if options[:order_id]
        post[:udf1] = escape(options[:description]) if options[:description]
        post[:eci] = options[:eci] if options[:eci]
      end

      def add_customer_data(post, options)
        post[:udf2] = escape(options[:email]) if options[:email]
        if address = (options[:billing_address] || options[:address])
          post[:udf3] = escape(address[:phone]) if address[:phone]
          post[:udf4] = escape(<<~EOA)
            #{address[:name]}
            #{address[:company]}
            #{address[:address1]}
            #{address[:address2]}
            #{address[:city]} #{address[:state]} #{address[:zip]}
            #{address[:country]}
          EOA
        end
      end

      def add_payment_method(post, payment_method)
        post[:member] = escape(payment_method.name, 30)
        post[:card] = escape(payment_method.number)
        post[:cvv2] = escape(payment_method.verification_value)
        post[:expyear] = format(payment_method.year, :four_digits)
        post[:expmonth] = format(payment_method.month, :two_digits)
      end

      def add_reference(post, authorization)
        tranid, member = split_authorization(authorization)
        post[:transid] = tranid
        post[:member] = member
      end

      def parse(xml)
        response = {}

        doc = Nokogiri::XML.fragment(fix_xml(xml))
        doc.children.each do |node|
          if node.text?
            next
          elsif node.elements.size == 0
            response[node.name.downcase.to_sym] = node.text
          else
            node.elements.each do |childnode|
              name = "#{node.name.downcase}_#{childnode.name.downcase}"
              response[name.to_sym] = childnode.text
            end
          end
        end

        response
      end

      def fix_xml(xml)
        xml.gsub(/&(?!(?:amp|quot|apos|lt|gt);)/, '&amp;')
      end

      ACTIONS = {
        'purchase' => '1',
        'refund' => '2',
        'authorize' => '4',
        'capture' => '5'
      }

      def commit(action, post)
        post[:id] = @options[:login]
        post[:password] = @options[:password]
        post[:action] = ACTIONS[action] if ACTIONS[action]

        raw = parse(ssl_post(url(action), build_request(post)))

        succeeded = success_from(raw[:result])
        Response.new(
          succeeded,
          message_from(succeeded, raw),
          raw,
          authorization: authorization_from(post, raw),
          test: test?
        )
      end

      def build_request(post)
        xml = Builder::XmlMarkup.new indent: 2
        xml.instruct!
        post.each do |field, value|
          xml.tag!(field, value)
        end
        xml.target!
      end

      def url(action)
        endpoint = 'TranPortalXMLServlet'
        (test? ? test_url : live_url) + endpoint
      end

      def success_from(result)
        case result
        when 'CAPTURED', 'APPROVED', 'NOT ENROLLED', 'ENROLLED'
          true
        else
          false
        end
      end

      def message_from(succeeded, response)
        if succeeded
          'Succeeded'
        else
          (response[:error_text] || response[:result] || 'Unable to read error message').split('-').last
        end
      end

      def authorization_from(request, response)
        [response[:tranid], request[:member]].join('|')
      end

      def split_authorization(authorization)
        tranid, member = authorization.split('|')
        [tranid, member]
      end

      def escape(string, max_length=250)
        return '' unless string

        string = string[0...max_length] if max_length
        string.gsub(/[^A-Za-z0-9 \-_@\.\n]/, '')
      end
    end
  end
end
