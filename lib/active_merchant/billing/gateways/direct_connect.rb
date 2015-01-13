require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class DirectConnectGateway < Gateway
      self.test_url = 'https://gateway.1directconnect.com/'
      self.live_url = 'https://gateway.1directconnect.com/'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.directconnectps.com/'
      self.display_name = 'Direct Connect'

      DIRECT_CONNECT_CODES = {
        0 => :success,
        23 => :invalidAccountNumber,
        1015 => :noRecordsToProcess
      }

      def initialize(options={})
        requires!(options, :username, :password)
        @username = options[:username]
        @password = options[:password]
        super
      end

      def purchase(money, payment, options={})
        post = {}
        
        add_required_nil_values(post)
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_authentication(post, options)

        post[:transtype] = 'sale'
        post[:magdata] = options[:track_data]
        
        commit(:saleCreditCard, post)
      end

      def authorize(money, payment, options={})
        post = {}

        add_required_nil_values(post)
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_authentication(post, options)

        post[:transtype] = 'Auth'
        post[:magdata] = options[:track_data]

        commit(:authCreditCard, post)
      end

      # could not implement remote tests for capture due to it not being enabled on our gateway
      def capture(money, authorization, options={})
        post = {}

        add_required_nil_values(post)
        add_invoice(post, money, options)
        add_customer_data(post, options)
        add_authentication(post, options)

        post[:transtype] = 'Capture'
        post[:pnref] =  authorization

        commit(:saleCreditCard, post)
      end

      def refund(money, payment, authorization, options={})
        post = {}
        
        add_required_nil_values(post)
        add_invoice(post, money, options)
        add_authentication(post, options)
        
        post[:transtype] = 'Return'
        post[:pnref] =  authorization

        commit(:returnCreditCard, post)
      end

      def void(authorization, options={})
        commit('void', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
          .gsub(%r((username=)\w+), '\1[FILTERED]')
          .gsub(%r((password=)\w+), '\1[FILTERED]')
          .gsub(%r((cardnum=)\d+), '\1[FILTERED]')
          .gsub(%r((cvnum=)\d+), '\1[FILTERED]')
      end

      private

      def add_authentication(post, options)
        post[:username] = @username
        post[:password] = @password
      end

      def add_customer_data(post, options)

      end

      def add_required_nil_values(post)
          post[:amount] = nil
          post[:invNum] = nil
          post[:cardnum] = nil
          post[:expdate] = nil
          post[:cvnum] = nil
          post[:nameoncard] = nil
          post[:street] = nil
          post[:zip] = nil
          post[:extdata] = nil
          post[:magdata] = nil
          post[:pnref] =  nil
      end

      def add_address(post, creditcard, options)
        if address = options[:billing_address] || options[:address]
          post[:nameoncard] = address[:name]
          post[:street] = address[:address1]
          post[:zip] = address[:zip]
        end
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:invNum] = options[:order_id]
      end

      def add_payment(post, payment)
        exp_date = payment.expiry_date.expiration.strftime('%02m%02y')

        post[:cardnum] = payment.number
        post[:expdate] = exp_date
        post[:cvnum] = payment.verification_value
      end

      def parse(action, body)
        doc = Nokogiri::XML(body)
        doc.remove_namespaces!
        response = {action: action}

        # special parsing
        response[:result] = doc.at_xpath("//Response/Result").content.to_i

        if el = doc.at_xpath("//Response/PNRef")
          response[:pnref] = el.content.to_i
        end

        # parse everything else
        doc.at_xpath('//Response').element_children.each do |node|
          node_sym = node.name.downcase.to_sym
          response[node_sym] ||= normalize(node.content)
        end

        response
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        service = actionToService(action)
        url = "#{url}#{serviceUrl(service)}"
        begin
          data = post_data(action, parameters)
          response = parse(action, ssl_post(url, data))
        rescue ResponseError => e
          puts e.response.body
        end

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def success_from(response)
        DIRECT_CONNECT_CODES[response[:result]] == :success
      end

      def message_from(response)
        response[:respmsg]
      end

      def authorization_from(response)
        response[:pnref]
      end

      def post_data(action, parameters = {})
        return nil unless parameters

        parameters.map do |k, v|
          "#{k}=#{CGI.escape(v.to_s)}"
        end.compact.join('&')
      end

      def actionToService(action)
        case action
        when :authCreditCard, :saleCreditCard, :returnCreditCard, :voidCreditCard
          :processCreditCard
        when :saleCheck, :authCheck, :returnCheck, :voidCheck
          :processCheck
        else
          action
        end
      end

      def serviceUrl(service)
        case service
        when :processCreditCard
          "ws/transact.asmx/ProcessCreditCard"
        when :processCheck
          "ws/transact.asmx/ProcessCheck"
        when :storeCardSafeCard
          "ws/cardsafe.asmx/StoreCard"
        when :processCardRecurring
          "ws/recurring.asmx/ProcessCreditCard"
        end
      end
    end
  end
end
