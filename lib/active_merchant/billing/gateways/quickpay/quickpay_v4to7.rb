require 'rexml/document'
require 'digest/md5'
require 'active_merchant/billing/gateways/quickpay/quickpay_common'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class QuickpayV4to7Gateway < Gateway
      include QuickpayCommon
      self.live_url = self.test_url = 'https://secure.quickpay.dk/api'    
      APPROVED = '000'

      # The login is the QuickpayId
      # The password is the md5checkword from the Quickpay manager
      # To use the API-key from the Quickpay manager, specify :api-key
      # Using the API-key, requires that you use version 4+. Specify :version => 4/5/6/7 in options.
      def initialize(options = {})
        requires!(options, :login, :password)
        @protocol = options.delete(:version) || 7 # default to protocol version 7
        super
      end

      def authorize(money, credit_card_or_reference, options = {})
        post = {}

        action = recurring_or_authorize(credit_card_or_reference)

        add_amount(post, money, options)
        add_invoice(post, options)
        add_creditcard_or_reference(post, credit_card_or_reference, options)
        add_autocapture(post, false)
        add_fraud_parameters(post, options) if action.eql?(:authorize)
        add_testmode(post)

        commit(action, post)
      end

      def purchase(money, credit_card_or_reference, options = {})
        post = {}

        action = recurring_or_authorize(credit_card_or_reference)

        add_amount(post, money, options)
        add_creditcard_or_reference(post, credit_card_or_reference, options)
        add_invoice(post, options)
        add_fraud_parameters(post, options) if action.eql?(:authorize)
        add_autocapture(post, true)

        commit(action, post)
      end

      def capture(money, authorization, options = {})
        post = {}

        add_finalize(post, options)
        add_reference(post, authorization)
        add_amount_without_currency(post, money)
        commit(:capture, post)
      end

      def void(identification, options = {})
        post = {}

        add_reference(post, identification)

        commit(:cancel, post)
      end

      def refund(money, identification, options = {})
        post = {}

        add_amount_without_currency(post, money)
        add_reference(post, identification)

        commit(:refund, post)
      end

      def credit(money, identification, options = {})
        ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, identification, options)
      end

      def store(creditcard, options = {})
        post = {}

        add_creditcard(post, creditcard, options)
        add_amount(post, 0, options) if @protocol >= 7
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
        post[:acquirers]      = options[:acquirers] unless options[:acquirers].blank?
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
        return if post[:transaction].present?
        post[:testmode] = test? ? '1' : '0'
      end

      def add_fraud_parameters(post, options)
        if @protocol >= 4
          post[:fraud_remote_addr] = options[:ip] if options[:ip]
          post[:fraud_http_accept] = options[:fraud_http_accept] if options[:fraud_http_accept]
          post[:fraud_http_accept_language] = options[:fraud_http_accept_language] if options[:fraud_http_accept_language]
          post[:fraud_http_accept_encoding] = options[:fraud_http_accept_encoding] if options[:fraud_http_accept_encoding]
          post[:fraud_http_accept_charset] = options[:fraud_http_accept_charset] if options[:fraud_http_accept_charset]
          post[:fraud_http_referer] = options[:fraud_http_referer] if options[:fraud_http_referer]
          post[:fraud_http_user_agent] = options[:fraud_http_user_agent] if options[:fraud_http_user_agent]
        end
      end

      def add_finalize(post, options)
        post[:finalize] = options[:finalize] ? '1' : '0'
      end

      def commit(action, params)
        response = parse(ssl_post(self.live_url, post_data(action, params)))

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
        number.to_s.gsub(/[^\w]/, '').rjust(4, "0")[0...20]
      end
    end
  end
end

