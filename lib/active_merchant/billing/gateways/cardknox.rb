module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CardknoxGateway < Gateway
      # self.test_url = 'https://x1.cardknox.com/gateway'
      self.live_url = self.test_url = 'https://x1.cardknox.com/gateway' 

      self.supported_countries = ['US','CA','GB']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]

      self.homepage_url = 'https://www.cardknox.com/'
      self.display_name = 'Cardknox'


      TRANSACTIONS = {
        authorization:     'cc:authonly',
        capture:           'cc:capture',
        purchase:          'cc:sale',
        refund:            'cc:refund',
        void:              'cc:void',
        void_release:      'cc:voidrelease',
        void_refund:       'cc:voidrefund',
        save:              'cc:save',  
        check_purchase:    'check:sale',
        check_refund:      'check:refund',
        check_void:        'check:void',
        check_void_refund: 'check:voidrefund',
        check_save:        'check:save'   
      }



      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :api_key) #pin?
        super
      end

      # There are three sources for doing a purchase transation a credit card, check, and cardknox token which is returned in the the authrization string "ref_num;token;command"

      def purchase(money, source, options={})
        post = {}
        add_amount(post, money, options)
        add_invoice(post,options)
        add_source(post, source)
        add_address(post, source, options)
        add_customer_data(post, options)
        add_custom_fields(post, options)
        commit(transacton_action(:purchase, source), post)
      end

      def authorize(money, source, options={})
        post = {}
        add_amount(post, money,)
        add_invoice(post,options)
        add_source(post, source)
        add_address(post, source, options)
        add_customer_data(post, options)
        add_custom_fields(post, options)
        commit(:authorization, post)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_reference(post, authorization)
        add_amount(post, money)
        commit(:capture, post)
      end

      # Use refund for transactions that the batch settled or for crdit card partial refunds

      def refund(money, source, options={})
        post = {}
        add_reference(post, source)
        add_amount(post, money)
        commit(transacton_action(:refund, source), post)
      end

      # Use void for tansactions that have not batched 

      def void(source, options = {})
        post = {}
        add_reference(post, source)
        commit(transacton_action(void_action(source, options),source), post)
      end

      # verify the credit card 
      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
         r.process { authorize(100, credit_card, options) }
         r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      # store the credit card or check on the gateway which will return a cardknox token that can be used later 

      def store(source, options = {})
        post = {}
        add_source(post, source)
        add_address(post, source, options)
        add_invoice(post,options)
        add_customer_data(post, options)
        add_custom_fields(post, options)
        commit(transacton_action(:save, source), post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
    #     gsub(%r((Authorization: Bearer )[a-zA-Z0-9._-]+)i, '\1[FILTERED]').
          gsub(%r((xCardNum=)\d+), '\1[FILTERED]').
          gsub(%r((xCVV=)\d+), '\1[FILTERED]').
          gsub(%r((xAccount=)\d+), '\1[FILTERED]').
          gsub(%r((xRouting=)\d+), '\1[FILTERED]').
          gsub(%r((xKey=)\w+), '\1[FILTERED]')
      end

      private

      def split_auth(string)
        string.split(";") if string.is_a?(String) and ( !string.empty? and !string.nil?) 
      end

      def add_reference(post, reference)
        reference, _, _ = split_auth(reference) 
        post[:Refnum] = reference
      end

      # determines what type of transaction command to post credit card or check 

      def transacton_action(command, source)
        if source.is_a?(Check) or (split_auth(source) and split_auth(source).last.include?('check')) 
          "check_#{command}".to_sym
        else # if source.is_a?(CreditCard) or (source.is_a?(String) and !source.empty?) 
           command
        end
      end

      def void_action(source, options)
        if split_auth(source) and split_auth(source).last.include?('refund')
          :void_refund 
        else      
          options[:no_release] or transacton_action(:void, source) == :check_void ? :void : :void_release
        end  
      end      
  
      # determines if the source is a credit card, check or cardknox token

      def add_source(post, source)
        if source.is_a?(String)
          add_cardknox_token(post, source)
        elsif source.is_a?(Check) 
          add_check(post, source)
        elsif source.is_a?(CreditCard)
          add_credit_card(post, source)
        else
          raise ArgumentError, 'please use a valid payment source'
        end 
      end

      # add amount, tip and tax the amount is inclusive of tax and tip. Subtotal + Tax + Tip = Amount.

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
        address = options[:billing_address] || options[:address] || {}
        post[:Street] = address[:address1]
        post[:Zip] = address[:zip]
        post[:PONum]     = options[:po_number]
        post[:Fax] =  options[:fax] 
        post[:Email] = options[:email]
        post[:IP] = options[:ip]
      end

      def add_address(post, source, options)
        billing_address = options[:billing_address] || options[:address]

        add_address_for_type(:billing, post, source, billing_address) if billing_address
        add_address_for_type(:shipping, post, source, options[:shipping_address]) if options[:shipping_address]
      end

      def add_address_for_type(type, post, source, address)
        prefix = address_key_prefix(type)
        if source.is_a?(String) || source.is_a?(Check)
          post[address_key(prefix, 'FirstName')] = address[:first_name] 
          post[address_key(prefix, 'MiddleName')]  = address[:middle_name] 
          post[address_key(prefix, 'LastName')]  = address[:last_name]  
        else
          post[address_key(prefix, 'FirstName')]    = source.first_name 
          post[address_key(prefix, 'LastName')]    = source.last_name 
        end    
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
        end
      end

      def address_key(prefix, key)
        "#{prefix}#{key}".to_sym
      end


      def add_payment(post, payment)
      end

      def add_invoice(post, options)
        post[:Invoice]      = options[:invoice]
        post[:OrderID]      = options[:order_id] 
        post[:Comments]    = options[:comments]      
        post[:Description]  = options[:description] 
        post[:Tax]    = amount(options[:tax])
      end

      def add_custom_fields(post, options)
         options.each{|k, v| post[k.capitalize] = v if k[0..5] == "custom" and ('01'..'20').include?(k[6..7])}
      end


      def add_credit_card(post, credit_card)
        if credit_card.track_data.present?
          post[:Magstripe] = credit_card.track_data
          post[:Cardpresent] = true
        elsif credit_card.respond_to?(:number)
          post[:CardNum]   = credit_card.number
          post[:CVV]   = credit_card.verification_value 
          post[:Exp]  = expdate(credit_card)
          post[:Name]   = credit_card.name 
          post[:CardPresent] = true if credit_card.manual_entry
        end
      end

      def add_check(post, check)
        post[:Routing] = check.routing_number
        post[:Account] = check.account_number
        post[:Name] = check.name
        post[:CheckNum] = check.number
      end

      def add_cardknox_token(post, token)
        _, token, _ = split_auth(token) 

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

      
      def commit(action, parameters)

        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url, post_data(action, parameters)))

       Response.new(response[:status] == 'Approved', message_from(response), response,
          authorization:  authorization_from(response, action),
          avs_result: { :code => response[:avs_result_code] },
          cvv_result: response[:cvv_result_code],
          error: [response[:error_code]]
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
        "#{response[:ref_num]};#{response[:token]};#{TRANSACTIONS[action]}"
      end    

      def post_data(action, parameters = {}) 
        initial_parameters = {
        :Key      => @options[:api_key],
        :Version => "4.5.4",
        :SoftwareName => 'Active Merchant',
        :SoftwareVersion => "#{ActiveMerchant::VERSION}",
        :Command  => TRANSACTIONS[action],
       
      }
        seed = SecureRandom.hex(32).upcase
        hash = Digest::SHA1.hexdigest("#{parameters[:command]}:#{@options[:pin]}:#{parameters[:amount]}:#{parameters[:invoice]}:#{seed}")
        initial_parameters[:Hash] = "s/#{seed}/#{hash}/n" unless @options[:pin].blank?
        parameters = initial_parameters.merge(parameters)
        
        parameters.reject{|k, v| v.blank?}.collect{ |key, value| "x#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end
    end
  end
end
