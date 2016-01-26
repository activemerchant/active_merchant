module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CardknoxGateway < Gateway
      self.live_url = 'https://x1.cardknox.com/gateway'

      self.supported_countries = ['US','CA','GB']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]

      self.homepage_url = 'https://www.cardknox.com/'
      self.display_name = 'Cardknox'

      COMMANDS = {
        credit_card: {
          purchase:          'cc:sale',
          authorization:     'cc:authonly',
          capture:           'cc:capture',
          refund:            'cc:refund',
          void:              'cc:void',
          save:              'cc:save'
        },
        check: {
          purchase:    'check:sale',
          refund:      'check:refund',
          void:        'check:void',
          save:        'check:save'
        }
      }

      def initialize(options={})
        requires!(options, :api_key)
        super
      end

      # There are three sources for doing a purchase transation:
      # - credit card
      # - check
      # - cardknox token, which is returned in the the authorization string "ref_num;token;command"

      def purchase(amount, source, options={})
        post = {}
        add_amount(post, amount, options)
        add_invoice(post, options)
        add_source(post, source)
        add_address(post, source, options)
        add_customer_data(post, options)
        add_custom_fields(post, options)
        commit(:purchase, source_type(source), post)
      end

      def authorize(amount, source, options={})
        post = {}
        add_amount(post, amount)
        add_invoice(post, options)
        add_source(post, source)
        add_address(post, source, options)
        add_customer_data(post, options)
        add_custom_fields(post, options)
        commit(:authorization, source_type(source), post)
      end

      def capture(amount, authorization, options = {})
        post = {}
        add_reference(post, authorization)
        add_amount(post, amount)
        commit(:capture, source_type(authorization), post)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_reference(post, authorization)
        add_amount(post, amount)
        commit(:refund, source_type(authorization), post)
      end

      def void(authorization, options = {})
        post = {}
        add_reference(post, authorization)
        commit(:void, source_type(authorization), post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
         r.process { authorize(100, credit_card, options) }
         r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def store(source, options = {})
        post = {}
        add_source(post, source)
        add_address(post, source, options)
        add_invoice(post, options)
        add_customer_data(post, options)
        add_custom_fields(post, options)
        commit(:save, source_type(source), post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((xCardNum=)\d+), '\1[FILTERED]').
          gsub(%r((xCVV=)\d+), '\1[FILTERED]').
          gsub(%r((xAccount=)\d+), '\1[FILTERED]').
          gsub(%r((xRouting=)\d+), '\1[FILTERED]').
          gsub(%r((xKey=)\w+), '\1[FILTERED]')
      end

      private

      def split_authorization(authorization)
        authorization.split(";")
      end

      def add_reference(post, reference)
        reference, _, _ = split_authorization(reference)
        post[:Refnum] = reference
      end

      def source_type(source)
        if source.respond_to?(:brand)
          :credit_card
        elsif source.respond_to?(:routing_number)
          :check
        elsif source.kind_of?(String)
          source_type_from(source)
        else
          raise ArgumentError, "Unknown source #{source.inspect}"
        end
      end

      def source_type_from(authorization)
        _, _, source_type = split_authorization(authorization)
        (source_type || "credit_card").to_sym
      end

      def add_source(post, source)
        if source.respond_to?(:brand)
          add_credit_card(post, source)
        elsif source.respond_to?(:routing_number)
          add_check(post, source)
        elsif source.kind_of?(String)
          add_cardknox_token(post, source)
        else
          raise ArgumentError, "Invalid payment source #{source.inspect}"
        end
      end

      # Subtotal + Tax + Tip = Amount.

      def add_amount(post, money, options = {})
        post[:Tip]    = amount(options[:tip])
        post[:Amount] = amount(money)
      end

      def expdate(credit_card)
        year  = format(credit_card.year, :two_digits)
        month = format(credit_card.month, :two_digits)
        "#{month}#{year}"
      end

      def add_customer_data(post, options)
        address = options[:billing_address] || {}
        post[:Street] = address[:address1]
        post[:Zip] = address[:zip]
        post[:PONum] = options[:po_number]
        post[:Fax] = options[:fax]
        post[:Email] = options[:email]
        post[:IP] = options[:ip]
      end

      def add_address(post, source, options)
        add_address_for_type(:billing, post, source, options[:billing_address]) if options[:billing_address]
        add_address_for_type(:shipping, post, source, options[:shipping_address]) if options[:shipping_address]
      end

      def add_address_for_type(type, post, source, address)
        prefix = address_key_prefix(type)
        if source.respond_to?(:first_name)
          post[address_key(prefix, 'FirstName')] = source.first_name
          post[address_key(prefix, 'LastName')]  = source.last_name
        else
          post[address_key(prefix, 'FirstName')] = address[:first_name]
          post[address_key(prefix, 'LastName')]  = address[:last_name]
        end
        post[address_key(prefix, 'MiddleName')]  = address[:middle_name]

        post[address_key(prefix, 'Company')]  = address[:company]
        post[address_key(prefix, 'Street')]   = address[:address1]
        post[address_key(prefix, 'Street2')]  = address[:address2]
        post[address_key(prefix, 'City')]     = address[:city]
        post[address_key(prefix, 'State')]    = address[:state]
        post[address_key(prefix, 'Zip')]      = address[:zip]
        post[address_key(prefix, 'Country')]  = address[:country]
        post[address_key(prefix, 'Phone')]    = address[:phone]
        post[address_key(prefix, 'Mobile')]   = address[:mobile]
      end

      def address_key_prefix(type)
        case type
        when :shipping then 'Ship'
        when :billing then 'Bill'
        else
          raise ArgumentError, "Unknown address key prefix: #{type}"
        end
      end

      def address_key(prefix, key)
        "#{prefix}#{key}".to_sym
      end

      def add_invoice(post, options)
        post[:Invoice] = options[:invoice]
        post[:OrderID] = options[:order_id]
        post[:Comments] = options[:comments]
        post[:Description] = options[:description]
        post[:Tax] = amount(options[:tax])
      end

      def add_custom_fields(post, options)
        options.keys.grep(/^custom(?:[01]\d|20)$/) do |key|
          post[key.to_s.capitalize] = options[key]
        end
      end

      def add_credit_card(post, credit_card)
        if credit_card.track_data.present?
          post[:Magstripe] = credit_card.track_data
          post[:Cardpresent] = true
        else
          post[:CardNum] = credit_card.number
          post[:CVV] = credit_card.verification_value
          post[:Exp] = expdate(credit_card)
          post[:Name] = credit_card.name
          post[:CardPresent] = true if credit_card.manual_entry
        end
      end

      def add_check(post, check)
        post[:Routing] = check.routing_number
        post[:Account] = check.account_number
        post[:Name] = check.name
        post[:CheckNum] = check.number
      end

      def add_cardknox_token(post, authorization)
        _, token, _ = split_authorization(authorization)

        post[:Token] = token
      end

      def parse(body)
        fields = {}
        for line in body.split('&')
          key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
          fields[key] = CGI.unescape(value.to_s)
        end

        {
          result:            fields['xResult'],
          status:            fields['xStatus'],
          error:             fields['xError'],
          auth_code:         fields['xAuthCode'],
          ref_num:           fields['xRefNum'],
          current_ref_num:   fields['xRefNumCurrent'],
          token:             fields['xToken'],
          batch:             fields['xBatch'],
          avs_result:        fields['xAvsResult'],
          avs_result_code:   fields['xAvsResultCode'],
          cvv_result:        fields['xCvvResult'],
          cvv_result_code:   fields['xCvvResultCode'],
          remaining_balance: fields['xRemainingBalance'],
          amount:            fields['xAuthAmount'],
          masked_card_num:   fields['xMaskedCardNumber'],
          masked_account_number: fields['MaskedAccountNumber']
        }.delete_if{|k, v| v.nil?}
      end


      def commit(action, source_type, parameters)
        response = parse(ssl_post(live_url, post_data(COMMANDS[source_type][action], parameters)))

       Response.new(
          (response[:status] == 'Approved'),
          message_from(response),
          response,
          authorization: authorization_from(response, source_type),
          avs_result: { code: response[:avs_result_code] },
          cvv_result: response[:cvv_result_code]
        )
      end

      def message_from(response)
        if response[:status] == "Approved"
          "Success"
        elsif response[:error].blank?
          "Unspecified error"
        else
          response[:error]
        end
      end

      def authorization_from(response, source_type)
        "#{response[:ref_num]};#{response[:token]};#{source_type}"
      end

      def post_data(command, parameters = {})
        initial_parameters = {
          Key: @options[:api_key],
          Version: "4.5.4",
          SoftwareName: 'Active Merchant',
          SoftwareVersion: "#{ActiveMerchant::VERSION}",
          Command: command,
        }

        seed = SecureRandom.hex(32).upcase
        hash = Digest::SHA1.hexdigest("#{initial_parameters[:command]}:#{@options[:pin]}:#{parameters[:amount]}:#{parameters[:invoice]}:#{seed}")
        initial_parameters[:Hash] = "s/#{seed}/#{hash}/n" unless @options[:pin].blank?
        parameters = initial_parameters.merge(parameters)

        parameters.reject{|k, v| v.blank?}.collect{ |key, value| "x#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end
    end
  end
end
