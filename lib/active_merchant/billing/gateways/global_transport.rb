require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GlobalTransportGateway < Gateway
      self.test_url = 'https://certapia.globalpay.com/GlobalPay/transact.asmx/ProcessCreditCard'
      self.live_url = 'https://api.globalpay.com/GlobalPay/transact.asmx/ProcessCreditCard'

      self.supported_countries = %w(CA PR US)
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover diners_club jcb]

      self.homepage_url = 'https://www.globalpaymentsinc.com'
      self.display_name = 'Global Transport'

      # Public: Create a new Global Transport gateway.
      #
      # options - A hash of options:
      #           :global_user_name - Your Global user name
      #           :global_password  - Your Global password
      #           :term_type        - 3 character field assigned by Global Transport after
      #                             - your application is certified.
      def initialize(options={})
        requires!(options, :global_user_name, :global_password, :term_type)
        super
      end

      def purchase(money, payment_method, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment_method(post, payment_method)
        add_address(post, options)

        commit('Sale', post, options)
      end

      def authorize(money, payment_method, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment_method(post, payment_method)
        add_address(post, options)

        commit('Auth', post, options)
      end

      def capture(money, authorization, options={})
        post = {}
        add_invoice(post, money, options)
        add_auth(post, authorization)

        commit('Force', post, options)
      end

      def refund(money, authorization, options={})
        post = {}
        add_invoice(post, money, options)
        add_auth(post, authorization)

        commit('Return', post, options)
      end

      def void(authorization, options={})
        post = {}
        add_auth(post, authorization)

        commit('Void', post, options)
      end

      def verify(payment_method, options={})
        post = {}
        add_payment_method(post, payment_method)
        add_address(post, options)

        commit('CardVerify', post, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((&?CardNum=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?CVNum=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?GlobalPassword=)[^&]*)i, '\1[FILTERED]')
      end

      private

      def add_address(post, options)
        if address = (options[:billing_address] || options[:address])
          post[:Street] = address[:address1]
          post[:Zip] = address[:zip]
        end
      end

      def add_auth(post, authorization)
        post[:PNRef] = authorization
      end

      def add_invoice(post, money, options)
        currency = (options[:currency] || currency(money))

        post[:Amount] = localized_amount(money, currency)
        post[:InvNum] = truncate(options[:order_id], 16)
      end

      def add_payment_method(post, payment_method)
        post[:CardNum] = payment_method.number
        post[:ExpDate] = expdate(payment_method)
        post[:NameOnCard] = payment_method.name
        post[:CVNum] = payment_method.verification_value
      end

      def parse(body)
        response = {}

        Nokogiri::XML(body).root.xpath('*').each do |node|
          response[node.name.downcase.to_sym] = node.text
        end

        ext_data = Nokogiri::HTML.parse(response[:extdata])
        response[:approved_amount] = ext_data.xpath('//approvedamount').text
        response[:balance_due] = ext_data.xpath('//balancedue').text

        response
      end

      def commit(action, parameters, options)
        raw = parse(ssl_post(url, post_data(action, parameters, options)))
        Response.new(
          success_from(raw),
          message_from(raw),
          raw,
          authorization: authorization_from(raw),
          test: test?,
          avs_result: avs_from(raw),
          cvv_result: cvv_from(raw)
        )
      end

      def post_data(action, params, options)
        post = default_params
        post[:GlobalUserName] = @options[:global_user_name]
        post[:GlobalPassword] = @options[:global_password]
        post[:TransType] = action
        post[:ExtData] = "<TermType>#{@options[:term_type]}</TermType>"

        post.merge(params).map { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join('&')
      end

      def url
        (test? ? test_url : live_url)
      end

      def success_from(response)
        response[:result] == '0' || response[:result] == '200'
      end

      def message_from(response)
        response[:respmsg]
      end

      def authorization_from(response)
        response[:pnref]
      end

      def avs_from(response)
        { code: response[:getavsresult] }
      end

      def cvv_from(response)
        response[:getcvresult]
      end

      def default_params
        {
          CardNum: '',
          ExpDate: '',
          NameOnCard: '',
          Amount: '',
          PNRef: '',
          Zip: '',
          Street: '',
          CVNum: '',
          MagData: '',
          InvNum: '',
          ExtData: ''
        }
      end
    end
  end
end
