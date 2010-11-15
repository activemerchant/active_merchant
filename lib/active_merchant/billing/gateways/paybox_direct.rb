require 'iconv'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayboxDirectGateway < Gateway
      TEST_URL = 'https://ppps.paybox.com/PPPS.php'
      TEST_URL_BACKUP = 'https://ppps1.paybox.com/PPPS.php'
      LIVE_URL = 'https://ppps.paybox.com/PPPS.php'
      LIVE_URL_BACKUP = 'https://ppps1.paybox.com/PPPS.php'

      # Payment API Version
      API_VERSION = '00104'

      # Transactions hash
      TRANSACTIONS = {
        :authorization => '00001',
        :capture => '00002',
        :purchase => '00003',
        :unreferenced_credit => '00004',
        :void => '00005',
        :refund => '00014'
      }

      CURRENCY_CODES = {
        "AUD"=> '036',
        "CAD"=> '124',
        "CZK"=> '203',
        "DKK"=> '208',
        "HKD"=> '344',
        "ICK"=> '352',
        "JPY"=> '392',
        "NOK"=> '578',
        "SGD"=> '702',
        "SEK"=> '752',
        "CHF"=> '756',
        "GBP"=> '826',
        "USD"=> '840',
        "EUR"=> '978'
      }

      SUCCESS_CODES = ['00000']
      UNAVAILABILITY_CODES = ['00001', '00097', '00098']
      FRAUD_CODES = ['00102','00104','00105','00134','00138','00141','00143','00156','00157','00159']
      SUCCESS_MESSAGE = 'The transaction was approved'
      FAILURE_MESSAGE = 'The transaction failed'

      # Money is referenced in cents
      self.money_format = :cents
      self.default_currency = 'EUR'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['FR']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :jcb]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.paybox.com/'

      # The name of the gateway
      self.display_name = 'Paybox Direct'

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        commit('authorization', money, post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        commit('purchase', money, post)
      end

      def capture(money, authorization, options = {})
        requires!(options, :order_id)
        post = {}
        add_invoice(post, options)
        post[:numappel] = authorization[0,10]
        post[:numtrans] = authorization[10,10]
        commit('capture', money, post)
      end

      def void(identification, options = {})
        requires!(options, :order_id, :amount)
        post ={}
        add_invoice(post, options)
        add_reference(post, identification)
        post[:porteur] = '000000000000000'
        post[:dateval] = '0000'
        commit('void', options[:amount], post)
      end

      def credit(money, identification, options = {})
        post = {}
        add_invoice(post, options)
        add_reference(post, identification)
        commit('refund', money, post)
      end

      def test?
        @options[:test] || Base.gateway_mode == :test
      end

      private

      def add_invoice(post, options)
        post[:reference] = options[:order_id]
      end

      def add_creditcard(post, creditcard)
        post[:porteur] = creditcard.number
        post[:dateval] = expdate(creditcard)
        post[:cvv] = creditcard.verification_value if creditcard.verification_value?
      end

      def add_reference(post, identification)
        post[:numappel] = identification[0,10]
        post[:numtrans] = identification[10,10]
      end

      def parse(body)
        body = Iconv.iconv("UTF-8","LATIN1", body.to_s).join
        results = {}
        body.split(/&/).each do |pair|
          key,val = pair.split(/\=/)
          results[key.downcase.to_sym] = CGI.unescape(val) if val
        end
        results
      end

      def commit(action, money = nil, parameters = nil)
        parameters[:montant] = ('0000000000' + (money ? amount(money) : ''))[-10..-1]
        parameters[:devise] = CURRENCY_CODES[options[:currency] || currency(money)]
        request_data = post_data(action,parameters)
        response = parse(ssl_post(test? ? TEST_URL : LIVE_URL, request_data))
        response = parse(ssl_post(test? ? TEST_URL_BACKUP : LIVE_URL_BACKUP, request_data)) if service_unavailable?(response)
        Response.new(success?(response), message_from(response), response.merge(
          :timestamp => parameters[:dateq]),
          :test => test?,
          :authorization => response[:numappel].to_s + response[:numtrans].to_s,
          :fraud_review => fraud_review?(response),
          :sent_params => parameters.delete_if{|key,value| ['porteur','dateval','cvv'].include?(key.to_s)}
        )
      end

      def success?(response)
        SUCCESS_CODES.include?(response[:codereponse])
      end

      def fraud_review?(response)
        FRAUD_CODES.include?(response[:codereponse])
      end

      def service_unavailable?(response)
        UNAVAILABILITY_CODES.include?(response[:codereponse])
      end

      def message_from(response)
        success?(response) ? SUCCESS_MESSAGE : (response[:commentaire]  || FAILURE_MESSAGE)
      end

      def post_data(action, parameters = {})

        parameters.update(
          :version => API_VERSION,
          :type => TRANSACTIONS[action.to_sym],
          :dateq => Time.now.strftime('%d%m%Y%H%M%S'),
          :numquestion => unique_id(parameters[:order_id]),
          :site => @options[:login].to_s[0,7],
          :rang => @options[:login].to_s[7..-1],
          :cle => @options[:password],
          :pays => '',
          :archivage => parameters[:order_id]
        )

        parameters.collect { |key, value| "#{key.to_s.upcase}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def unique_id(seed = 0)
        randkey = "#{seed}#{Time.now.usec}".to_i % 2147483647 # Max paybox value for the question number

        "0000000000#{randkey}"[-10..-1]
      end

      def expdate(credit_card)
        year  = sprintf("%.4i", credit_card.year)
        month = sprintf("%.2i", credit_card.month)

        "#{month}#{year[-2..-1]}"
      end

    end
  end
end
