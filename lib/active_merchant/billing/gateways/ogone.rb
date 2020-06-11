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
    # guide version 4.3.0 (25 April 2012), available here:
    # https://secure.ogone.com/ncol/Ogone_DirectLink_EN.pdf
    #
    # It also features aliases, which allow to store/unstore credit cards, as specified in
    # the Alias Manager Option guide version 3.2.1 (25 April 2012) available here:
    # https://secure.ogone.com/ncol/Ogone_Alias_EN.pdf
    #
    # It also implements the 3-D Secure feature, as specified in the DirectLink with
    # 3-D Secure guide version 3.0 (25 April 2012) available here:
    # https://secure.ogone.com/ncol/Ogone_DirectLink-3-D_EN.pdf
    #
    # It was last tested on Release 4.92 of Ogone DirectLink + AliasManager + Direct Link 3D
    # (25 April 2012).
    #
    # For any questions or comments, please contact one of the following:
    # - Joel Cogen (joel.cogen@belighted.com)
    # - Nicolas Jacobeus (nicolas.jacobeus@belighted.com),
    # - Sébastien Grosjean (public@zencocoon.com),
    # - Rémy Coutable (remy@jilion.com).
    #
    # == Usage
    #
    #   gateway = ActiveMerchant::Billing::OgoneGateway.new(
    #     :login               => "my_ogone_psp_id",
    #     :user                => "my_ogone_user_id",
    #     :password            => "my_ogone_pswd",
    #     :signature           => "my_ogone_sha_signature", # Only if you configured your Ogone environment so.
    #     :signature_encryptor => "sha512"                  # Can be "none" (default), "sha1", "sha256" or "sha512".
    #                                                       # Must be the same as the one configured in your Ogone account.
    #   )
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
    #   puts response.order_id      # Retrieve the order ID
    #
    # == Alias feature
    #
    #   To use the alias feature, simply add :billing_id in the options hash:
    #
    #   # Associate the alias to that credit card
    #   gateway.purchase(1000, creditcard, :order_id => "1", :billing_id => "myawesomecustomer")
    #
    #   # You can use the alias instead of the credit card for subsequent orders
    #   gateway.purchase(2000, "myawesomecustomer", :order_id => "2")
    #
    #   # You can also create an alias without making a purchase using store
    #   gateway.store(creditcard, :billing_id => "myawesomecustomer")
    #
    #   # When using store, you can also let Ogone generate the alias for you
    #   response = gateway.store(creditcard)
    #   puts response.billing_id # Retrieve the generated alias
    #
    #   # By default, Ogone tries to authorize 0.01 EUR but you can change this
    #   # amount using the :store_amount option when creating the gateway object:
    #   gateway = ActiveMerchant::Billing::OgoneGateway.new(
    #     :login               => "my_ogone_psp_id",
    #     :user                => "my_ogone_user_id",
    #     :password            => "my_ogone_pswd",
    #     :signature           => "my_ogone_sha_signature",
    #     :signature_encryptor => "sha512",
    #     :store_amount        => 100 # The store method will try to authorize 1 EUR instead of 0.01 EUR
    #   )
    #   response = gateway.store(creditcard) # authorize 1 EUR and void the authorization right away
    #
    # == 3-D Secure feature
    #
    #   To use the 3-D Secure feature, simply add :d3d => true in the options hash:
    #   gateway.purchase(2000, "myawesomecustomer", :order_id => "2", :d3d => true)
    #
    #   Specific 3-D Secure request options are (please refer to the documentation for more infos about these options):
    #     :win_3ds         => :main_window (default), :pop_up or :pop_ix.
    #     :http_accept     => "*/*" (default), or any other HTTP_ACCEPT header value.
    #     :http_user_agent => The cardholder's User-Agent string
    #     :accept_url      => URL of the web page to show the customer when the payment is authorized.
    #                         (or waiting to be authorized).
    #     :decline_url     => URL of the web page to show the customer when the acquirer rejects the authorization
    #                         more than the maximum permitted number of authorization attempts (10 by default, but can
    #                         be changed in the "Global transaction parameters" tab, "Payment retry" section of the
    #                         Technical Information page).
    #     :exception_url   => URL of the web page to show the customer when the payment result is uncertain.
    #     :paramplus       => Field to submit the miscellaneous parameters and their values that you wish to be
    #                         returned in the post sale request or final redirection.
    #     :complus         => Field to submit a value you wish to be returned in the post sale request or output.
    #     :language        => Customer's language, for example: "en_EN"
    #
    class OgoneGateway < Gateway
      CVV_MAPPING = { 'OK' => 'M',
                      'KO' => 'N',
                      'NO' => 'P' }

      AVS_MAPPING = { 'OK' => 'M',
                      'KO' => 'N',
                      'NO' => 'R' }

      SUCCESS_MESSAGE = 'The transaction was successful'

      THREE_D_SECURE_DISPLAY_WAYS = { main_window: 'MAINW', # display the identification page in the main window (default value).

                                      pop_up: 'POPUP',  # display the identification page in a pop-up window and return to the main window at the end.
                                      pop_ix: 'POPIX' } # display the identification page in a pop-up window and remain in the pop-up window.

      OGONE_NO_SIGNATURE_DEPRECATION_MESSAGE   = 'Signature usage will be the default for a future release of ActiveMerchant. You should either begin using it, or update your configuration to explicitly disable it (signature_encryptor: none)'
      OGONE_STORE_OPTION_DEPRECATION_MESSAGE   = "The 'store' option has been renamed to 'billing_id', and its usage is deprecated."

      self.test_url = 'https://secure.ogone.com/ncol/test/'
      self.live_url = 'https://secure.ogone.com/ncol/prod/'

      self.supported_countries = %w[BE DE FR NL AT CH]
      # also supports Airplus and UATP
      self.supported_cardtypes = %i[visa master american_express diners_club discover jcb maestro]
      self.homepage_url = 'http://www.ogone.com/'
      self.display_name = 'Ogone'
      self.default_currency = 'EUR'
      self.money_format = :cents

      def initialize(options = {})
        requires!(options, :login, :user, :password)
        super
      end

      # Verify and reserve the specified amount on the account, without actually doing the transaction.
      def authorize(money, payment_source, options = {})
        post = {}
        action = payment_source.brand == 'mastercard' ? 'PAU' : 'RES'
        add_invoice(post, options)
        add_payment_source(post, payment_source, options)
        add_address(post, payment_source, options)
        add_customer_data(post, options)
        add_money(post, money, options)
        commit(action, post)
      end

      # Verify and transfer the specified amount.
      def purchase(money, payment_source, options = {})
        post   = {}
        action = options[:action] || 'SAL'
        add_invoice(post, options)
        add_payment_source(post, payment_source, options)
        add_address(post, payment_source, options)
        add_customer_data(post, options)
        add_money(post, money, options)
        commit(action, post)
      end

      # Complete a previously authorized transaction.
      def capture(money, authorization, options = {})
        post   = {}
        action = options[:action] || 'SAL'
        add_authorization(post, reference_from(authorization))
        add_invoice(post, options)
        add_customer_data(post, options)
        add_money(post, money, options)
        commit(action, post)
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
          ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
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

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      # Store a credit card by creating an Ogone Alias
      def store(payment_source, options = {})
        options[:alias_operation] = 'BYPSP' unless options.has_key?(:billing_id) || options.has_key?(:store)
        response = authorize(@options[:store_amount] || 1, payment_source, options)
        void(response.authorization) if response.success?
        response
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((&?cardno=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?cvc=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?pswd=)[^&]*)i, '\1[FILTERED]')
      end

      private

      def reference_from(authorization)
        authorization.split(';').first
      end

      def reference_transaction?(identifier)
        return false unless identifier.is_a?(String)

        _, action = identifier.split(';')
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
        add_d3d(post, options) if options[:d3d]

        if payment_source.is_a?(String)
          add_alias(post, payment_source, options[:alias_operation])
          add_eci(post, options[:eci] || '9')
        else
          if options.has_key?(:store)
            ActiveMerchant.deprecated OGONE_STORE_OPTION_DEPRECATION_MESSAGE
            options[:billing_id] ||= options[:store]
          end
          add_alias(post, options[:billing_id], options[:alias_operation])
          add_eci(post, options[:eci] || '7')
          add_creditcard(post, payment_source)
        end
      end

      def add_d3d(post, options)
        add_pair post, 'FLAG3D', 'Y'
        win_3ds = THREE_D_SECURE_DISPLAY_WAYS.key?(options[:win_3ds]) ?
          THREE_D_SECURE_DISPLAY_WAYS[options[:win_3ds]] :
          THREE_D_SECURE_DISPLAY_WAYS[:main_window]
        add_pair post, 'WIN3DS', win_3ds

        add_pair post, 'HTTP_ACCEPT',     options[:http_accept] || '*/*'
        add_pair post, 'HTTP_USER_AGENT', options[:http_user_agent] if options[:http_user_agent]
        add_pair post, 'ACCEPTURL',       options[:accept_url]      if options[:accept_url]
        add_pair post, 'DECLINEURL',      options[:decline_url]     if options[:decline_url]
        add_pair post, 'EXCEPTIONURL',    options[:exception_url]   if options[:exception_url]
        add_pair post, 'CANCELURL',       options[:cancel_url]      if options[:cancel_url]
        add_pair post, 'PARAMVAR',        options[:paramvar]        if options[:paramvar]
        add_pair post, 'PARAMPLUS',       options[:paramplus]       if options[:paramplus]
        add_pair post, 'COMPLUS',         options[:complus]         if options[:complus]
        add_pair post, 'LANGUAGE',        options[:language]        if options[:language]
      end

      def add_eci(post, eci)
        add_pair post, 'ECI', eci.to_s
      end

      def add_alias(post, alias_name, alias_operation = nil)
        add_pair post, 'ALIAS', alias_name
        add_pair post, 'ALIASOPERATION', alias_operation unless alias_operation.nil?
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
        add_pair post, 'ORIG',    options[:origin] if options[:origin]
      end

      def add_creditcard(post, creditcard)
        add_pair post, 'CN',     creditcard.name
        add_pair post, 'CARDNO', creditcard.number
        add_pair post, 'ED',     '%02d%02s' % [creditcard.month, creditcard.year.to_s[-2..-1]]
        add_pair post, 'CVC',    creditcard.verification_value
      end

      def parse(body)
        xml_root = REXML::Document.new(body).root
        response = convert_attributes_to_hash(xml_root.attributes)

        # Add HTML_ANSWER element (3-D Secure specific to the response's params)
        # Note: HTML_ANSWER is not an attribute so we add it "by hand" to the response
        if html_answer = REXML::XPath.first(xml_root, '//HTML_ANSWER')
          response['HTML_ANSWER'] = html_answer.text
        end

        response
      end

      def commit(action, parameters)
        add_pair parameters, 'RTIMEOUT', @options[:timeout] if @options[:timeout]
        add_pair parameters, 'PSPID',  @options[:login]
        add_pair parameters, 'USERID', @options[:user]
        add_pair parameters, 'PSWD',   @options[:password]

        response = parse(ssl_post(url(parameters['PAYID']), post_data(action, parameters)))

        options = {
          authorization: [response['PAYID'], action].join(';'),
          test: test?,
          avs_result: { code: AVS_MAPPING[response['AAVCheck']] },
          cvv_result: CVV_MAPPING[response['CVCCheck']]
        }
        OgoneResponse.new(successful?(response), message_from(response), response, options)
      end

      def url(payid)
        (test? ? test_url : live_url) + (payid ? 'maintenancedirect.asp' : 'orderdirect.asp')
      end

      def successful?(response)
        response['NCERROR'] == '0'
      end

      def message_from(response)
        if successful?(response)
          SUCCESS_MESSAGE
        else
          format_error_message(response['NCERRORPLUS'])
        end
      end

      def format_error_message(message)
        raw_message = message.to_s.strip
        case raw_message
        when /\|/
          raw_message.split('|').join(', ').capitalize
        when /\//
          raw_message.split('/').first.to_s.capitalize
        else
          raw_message.to_s.capitalize
        end
      end

      def post_data(action, parameters = {})
        add_pair parameters, 'Operation', action
        add_signature(parameters)
        parameters.to_query
      end

      def add_signature(parameters)
        if @options[:signature].blank?
          ActiveMerchant.deprecated(OGONE_NO_SIGNATURE_DEPRECATION_MESSAGE) unless @options[:signature_encryptor] == 'none'
          return
        end

        add_pair parameters, 'SHASign', calculate_signature(parameters, @options[:signature_encryptor], @options[:signature])
      end

      def calculate_signature(signed_parameters, algorithm, secret)
        return legacy_calculate_signature(signed_parameters, secret) unless algorithm

        sha_encryptor =
          case algorithm
          when 'sha256'
            Digest::SHA256
          when 'sha512'
            Digest::SHA512
          when 'sha1'
            Digest::SHA1
          else
            raise "Unknown signature algorithm #{algorithm}"
          end

        filtered_params = signed_parameters.select { |k, v| !v.blank? }
        sha_encryptor.hexdigest(
          filtered_params.sort_by { |k, v| k.upcase }.map { |k, v| "#{k.upcase}=#{v}#{secret}" }.join('')
        ).upcase
      end

      def legacy_calculate_signature(parameters, secret)
        Digest::SHA1.hexdigest(
          (
            %w(
              orderID
              amount
              currency
              CARDNO
              PSPID
              Operation
              ALIAS
            ).map { |key| parameters[key] } +
            [secret]
          ).join('')
        ).upcase
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

    class OgoneResponse < Response
      def order_id
        @params['orderID']
      end

      def billing_id
        @params['ALIAS']
      end
    end
  end
end
