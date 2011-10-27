# coding: utf-8
require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # = Ogone DirectLink Gateway
    #
    # DirectLink is the API version of the Ogone Payment Platform. It allows server to server
    # communication between Ogone systems and your e-commerce website.
    #
    # This implementation follows the specification provided in the DirectLink integration
    # guide version 4.2.0 (26 October 2011), available here:
    # https://secure.ogone.com/ncol/Ogone_DirectLink_EN.pdf
    #
    # It also features aliases, which allow to store/unstore credit cards, as specified in
    # the Alias Manager Option guide version 3.2.0 (26 October 2011) available here:
    # https://secure.ogone.com/ncol/Ogone_Alias_EN.pdf
    #
    # It was last tested on Release 4.89 of Ogone DirectLink + AliasManager (26 October 2011).
    #
    # For any questions or comments, please contact one of the following:
    # - Nicolas Jacobeus (nj@belighted.com),
    # - Sébastien Grosjean (public@zencocoon.com),
    # - Rémy Coutable (remy@jilion.com).
    #
    # == Usage
    #
    #   gateway = ActiveMerchant::Billing::OgoneGateway.new(
    #               :login                     => "my_ogone_psp_id",
    #               :user                      => "my_ogone_user_id",
    #               :password                  => "my_ogone_pswd",
    #               :signature                 => "my_ogone_sha_signature", # Only if you configured your Ogone environment so.
    #               :signature_encryptor       => "sha512", # Can be "sha1" (default), "sha256" or "sha512".
    #                                                       # Must be the same as the one configured in your Ogone account.
    #            )
    #
    #   # set up credit card object as in main ActiveMerchant example
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
    # == Alias feature
    #
    #   To use the alias feature, simply add :store in the options hash:
    #
    #   # Associate the alias to that credit card
    #   gateway.purchase(1000, creditcard, :order_id => "1", :store => "myawesomecustomer")
    #
    #   # You can use the alias instead of the credit card for subsequent orders
    #   gateway.purchase(2000, "myawesomecustomer", :order_id => "2")
    #
    class OgoneGateway < Gateway

      URLS = {
        :order       => 'https://secure.ogone.com/ncol/%s/orderdirect.asp',
        :maintenance => 'https://secure.ogone.com/ncol/%s/maintenancedirect.asp'
      }

      CVV_MAPPING = { 'OK' => 'M',
                      'KO' => 'N',
                      'NO' => 'P' }

      AVS_MAPPING = { 'OK' => 'M',
                      'KO' => 'N',
                      'NO' => 'R' }

      SUCCESS_MESSAGE = "The transaction was successful"

      OGONE_NO_SIGNATURE_DEPRECATION_MESSAGE   = "Signature usage will be required from a future release of ActiveMerchant's Ogone Gateway. Please update your Ogone account to use it."
      OGONE_LOW_ENCRYPTION_DEPRECATION_MESSAGE = "SHA512 signature encryptor will be required from a future release of ActiveMerchant's Ogone Gateway. Please update your Ogone account to use it."

      self.supported_countries = ['BE', 'DE', 'FR', 'NL', 'AT', 'CH']
      # also supports Airplus and UATP
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :discover, :jcb, :maestro]
      self.homepage_url = 'http://www.ogone.com/'
      self.display_name = 'Ogone'
      self.default_currency = 'EUR'
      self.money_format = :cents

      def initialize(options = {})
        requires!(options, :login, :user, :password)
        @options = options
        super
      end

      # Verify and reserve the specified amount on the account, without actually doing the transaction.
      def authorize(money, payment_source, options = {})
        post = {}
        add_invoice(post, options)
        add_payment_source(post, payment_source, options)
        add_address(post, payment_source, options)
        add_customer_data(post, options)
        add_money(post, money, options)
        commit('RES', post)
      end

      # Verify and transfer the specified amount.
      def purchase(money, payment_source, options = {})
        post = {}
        add_invoice(post, options)
        add_payment_source(post, payment_source, options)
        add_address(post, payment_source, options)
        add_customer_data(post, options)
        add_money(post, money, options)
        commit('SAL', post)
      end

      # Complete a previously authorized transaction.
      def capture(money, authorization, options = {})
        post = {}
        add_authorization(post, reference_from(authorization))
        add_invoice(post, options)
        add_customer_data(post, options)
        add_money(post, money, options)
        commit('SAL', post)
      end

      # Cancels a previously authorized transaction.
      def void(identification, options = {})
        post = {}
        add_authorization(post, reference_from(identification))
        commit('DES', post)
      end

      # Credit the specified account by a specific amount.
      def credit(money, identification_or_credit_card, options = {})
        if reference_transaction?(identification_or_credit_card)
          deprecated CREDIT_DEPRECATION_MESSAGE
          # Referenced credit: refund of a settled transaction
          refund(money, identification_or_credit_card, options)
        else # must be a credit card or card reference
          perform_non_referenced_credit(money, identification_or_credit_card, options)
        end
      end

      # Refund of a settled transaction
      def refund(money, reference, options = {})
        perform_reference_credit(money, reference, options)
      end

      def test?
        @options[:test] || super
      end

      private

      def reference_from(authorization)
        authorization.split(";").first
      end

      def reference_transaction?(identifier)
        return false unless identifier.is_a?(String)
        reference, action = identifier.split(";")
        !action.nil?
      end

      def perform_reference_credit(money, payment_target, options = {})
        post = {}
        add_authorization(post, reference_from(payment_target))
        add_money(post, money, options)
        commit('RFD', post)
      end

      def perform_non_referenced_credit(money, payment_target, options = {})
        # Non-referenced credit: acts like a reverse purchase
        post = {}
        add_invoice(post, options)
        add_payment_source(post, payment_target, options)
        add_address(post, payment_target, options)
        add_customer_data(post, options)
        add_money(post, money, options)
        commit('RFD', post)
      end

      def add_payment_source(post, payment_source, options)
        if payment_source.is_a?(String)
          add_alias(post, payment_source)
          add_eci(post, options[:eci] || '9')
        else
          add_alias(post, options[:store])
          add_eci(post, options[:eci] || '7')
          add_creditcard(post, payment_source)
        end
      end

      def add_eci(post, eci)
        add_pair post, 'ECI', eci.to_s
      end

      def add_alias(post, _alias)
        add_pair post, 'ALIAS', _alias
      end

      def add_authorization(post, authorization)
        add_pair post, 'PAYID', authorization
      end

      def add_money(post, money, options)
        add_pair post, 'currency', options[:currency] || @options[:currency] || currency(money)
        add_pair post, 'amount',   amount(money)
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
        add_pair post, 'CN',     creditcard.name
        add_pair post, 'CARDNO', creditcard.number
        add_pair post, 'ED',     "%02d%02s" % [creditcard.month, creditcard.year.to_s[-2..-1]]
        add_pair post, 'CVC',    creditcard.verification_value
      end

      def parse(body)
        xml_root = REXML::Document.new(body).root
        convert_attributes_to_hash(xml_root.attributes)
      end

      def commit(action, parameters)
        add_pair parameters, 'PSPID',  @options[:login]
        add_pair parameters, 'USERID', @options[:user]
        add_pair parameters, 'PSWD',   @options[:password]

        url = URLS[parameters['PAYID'] ? :maintenance : :order] % [test? ? "test" : "prod"]
        response = parse(ssl_post(url, post_data(action, parameters)))

        options = {
          :authorization => [response["PAYID"], action].join(";"),
          :test          => test?,
          :avs_result    => { :code => AVS_MAPPING[response["AAVCheck"]] },
          :cvv_result    => CVV_MAPPING[response["CVCCheck"]]
        }
        Response.new(successful?(response), message_from(response), response, options)
      end

      def successful?(response)
        response["NCERROR"] == "0"
      end

      def message_from(response)
        if successful?(response)
          SUCCESS_MESSAGE
        else
          format_error_message(response["NCERRORPLUS"])
        end
      end

      def format_error_message(message)
        raw_message = message.to_s.strip
        case raw_message
        when /\|/
          raw_message.split("|").join(", ").capitalize
        when /\//
          raw_message.split("/").first.to_s.capitalize
        else
          raw_message.to_s.capitalize
        end
      end

      def post_data(action, parameters = {})
        add_pair parameters, 'Operation', action
        @options[:signature] ? add_signature(parameters) : deprecated(OGONE_NO_SIGNATURE_DEPRECATION_MESSAGE)
        parameters.to_query
      end

      def add_signature(parameters)
        deprecated(OGONE_LOW_ENCRYPTION_DEPRECATION_MESSAGE) unless @options[:signature_encryptor] == 'sha512'

        sha_encryptor = case @options[:signature_encryptor]
                        when 'sha256'
                          Digest::SHA256
                        when 'sha512'
                          Digest::SHA512
                        else
                          Digest::SHA1
                        end

        string_to_digest = if @options[:signature_encryptor]
          parameters.sort { |a, b| a[0].upcase <=> b[0].upcase }.map { |k, v| "#{k.upcase}=#{v}" }.join(@options[:signature])
        else
          %w[orderID amount currency CARDNO PSPID Operation ALIAS].map { |key| parameters[key] }.join
        end
        string_to_digest << @options[:signature]

        add_pair parameters, 'SHASign', sha_encryptor.hexdigest(string_to_digest).upcase
      end

      def add_pair(post, key, value)
        post[key] = value if !value.blank?
      end

      def convert_attributes_to_hash(rexml_attributes)
        response_hash = {}
        rexml_attributes.each do |key, value|
          response_hash[key] = value
        end
        response_hash
      end
    end
  end
end
