require 'rexml/document'
require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class QuickpayGateway < Gateway
      URL = 'https://secure.quickpay.dk/api'

      self.default_currency = 'DKK'
      self.money_format = :cents
      self.supported_cardtypes = [:dankort, :forbrugsforeningen, :visa, :master, :american_express, :diners_club, :jcb, :maestro]
      self.supported_countries = ['DK', 'SE']
      self.homepage_url = 'http://quickpay.dk/'
      self.display_name = 'Quickpay'

      MD5_CHECK_FIELDS = {
        3 => {
          :authorize => %w(protocol msgtype merchant ordernumber amount
                           currency autocapture cardnumber expirationdate
                           cvd cardtypelock testmode),

          :capture   => %w(protocol msgtype merchant amount transaction),

          :cancel    => %w(protocol msgtype merchant transaction),

          :refund    => %w(protocol msgtype merchant amount transaction),

          :subscribe => %w(protocol msgtype merchant ordernumber cardnumber
                           expirationdate cvd cardtypelock description testmode),

          :recurring => %w(protocol msgtype merchant ordernumber amount
                           currency autocapture transaction),

          :status    => %w(protocol msgtype merchant transaction),

          :chstatus  => %w(protocol msgtype merchant)
        },

        4 => {
          :authorize => %w(protocol msgtype merchant ordernumber amount
                           currency autocapture cardnumber expirationdate cvd
                           cardtypelock testmode fraud_remote_addr
                           fraud_http_accept fraud_http_accept_language
                           fraud_http_accept_encoding fraud_http_accept_charset
                           fraud_http_referer fraud_http_user_agent apikey),

          :capture   => %w(protocol msgtype merchant amount transaction
                           fraud_remote_addr fraud_http_accept
                           fraud_http_accept_language fraud_http_accept_encoding
                           fraud_http_accept_charset fraud_http_referer
                           fraud_http_user_agent apikey),

          :cancel    => %w(protocol msgtype merchant transaction fraud_remote_addr
                           fraud_http_accept fraud_http_accept_language
                           fraud_http_accept_encoding fraud_http_accept_charset
                           fraud_http_referer fraud_http_user_agent apikey),

          :refund    => %w(protocol msgtype merchant amount transaction
                           fraud_remote_addr fraud_http_accept fraud_http_accept_language
                           fraud_http_accept_encoding fraud_http_accept_charset
                           fraud_http_referer fraud_http_user_agent apikey),

          :subscribe => %w(protocol msgtype merchant ordernumber cardnumber
                           expirationdate cvd cardtypelock description testmode
                           fraud_remote_addr fraud_http_accept fraud_http_accept_language
                           fraud_http_accept_encoding fraud_http_accept_charset
                           fraud_http_referer fraud_http_user_agent apikey),

          :recurring => %w(protocol msgtype merchant ordernumber amount currency
                           autocapture transaction fraud_remote_addr fraud_http_accept
                           fraud_http_accept_language fraud_http_accept_encoding
                           fraud_http_accept_charset fraud_http_referer
                           fraud_http_user_agent apikey),

          :status    => %w(protocol msgtype merchant transaction fraud_remote_addr
                           fraud_http_accept fraud_http_accept_language
                           fraud_http_accept_encoding fraud_http_accept_charset
                           fraud_http_referer fraud_http_user_agent apikey),

          :chstatus  => %w(protocol msgtype merchant fraud_remote_addr fraud_http_accept
                           fraud_http_accept_language fraud_http_accept_encoding
                           fraud_http_accept_charset fraud_http_referer
                           fraud_http_user_agent apikey)
        }
      }

      APPROVED = '000'

      # The login is the QuickpayId
      # The password is the md5checkword from the Quickpay manager
      # To use the API-key from the Quickpay manager, specify :api-key
      # Using the API-key, requires that you use version 4. Specify :version => 4 in options.
      def initialize(options = {})
        requires!(options, :login, :password)
        @protocol = options.delete(:version) || 3 # default to protocol version 3
        @options = options
        super
      end

      def authorize(money, credit_card_or_reference, options = {})
        post = {}

        add_amount(post, money, options)
        add_invoice(post, options)
        add_creditcard_or_reference(post, credit_card_or_reference, options)
        add_autocapture(post, false)
        add_fraud_parameters(post, options)
        add_testmode(post)

        commit(recurring_or_authorize(credit_card_or_reference), post)
      end

      def purchase(money, credit_card_or_reference, options = {})
        post = {}

        add_amount(post, money, options)
        add_creditcard_or_reference(post, credit_card_or_reference, options)
        add_invoice(post, options)
        add_fraud_parameters(post, options)
        add_autocapture(post, true)

        commit(recurring_or_authorize(credit_card_or_reference), post)
      end

      def capture(money, authorization, options = {})
        post = {}

        add_reference(post, authorization)
        add_amount_without_currency(post, money)
        add_fraud_parameters(post, options)

        commit(:capture, post)
      end

      def void(identification, options = {})
        post = {}

        add_reference(post, identification)
        add_fraud_parameters(post, options)

        commit(:cancel, post)
      end

      def refund(money, identification, options = {})
        post = {}

        add_amount_without_currency(post, money)
        add_reference(post, identification)
        add_fraud_parameters(post, options)

        commit(:refund, post)
      end

      def credit(money, identification, options = {})
        deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, identification, options)
      end

      def store(creditcard, options = {})
        post = {}

        add_creditcard(post, creditcard, options)
        add_invoice(post, options)
        add_description(post, options)
        add_fraud_parameters(post, options)
        add_testmode(post)

        commit(:subscribe, post)
      end

      private

      def add_amount(post, money, options = {})
        post[:amount]   = amount(money)
        post[:currency] = options[:currency] || currency(money)
      end

      def add_amount_without_currency(post, money, options = {})
        post[:amount] = amount(money)
      end

      def add_invoice(post, options)
        post[:ordernumber] = format_order_number(options[:order_id])
      end

      def add_creditcard(post, credit_card, options)
        post[:cardnumber]     = credit_card.number
        post[:cvd]            = credit_card.verification_value
        post[:expirationdate] = expdate(credit_card)
        post[:cardtypelock]   = options[:cardtypelock] unless options[:cardtypelock].blank?
      end

      def add_reference(post, identification)
        post[:transaction] = identification
      end

      def add_creditcard_or_reference(post, credit_card_or_reference, options)
        if credit_card_or_reference.is_a?(String)
          add_reference(post, credit_card_or_reference)
        else
          add_creditcard(post, credit_card_or_reference, options)
        end
      end

      def add_autocapture(post, autocapture)
        post[:autocapture] = autocapture ? 1 : 0
      end

      def recurring_or_authorize(credit_card_or_reference)
        credit_card_or_reference.is_a?(String) ? :recurring : :authorize
      end

      def add_description(post, options)
        post[:description] = options[:description]
      end

      def add_testmode(post)
        post[:testmode] = test? ? '1' : '0'
      end
      
      def add_fraud_parameters(post, options)
        if @protocol == 4
          post[:fraud_remote_addr] = options[:fraud_remote_addr] if options[:fraud_remote_addr]
          post[:fraud_http_accept] = options[:fraud_http_accept] if options[:fraud_http_accept]
          post[:fraud_http_accept_language] = options[:fraud_http_accept_language] if options[:fraud_http_accept_language]
          post[:fraud_http_accept_encoding] = options[:fraud_http_accept_encoding] if options[:fraud_http_accept_encoding]
          post[:fraud_http_accept_charset] = options[:fraud_http_accept_charset] if options[:fraud_http_accept_charset]
          post[:fraud_http_referer] = options[:fraud_http_referer] if options[:fraud_http_referer]
          post[:fraud_http_user_agent] = options[:fraud_http_user_agent] if options[:fraud_http_user_agent]
        end
      end

      def commit(action, params)
        response = parse(ssl_post(URL, post_data(action, params)))

        Response.new(successful?(response), message_from(response), response,
          :test => test?,
          :authorization => response[:transaction]
        )
      end

      def successful?(response)
        response[:qpstat] == APPROVED
      end

      def parse(data)
        response = {}

        doc = REXML::Document.new(data)

        doc.root.elements.each do |element|
          response[element.name.to_sym] = element.text
        end

        response
      end

      def message_from(response)
        response[:qpstatmsg].to_s
      end

      def post_data(action, params = {})
        params[:protocol] = @protocol
        params[:msgtype]  = action.to_s
        params[:merchant] = @options[:login]
        params[:apikey] = @options[:apikey] if @options[:apikey]
        params[:md5check] = generate_check_hash(action, params)

        params.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def generate_check_hash(action, params)
        string = MD5_CHECK_FIELDS[@protocol][action].collect do |key|
          params[key.to_sym]
        end.join('')

        # Add the md5checkword
        string << @options[:password].to_s

        Digest::MD5.hexdigest(string)
      end

      def expdate(credit_card)
        year  = format(credit_card.year, :two_digits)
        month = format(credit_card.month, :two_digits)

        "#{year}#{month}"
      end

      # Limited to 20 digits max
      def format_order_number(number)
        number.to_s.gsub(/[^\w_]/, '').rjust(4, "0")[0...20]
      end
    end
  end
end

