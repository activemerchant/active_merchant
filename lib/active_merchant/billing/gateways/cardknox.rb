module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CardknoxGateway < Gateway
      # self.test_url = 'https://x1.cardknox.com/gateway'
      self.live_url = self.test_url = 'https://x1.cardknox.com/gateway'

      self.supported_countries = ['US','CA','GB']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.cardknox.com/'
      self.display_name = 'Cardknox'


      TRANSACTIONS = {
        :authorization  => 'cc:authonly',
        :purchase       => 'cc:sale',
        :capture        => 'cc:capture',
        :refund         => 'cc:refund',
        :void           => 'cc:void',
        :void_release   => 'cc:voidrelease',
        :save           => 'cc:save',  
        :check_purchase => 'check:sale',
        :check_refund   => 'check:refund',
        :check_void     => 'check:void',
        :check_save     => 'check:save'   
      }



      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :api_key)
        super
      end

      #There are three sources for doing a purchase a credit card, check, and cardknox token

      def purchase(money, source, options={})
        post = {}
        add_amount(post, money)
        add_invoice(post,options)
        add_source(post, source)
        unless source.is_a?(CreditCard) and source.track_data.present?
          add_address(post, source, options)
          add_customer_data(post, options)
        end
        commit(transacton_action("purchase", source), post)
      end

      def authorize(money, source, options={})
        post = {}
        add_amount(post, money)
        add_invoice(post,options)
        add_source(post, source)
        unless source.is_a?(CreditCard) and source.track_data.present?
          add_address(post, source, options)
          add_customer_data(post, options)
        end
        commit(:authorization, post)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_reference(post, authorization)
        add_amount(post, money)
        commit(:capture, post)
      end

      # Use refund for transactions that the batch settled or for partial refounds

      def refund(money, source, options={})
        post = {}
        add_reference(post, source)
        add_amount(post, money)
        commit(transacton_action("refund", source), post)
      end

      # Use void for tansactions that have not batched yet

      def void(source, options = {})
        post = {}
        add_reference(post, source)   
        commit(transacton_action("void", source), post )
      end

      # verify the credit card 
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
        add_invoice(post,options)
        add_customer_data(post, options)
        commit(transacton_action("save", source), post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
         gsub(%r((Authorization: Bearer )[a-zA-Z0-9._-]+)i, '\1[FILTERED]').
          gsub(%r((xCardNum=)\d+), '\1[FILTERED]').
          gsub(%r((xCVV=)\d+), '\1[FILTERED]').
          gsub(%r((xKey=)\w+), '\1[FILTERED]')
      end

      private

      def split_auth(string)
        string.split(";") if !string.empty?
      end

      def add_reference(post, reference)
        reference, _, _ = split_auth(reference) 
        post[:Refnum] = reference
      end

      # detrmines if the what type of transaction command to post

      def transacton_action(command, source)
        if source.is_a?(Check) or (source.is_a?(String) and source.include? "check") 
          "check_#{command}".to_sym
        else # if source.is_a?(CreditCard) or (source.is_a?(String) and !source.empty?) 
          command.to_sym
        end
      end
  
      # determines if the source is a credit card, check or cardknox token

      def add_source(post, source)
        if source.is_a?(String) and !source.empty?
          add_cardknox_token(post, source)
        elsif source.is_a?(Check)
          add_check(post, source)
        elsif source.is_a?(CreditCard)
          add_credit_card(post, source)
        end
      end

      def add_amount(post, money)
        post[:Amount] = amount(money)
      end

      def expdate(credit_card)
        year  = format(credit_card.year, :two_digits)
        month = format(credit_card.month, :two_digits)
        "#{month}#{year}"
      end

      def add_customer_data(post, options)
        address = options[:billing_address] || options[:address] || {}
        post[:Street] = address[:address1]
        post[:Zip] = address[:zip]

        if options.has_key? :email
          post[:Email] = options[:email]
        end

        if options.has_key? :customer
          post[:custid] = options[:customer]
        end

        if options.has_key? :ip
          post[:IP] = options[:ip]
        end
      end

      def add_address(post, credit_card, options)
        billing_address = options[:billing_address] || options[:address]

        add_address_for_type(:billing, post, credit_card, billing_address) if billing_address
        add_address_for_type(:shipping, post, credit_card, options[:shipping_address]) if options[:shipping_address]
      end

      def add_address_for_type(type, post, credit_card, address)
        prefix = address_key_prefix(type)
        if credit_card.is_a?(String)
          post[address_key(prefix, 'FirstName')] = address[:first_name] unless address[:first_name].blank?
          post[address_key(prefix, 'MiddleName')]  = address[:middle_name]  unless address[:middle_name].blank?
          post[address_key(prefix, 'LastName')]  = address[:last_name]  unless address[:last_name].blank?
        else
          post[address_key(prefix, 'FirstName')]    = credit_card.first_name 
          post[address_key(prefix, 'LastName')]    = credit_card.last_name 
        end
        post[address_key(prefix, 'Company')]  = address[:company]   unless address[:company].blank?
        post[address_key(prefix, 'Street')]   = address[:address1]  unless address[:address1].blank?
        post[address_key(prefix, 'Street2')]  = address[:address2]  unless address[:address2].blank?
        post[address_key(prefix, 'City')]     = address[:city]      unless address[:city].blank?
        post[address_key(prefix, 'State')]    = address[:state]     unless address[:state].blank?
        post[address_key(prefix, 'Zip')]      = address[:zip]       unless address[:zip].blank?
        post[address_key(prefix, 'Country')]  = address[:country]   unless address[:country].blank?
        post[address_key(prefix, 'Phone')]    = address[:phone]     unless address[:phone].blank?
        post[address_key(prefix, 'Mobile')]   = address[:mobile]    unless address[:mobile].blank?
      end

      def address_key_prefix(type)
        case type
        when :shipping then 'Ship'
        when :billing then 'Bill'
        end
      end

      def address_key(prefix, key)
        "#{prefix}#{key}".to_sym
      end


      def add_payment(post, payment)
      end

      def add_invoice(post, options)
        post[:Invoice]      = options[:invoice] unless options[:invoice].blank?
        post[:OrderID]      = options[:order_id] unless options[:order_id].blank?

        post[:Description]  = options[:description] unless options[:description].blank?
      end

      def add_credit_card(post, credit_card)
        if credit_card.track_data.present?
          post[:Magstripe] = credit_card.track_data
          post[:Cardpresent] = true
        elsif credit_card.respond_to?(:number)
          post[:CardNum]   = credit_card.number
          post[:CVV]   = credit_card.verification_value if credit_card.verification_value?
          post[:Exp]  = expdate(credit_card)
          post[:Name]   = credit_card.name unless credit_card.name.blank?
          post[:CardPresent] = true if credit_card.manual_entry
        end
      end

      def add_check(post, check)
        post[:Routing] = check.routing_number

        post[:Account] = check.account_number

        post[:Name] = check.name
  
      end

      def add_cardknox_token(post, token)
        _, token = split_auth(token) 

        post[:Token] = token
      end

      def parse(body)
        fields = {}
        for line in body.split('&')
          key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
          fields[key] = CGI.unescape(value.to_s)
        end

        {
          :result           =>fields['xResult'], 
          :status           =>fields['xStatus'],
          :error            =>fields['xError'],
          :auth_code        =>fields['xAuthCode'],
          :ref_num          =>fields['xRefNum'],
          :token            =>fields['xToken'],
          :batch            =>fields['xBatch'],
          :avs_result       =>fields['xAvsResult'],
          :avs_result_code  => fields['xAvsResultCode'],
          :cvv_result       => fields['xCvvResult'],
          :cvv_result_code  => fields['xCvvResultCode'],
          :remaining_balance => fields['xRemainingBalance'],
          :amount            => fields['xAuthAmount'],
          :masked_card_num  => fields['xMaskedCardNumber']
        }.delete_if{|k, v| v.nil?}
      end

      def commit(action, parameters)

        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url, post_data(action, parameters)))

       Response.new(response[:status] == 'Approved', message_from(response), response,
          :authorization => authorization_from(response, action),
          :avs_result => { :code => response[:avs_result_code] },
          :cvv_result => response[:cvv_result_code],
          :error => [response[:error_code]]
        )
      end

      def message_from(response)
        if response[:status] == "Approved"
          return 'Success'
        else
          return 'Unspecified error' if response[:error].blank?
          return response[:error]
        end
      end

      def authorization_from(response, action)
        "#{response[:ref_num]};#{response[:token]};#{action}"
      end    

      def post_data(action, parameters = {}) 
        initial_parameters = {
        :Key      => @options[:api_key],
        :Version => "4.5.4",
        :SoftwareName => 'Active Merchant',
        :SoftwareVersion => "1.5.1",
        :Command  => TRANSACTIONS[action],
      }

        parameters = initial_parameters.merge(parameters)
        parameters[:Custom01] = parameters[:Invoice] || parameters[:OrderID] if parameters[:Command].to_s.include? "check"

        parameters.collect { |key, value| "x#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end
    end
  end
end
