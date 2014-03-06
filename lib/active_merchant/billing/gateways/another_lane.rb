module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AnotherLaneGateway < Gateway

      self.test_url = 'https://credit.alij.ne.jp/service/gateway/'
      self.live_url = 'https://credit.alij.ne.jp/service/gateway/'

      self.supported_countries = ['JP']
      self.default_currency = 'JPY' # currency is hard binded to merchant code.
      self.supported_cardtypes = [:visa, :master, :american_express, :jcb]

      self.homepage_url = 'http://www.alij.ne.jp/'
      self.display_name = 'Another Lane'

      def initialize(options={})
        requires!(options, :site_id, :site_password)
        super
      end

      #
      # Purchase or quick purchase.
      # - set nil for credit_card for quick purchase but requires `customerId` option
      #
      def purchase(money, credit_card, options={})
        post = {}
        add_credential(post)
        add_invoice(post, money, options)
        add_cc(post, credit_card, options)
        add_address(post, options)
        add_customer_data(post, options)
        add_item(post, options)
        add_misc(post, options)
        add_customer_mail(post, options)

        commit(:sale, post)
      end

      #
      # Change customer's credit card information according to existing customer_id
      #
      def store(credit_card, options = {})

        requires!(options, :customer_id)
        requires!(options, :customer_password)

        post = {}
        add_credential(post)
        add_customer_data(post, options)
        add_cc(post, credit_card, options)

        commit(:cust_change, post)

      end


      #
      # Change customer's mail address information according to existing customer_id
      #
      def store_mail(credit_card, options = {})

        requires!(options, :customer_id)
        requires!(options, :customer_password)

        post = {}
        add_credential(post)
        add_customer_data(post, options)
        add_customer_mail(post, options)

        commit(:cust_change_mail, post)

      end


      #
      # Get payment status
      #
      def get_status(transaction_id = nil, site_transaction_id = nil)

        unless transaction_id || site_transaction_id
          raise "transactioon_id or site_transaction_id is required."
        end

        post = {}
        add_credential(post)
        add_transaction_id(post, transaction_id, site_transaction_id)

        commit(:get_status, post)

      end



      #
      # void the purchase
      #
      def void(transaction_id)

        post = {}
        add_credential(post)
        add_transaction_id(post, transaction_id)

        commit(:void, post)
      end


      def authorize(money, credit_card, options={})
        raise NotImplementedError, "Authorization operation is not provided by the gateway"
      end

      def capture(money, authorization, options={})
        raise NotImplementedError, "Capture operation is not provided by the gateway"
      end

      def refund(money, authorization, options={})
        raise NotImplementedError, "Refund operation is not provided by the gateway"
      end



      private

      def add_credential(post)
        post[:SiteId] = options[:site_id]
        post[:SitePass] = options[:site_password]
      end


      def add_transaction_id(post, transaction_id = nil, site_transaction_id = nil)
        post[:TransactionId]     = transaction_id      if transaction_id
        post[:SiteTransactionId] = site_transaction_id if site_transaction_id
      end

      def add_customer_data(post, options)
        post[:CustomerId] = options[:customer_id]         if options[:customer_id]
        post[:CustomerPass] = options[:customer_password] if options[:customer_password]
      end


      def add_customer_mail(post, options)
        post[:Mail] = options[:mail] if options[:mail]
      end

      def add_item(post, options)
        post[:itemId] = options[:item_id]
      end

      #
      # Add credit card information
      #
      def add_cc(post, credit_card, options)
        if credit_card.nil?
          return
        end
        post[:cardName] = credit_card.name
        post[:cardNo] = credit_card.number
        post[:cardMonth] = credit_card.month
        post[:cardYear] = credit_card.year
        post[:cvv2] = credit_card.verification_value
      end

      #
      # Add address information
      #
      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:zip] = address[:zip]
          post[:capital] = address[:state]
          post[:adr1]    = address[:city] + address[:address1]
          post[:adr2]    = address[:address2]
          post[:name]    = address[:name]
          post[:tel]     = address[:phone].gsub(/[^0-9]+/, '') if address[:phone]
          post[:country] = address[:country]
#          post[:company] = address[:company]
        end
      end

      def add_invoice(post, money, options)
        post[:Amount] = (money) # in the test mode, use only 210 JPY
      end

      def add_misc(post, options)
        post[:note]          = options[:note] if options[:note]
        post[:TransactionId] = options[:TransactionId] if options[:TransactionId]
        post[:ipaddr]        = options[:ipaddr] if options[:ipaddr]
        post[:country]       = options[:country] if options[:country]
      end


      #
      # Create response has from string
      #
      def parse(body)

        # state=1&TransactionId=1403068209641&msg=THROUGH TEST OK (TEST CARD)
        if 0 < body.count("\n")
          { 'msg' => body }
        else
          result = {}
          body.split('&').each do |item|
            items = item.partition('=')
            result[items[0]] = items[2]
          end
          result
        end
      end

      def commit(action, parameters)

        end_point = (test? ? self.test_url : self.live_url).dup
        case action
        when :sale
          url = end_point  + 'credit.htm'
        when :cust_change
          url = end_point  + 'cust_change.htm'
        when :cust_change_mail
          url = end_point  + 'cust_change_mail.htm'
        when :get_status
          url = end_point  + 'get_status.htm'
        when :void
          url = end_point  + 'void.htm'
        else
          raise "Specify action type."
        end

        url += post_data(parameters)

        response = parse(ssl_get(url))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: transaction_id_from(response),
          test: test?
        )
      end

      #
      # judge the response code success = 1, falure = 2
      #
      def success_from(response)
        if response['state'] == '1'
          true
        else
          false
        end
      end

      #
      # Retrive message from response hash
      #
      def message_from(response)
        response['msg']
      end

      def transaction_id_from(response)
        response['TransactionId'] if response['TransactionId']
      end

      #
      # Create get parameters from hash data
      #
      def post_data(parameters = {})

        get_parameter = ''
        if parameters
          get_parameter << '?'
          get_parameter << encode(parameters)
        end
        get_parameter

      end

      def encode(hash)
        hash.collect{|(k,v)| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"}.join('&')
      end

    end
  end
end
