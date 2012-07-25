require File.dirname(__FILE__) + '/migs/migs_codes'

require 'digest/md5' # Used in add_secure_hash

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MigsGateway < Gateway
      include MigsCodes

      API_VERSION = 1

      class_attribute :server_hosted_url, :merchant_hosted_url

      self.server_hosted_url = 'https://migs.mastercard.com.au/vpcpay'
      self.merchant_hosted_url = 'https://migs.mastercard.com.au/vpcdps'

      self.live_url = self.server_hosted_url

      # MiGS is supported throughout Asia Pacific, Middle East and Africa
      # MiGS is used in Australia (AU) by ANZ (eGate), CBA (CommWeb) and more
      # Source of Country List: http://www.scribd.com/doc/17811923
      self.supported_countries = %w(AU AE BD BN EG HK ID IN JO KW LB LK MU MV MY NZ OM PH QA SA SG TT VN)

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :jcb]

      self.money_format = :cents

      # The homepage URL of the gateway
      self.homepage_url = 'http://mastercard.com/mastercardsps'

      # The name of the gateway
      self.display_name = 'MasterCard Internet Gateway Service (MiGS)'

      # Creates a new MigsGateway
      # The advanced_login/advanced_password fields are needed for
      # advanced methods such as the capture, refund and status methods
      #
      # ==== Options
      #
      # * <tt>:login</tt> -- The MiGS Merchant ID (REQUIRED)
      # * <tt>:password</tt> -- The MiGS Access Code (REQUIRED)
      # * <tt>:secure_hash</tt> -- The MiGS Secure Hash
      # (Required for Server Hosted payments)
      # * <tt>:advanced_login</tt> -- The MiGS AMA User
      # * <tt>:advanced_password</tt> -- The MiGS AMA User's password
      def initialize(options = {})
        requires!(options, :login, :password)
        @test = options[:login].start_with?('TEST')
        @options = options
        super
      end

      # ==== Options
      #
      # * <tt>:order_id</tt> -- A reference for tracking the order (REQUIRED)
      # * <tt>:unique_id</tt> -- A unique id for this request (Max 40 chars).
      # If not supplied one will be generated.
      def purchase(money, creditcard, options = {})
        requires!(options, :order_id)

        post = {}
        post[:Amount] = amount(money)
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_standard_parameters('pay', post, options[:unique_id])

        commit(post)
      end

      # MiGS works by merchants being either purchase only or authorize/capture
      # So authorize is the same as purchase when in authorize mode
      alias_method :authorize, :purchase

      # ==== Options
      #
      # * <tt>:unique_id</tt> -- A unique id for this request (Max 40 chars).
      # If not supplied one will be generated.
      def capture(money, authorization, options = {})
        requires!(@options, :advanced_login, :advanced_password)

        post = options.merge(:TransNo => authorization)
        post[:Amount] = amount(money)
        add_advanced_user(post)
        add_standard_parameters('capture', post, options[:unique_id])

        commit(post)
      end

      # ==== Options
      #
      # * <tt>:unique_id</tt> -- A unique id for this request (Max 40 chars).
      # If not supplied one will be generated.
      def refund(money, authorization, options = {})
        requires!(@options, :advanced_login, :advanced_password)

        post = options.merge(:TransNo => authorization)
        post[:Amount] = amount(money)
        add_advanced_user(post)
        add_standard_parameters('refund', post, options[:unique_id])

        commit(post)
      end

      def credit(money, authorization, options = {})
        deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, authorization, options)
      end

      # Checks the status of a previous transaction
      # This can be useful when a response is not received due to network issues
      #
      # ==== Parameters
      #
      # * <tt>unique_id</tt> -- Unique id of transaction to find.
      #   This is the value of the option supplied in other methods or
      #   if not supplied is returned with key :MerchTxnRef
      def status(unique_id)
        requires!(@options, :advanced_login, :advanced_password)

        post = {}
        add_advanced_user(post)
        add_standard_parameters('queryDR', post, unique_id)

        commit(post)
      end

      # Generates a URL to redirect user to MiGS to process payment
      # Once user is finished MiGS will redirect back to specified URL
      # With a response hash which can be turned into a Response object
      # with purchase_offsite_response
      #
      # ==== Options
      #
      # * <tt>:order_id</tt> -- A reference for tracking the order (REQUIRED)
      # * <tt>:locale</tt> -- Change the language of the redirected page
      #   Values are 2 digit locale, e.g. en, es
      # * <tt>:return_url</tt> -- the URL to return to once the payment is complete
      # * <tt>:card_type</tt> -- Providing this skips the card type step.
      #   Values are ActiveMerchant formats: e.g. master, visa, american_express, diners_club
      # * <tt>:unique_id</tt> -- Unique id of transaction to find.
      #   If not supplied one will be generated.
      def purchase_offsite_url(money, options = {})
        requires!(options, :order_id, :return_url)
        requires!(@options, :secure_hash)

        post = {}
        post[:Amount] = amount(money)
        add_invoice(post, options)
        add_creditcard_type(post, options[:card_type]) if options[:card_type]

        post.merge!(
          :Locale => options[:locale] || 'en',
          :ReturnURL => options[:return_url]
        )

        add_standard_parameters('pay', post, options[:unique_id])

        add_secure_hash(post)

        self.server_hosted_url + '?' + post_data(post)
      end

      # Parses a response from purchase_offsite_url once user is redirected back
      #
      # ==== Parameters
      #
      # * <tt>data</tt> -- All params when offsite payment returns
      # e.g. returns to http://company.com/return?a=1&b=2, then input "a=1&b=2"
      def purchase_offsite_response(data)
        requires!(@options, :secure_hash)

        response_hash = parse(data)

        expected_secure_hash = calculate_secure_hash(response_hash.reject{|k, v| k == :SecureHash}, @options[:secure_hash])
        unless response_hash[:SecureHash] == expected_secure_hash
          raise SecurityError, "Secure Hash mismatch, response may be tampered with"
        end

        response_object(response_hash)
      end

      private

      def add_advanced_user(post)
        post[:User] = @options[:advanced_login]
        post[:Password] = @options[:advanced_password]
      end

      def add_invoice(post, options)
        post[:OrderInfo] = options[:order_id]
      end

      def add_creditcard(post, creditcard)
        post[:CardNum] = creditcard.number
        post[:CardSecurityCode] = creditcard.verification_value if creditcard.verification_value?
        post[:CardExp] = format(creditcard.year, :two_digits) + format(creditcard.month, :two_digits)
      end

      def add_creditcard_type(post, card_type)
        post[:Gateway]  = 'ssl'
        post[:card] = CARD_TYPES.detect{|ct| ct.am_code == card_type}.migs_long_code
      end

      def parse(body)
        params = CGI::parse(body)
        hash = {}
        params.each do |key, value|
          hash[key.gsub('vpc_', '').to_sym] = value[0]
        end
        hash
      end

      def commit(post)
        data = ssl_post self.merchant_hosted_url, post_data(post)
        response_hash = parse(data)
        response_object(response_hash)
      end

      def response_object(response)
        Response.new(success?(response), response[:Message], response,
          :test => @test,
          :authorization => response[:TransactionNo],
          :fraud_review => fraud_review?(response),
          :avs_result => { :code => response[:AVSResultCode] },
          :cvv_result => response[:CSCResultCode]
        )
      end

      def success?(response)
        response[:TxnResponseCode] == '0'
      end

      def fraud_review?(response)
        ISSUER_RESPONSE_CODES[response[:AcqResponseCode]] == 'Suspected Fraud'
      end

      def add_standard_parameters(action, post, unique_id = nil)
        post.merge!(
          :Version     => API_VERSION,
          :Merchant    => @options[:login],
          :AccessCode  => @options[:password],
          :Command     => action,
          :MerchTxnRef => unique_id || generate_unique_id.slice(0, 40)
        )
      end

      def post_data(post)
        post.collect { |key, value| "vpc_#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def add_secure_hash(post)
        post[:SecureHash] = calculate_secure_hash(post, @options[:secure_hash])
      end

      def calculate_secure_hash(post, secure_hash)
        sorted_values = post.sort_by(&:to_s).map(&:last)
        input = secure_hash + sorted_values.join
        Digest::MD5.hexdigest(input).upcase
      end
    end
  end
end
