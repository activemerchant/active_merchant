require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # = Ogone DirectLink Gateway
    #
    # DirectLink is the API version of the Ogone Payment Platform. It allows server to server
    # communication between Ogone systems and your e-commerce website.
    #
    # This implementation follows the specification provided in the DirectLink integration
    # guide version 2.4 (December 2008), available here:
    # https://secure.ogone.com/ncol/Ogone_DirectLink_EN.pdf
    #
    # It also features aliases, which allow to store/unstore credit cards, as specified in
    # the Alias Manager Option guide version 2.2 available here:
    # https://secure.ogone.com/ncol/Ogone_Alias_EN.pdf
    #
    # It was last tested on Release 04.79 of Ogone e-Commerce (dated 11/02/2009).
    #
    # For any questions or comments, please contact Nicolas Jacobeus (nj@belighted.com).
    #
    # == Example use:
    #
    #   gateway = ActiveMerchant::Billing::OgoneGateway.new(
    #               :login     => "my_ogone_psp_id",
    #               :user      => "my_ogone_user_id",
    #               :password  => "my_ogone_pswd",
    #               :signature => "my_ogone_sha1_signature" # extra security, only if you configured your Ogone environment so
    #            )
    #
    #   # set up credit card obj as in main ActiveMerchant example
    #   creditcard = ActiveMerchant::Billing::CreditCard.new(
    #     :type       => 'visa',
    #     :number     => '4242424242424242',
    #     :month      => 8,
    #     :year       => 2009,
    #     :first_name => 'Bob',
    #     :last_name  => 'Bobsen'
    #   )
    #
    #   # run request
    #   response = gateway.purchase(1000, creditcard, :order_id => "1") # charge 10 EUR
    #
    #   If you don't provide an :order_id, the gateway will generate a random one for you.
    #
    #   puts response.success?      # Check whether the transaction was successful
    #   puts response.message       # Retrieve the message returned by Ogone
    #   puts response.authorization # Retrieve the unique transaction ID returned by Ogone
    #
    #   To use the alias feature, simply add :alias in the options hash:
    #
    #   gateway.purchase(1000, creditcard, :order_id => "1", :alias => "myawesomecustomer") # associates the alias to that creditcard
    #   gateway.purchase(2000, nil,        :order_id => "2", :alias => "myawesomecustomer") # don't need to know the creditcard for subsequent orders
    #
    class OgoneGateway < Gateway

      URLS = {
        :test =>       { :order => 'https://secure.ogone.com/ncol/test/orderdirect.asp',
                         :maintenance => 'https://secure.ogone.com/ncol/test/maintenancedirect.asp' },
        :production => { :order => 'https://secure.ogone.com/ncol/prod/orderdirect.asp',
                         :maintenance => 'https://secure.ogone.com/ncol/prod/maintenancedirect.asp' }
      }

      CVV_MAPPING = { 'OK' => 'M',
                      'KO' => 'N',
                      'NO' => 'P' }

      AVS_MAPPING = { 'OK' => 'M',
                      'KO' => 'N',
                      'NO' => 'R' }

      self.supported_countries = ['BE', 'DE', 'FR', 'NL', 'AT', 'CH']
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.homepage_url = 'http://www.ogone.com/'
      self.display_name = 'Ogone'
      self.default_currency = 'EUR'

      def initialize(options = {})
        requires!(options, :login, :user, :password)
        @options = options
        super
      end

      # Verify and reserve the specified amount on the account, without actually doing the transaction.
      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_alias(post, options[:alias])
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)
        add_money(post, money, options)
        commit('RES', post)
      end

      # Verify and transfer the specified amount.
      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_alias(post, options[:alias])
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)
        add_money(post, money, options)
        commit('SAL', post)
      end

      # Complete a previously authorized transaction.
      def capture(money, authorization, options = {})
        post = {}
        add_authorization(post, authorization)
        add_invoice(post, options)
        add_customer_data(post, options)
        add_money(post, money, options)
        commit('SAL', post)
      end

      # Cancels a previously authorized transaction.
      def void(identification, options = {})
        post = {}
        add_authorization(post, identification)
        commit('DES', post)
      end

      # Credit the specified account by a specific amount.
      def credit(money, identification_or_credit_card, options = {})
        post = {}
        if identification_or_credit_card.is_a?(String)
          # Referenced credit: refund of a settled transaction
          add_authorization(post, identification_or_credit_card)
        else # must be a credit card
          # Non-referenced credit: acts like a reverse purchase
          add_invoice(post, options)
          add_alias(post, options[:alias])
          add_creditcard(post, identification_or_credit_card)
          add_address(post, identification_or_credit_card, options)
          add_customer_data(post, options)
        end
        add_money(post, money, options)
        commit('RFD', post)
      end

      private

      # Specific data to add to the hash ===============================================================

      def add_alias(post, _alias)
        add_pair post, 'ALIAS',   _alias
      end

      def add_authorization(post, authorization)
        add_pair post, 'PAYID',   authorization
      end

      def add_money(post, money, options)
        add_pair post, 'currency', options[:currency] || currency(money)
        add_pair post, 'amount',   money
      end

      def add_customer_data(post, options)
        add_pair post, 'EMAIL',       options[:email]
        add_pair post, 'REMOTE_ADDR', options[:ip]
      end

      def add_address(post, creditcard, options)
        return unless options[:billing_address]
        add_pair post, 'Owneraddress', options[:billing_address][:address1]
        add_pair post, 'OwnerZip',     options[:billing_address][:zip]
        add_pair post, 'ownertown',    options[:billing_address][:city]
        add_pair post, 'ownercty',     options[:billing_address][:country]
        add_pair post, 'ownertelno',   options[:billing_address][:phone]
      end

      def add_invoice(post, options)
        add_pair post, 'orderID', options[:order_id] || generate_unique_id[0...30]
        add_pair post, 'COM',     options[:description]
      end

      def add_creditcard(post, creditcard)
        return unless (creditcard and creditcard.valid?)
        add_pair post, 'CN',     "#{creditcard.first_name} #{creditcard.last_name}"
        add_pair post, 'CARDNO', creditcard.number
        add_pair post, 'ED',     "%02d%02s" % [creditcard.month, creditcard.year.to_s[-2..-1]]
        add_pair post, 'CVC',    creditcard.verification_value
        add_pair post, 'BRAND',  creditcard.type.upcase
      end

      # Backend methods ================================================================================

      def parse(body)
        xml = REXML::Document.new(body)
        xml.root.attributes
      end

      def commit(action, parameters)
        add_pair parameters, 'PSPID',      @options[:login]
        add_pair parameters, 'USERID',     @options[:user]
        add_pair parameters, 'PSWD',       @options[:password]
        url = URLS[test? ? :test : production][parameters['PAYID'] ? :maintenance : :order ]
        response = parse(ssl_post(url, post_data(action, parameters)))
        success = response["NCERROR"]=="0"
        message = message_from(response)
        options = { :authorization => response["PAYID"],
                    :test => test?,
                    :avs_result => { :code => AVS_MAPPING[response["AAVCheck"]] },
                    :cvv_result => CVV_MAPPING[response["CVCCheck"]] }
        Response.new(success, message, response, options)
      end

      def message_from(response)
        response["NCERRORPLUS"]
      end

      def post_data(action, parameters = {})
        add_pair parameters, 'Operation' , action
        if @options[:signature] # the user wants a SHA-1 signature
          string = ['orderID','amount','currency','CARDNO','PSPID','Operation','ALIAS'].map{|s|parameters[s]}.join + @options[:signature]
          add_pair parameters, 'SHASign' , Digest::SHA1.hexdigest(string)
        end
        parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def add_pair(post, key, value, options = {})
        post[key] = value if !value.blank? || options[:required]
      end

    end
  end
end