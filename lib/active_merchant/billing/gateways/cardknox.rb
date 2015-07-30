module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CardknoxGateway < Gateway
      # self.test_url = 'https://x1.cardknox.com/gateway'
      self.live_url = self.test_url = 'https://x1.cardknox.com/gateway'

      self.supported_countries = ['US']
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

      def purchase(money, source, options={})
        post = {}
        add_amount(post, money)
        add_invoice(post,options)
        add_source(post, source)
        unless source.is_a?(CreditCard) and source.track_data.present?
          add_address(post, source, options)
          add_customer_data(post, options)
        end
        commit(purchase_action(source), post)
      end

      def authorize(money, credit_card, options={})
        post = {}
        add_amount(post, money)
        add_invoice(post,options)
        add_credit_card(post, credit_card)
        unless credit_card.track_data.present?
          add_address(post, credit_card, options)
          add_customer_data(post, options)
        end
        commit(:authorization, post)
      end

      def capture(money, authorization, options = {})
        post = {}
        reference, _, type = split_auth(authorization)
        add_reference(post, reference)
        add_amount(post, money)
        commit(:capture, post)
      end

      def refund(money, source, options={})
        post = {}
        reference, _, command = split_auth(source) 
        add_reference(post, reference)
        add_amount(post, money)
        commit(refund_action(command), post)
      end

      def void(source, options = {})
        post = {}
        reference, _, command  = split_auth(source)
        add_reference(post, reference)   
        commit(void_action(command), post )
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
        add_invoice(post,options)
        add_customer_data(post, options)
        commit(store_action(source), post)
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
        string.split(";")
      end

      def add_reference(post, reference)
        post[:Refnum] = reference
      end

      def add_transaction_type(post, action)
        post [:Command]  = TRANSACTIONS[action]
      end

      def purchase_action(source)
        if source.is_a?(String) and !source.empty?
          _, _,command = split_auth(source)
          command[0..4] == "check" ? :check_purchase : :purchase
        else
          if source.is_a?(Check)
            :check_purchase
          else
            :purchase
          end
        end
      end

      def void_action(original_transaction_type)
        (original_transaction_type == TRANSACTIONS[:check_purchase]) ? :check_void : :void
      end

      def refund_action(original_transaction_type)
        (original_transaction_type == TRANSACTIONS[:check_purchase]) ? :check_refund : :refund
        # if original_transaction_type[0..4] == "check" 
        #  :check_refund 
        # else
        #  :refund
        # end
      end

      def store_action(source)
        if source.is_a?(String)
          _, _, command = split_auth(source)
          command == TRANSACTIONS[:check_purchase] ? :check_save : :save
        else
          if source.is_a?(Check)
            :check_save
          else
            :save
          end
        end
      end


      def add_source(post, source)
        if source.is_a?(String) 
          _, token, command = split_auth(source)
          command[0..4] == "check" ?  add_check(post, token) : add_credit_card(post, token)
        else
       
          card_brand(source) == "check" ? add_check(post, source) : add_credit_card(post, source)
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
        post[:orderID]      = options[:order_id] unless options[:order_id].blank?
        post[:Description]  = options[:description] unless options[:description].blank?
      end

      def add_credit_card(post, credit_card)
        if credit_card.is_a?(String) 
           post[:Token] = credit_card
        else
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
      end

      def add_check(post, check)
        if check.is_a?(String)
           post[:Token] = check
        else
          post[:Routing] = check.routing_number

          post[:Account] = check.account_number

          post[:Name] = check.name
        end
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
        parameters[:Key]      = @options[:api_key]
        parameters[:Version] = "4.5.4"
        parameters[:SoftwareName] = 'Active Merchant'
        parameters[:SoftwareVersion] = "1.5.1"
        parameters[:Command]  = TRANSACTIONS[action]

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
