module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class UsaEpayTransactionGateway < Gateway
      self.live_url = 'https://www.usaepay.com/gate'
      self.test_url = 'https://sandbox.usaepay.com/gate'

      self.supported_cardtypes  = %i[visa master american_express]
      self.supported_countries  = ['US']
      self.homepage_url         = 'http://www.usaepay.com/'
      self.display_name         = 'USA ePay'

      TRANSACTIONS = {
        authorization: 'cc:authonly',
        purchase: 'cc:sale',
        capture: 'cc:capture',
        refund: 'cc:refund',
        void: 'cc:void',
        void_release: 'cc:void:release',
        check_purchase: 'check:sale'
      }

      STANDARD_ERROR_CODE_MAPPING = {
        '00011' => STANDARD_ERROR_CODE[:incorrect_number],
        '00012' => STANDARD_ERROR_CODE[:incorrect_number],
        '00013' => STANDARD_ERROR_CODE[:incorrect_number],
        '00014' => STANDARD_ERROR_CODE[:invalid_number],
        '00015' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        '00016' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        '00017' => STANDARD_ERROR_CODE[:expired_card],
        '10116' => STANDARD_ERROR_CODE[:incorrect_cvc],
        '10107' => STANDARD_ERROR_CODE[:incorrect_zip],
        '10109' => STANDARD_ERROR_CODE[:incorrect_address],
        '10110' => STANDARD_ERROR_CODE[:incorrect_address],
        '10111' => STANDARD_ERROR_CODE[:incorrect_address],
        '10127' => STANDARD_ERROR_CODE[:card_declined],
        '00043' => STANDARD_ERROR_CODE[:call_issuer],
        '10205' => STANDARD_ERROR_CODE[:card_declined],
        '10204' => STANDARD_ERROR_CODE[:pickup_card]
      }

      def initialize(options = {})
        requires!(options, :login)
        super
      end

      def authorize(money, credit_card, options = {})
        post = {}

        add_amount(post, money)
        add_invoice(post, options)
        add_payment(post, credit_card)
        unless credit_card.track_data.present?
          add_address(post, credit_card, options)
          add_customer_data(post, options)
        end
        add_split_payments(post, options)
        add_recurring_fields(post, options)
        add_custom_fields(post, options)
        add_line_items(post, options)
        add_test_mode(post, options)

        commit(:authorization, post)
      end

      def purchase(money, payment, options = {})
        post = {}

        add_amount(post, money)
        add_invoice(post, options)
        add_payment(post, payment, options)
        unless payment.respond_to?(:track_data) && payment.track_data.present?
          add_address(post, payment, options)
          add_customer_data(post, options)
        end
        add_split_payments(post, options)
        add_recurring_fields(post, options)
        add_custom_fields(post, options)
        add_line_items(post, options)
        add_test_mode(post, options)

        payment.respond_to?(:routing_number) ? commit(:check_purchase, post) : commit(:purchase, post)
      end

      def capture(money, authorization, options = {})
        post = { refNum: authorization }

        add_amount(post, money)
        add_test_mode(post, options)
        commit(:capture, post)
      end

      def refund(money, authorization, options = {})
        post = { refNum: authorization }

        add_amount(post, money)
        add_test_mode(post, options)
        commit(:refund, post)
      end

      def verify(creditcard, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(1, creditcard, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      # Pass `no_release: true` to keep the void from immediately settling
      def void(authorization, options = {})
        command = (options[:no_release] ? :void : :void_release)
        post = { refNum: authorization }
        add_test_mode(post, options)
        commit(command, post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((&?UMcard=)\d*(&?))i, '\1[FILTERED]\2').
          gsub(%r((&?UMcvv2=)\d*(&?))i, '\1[FILTERED]\2').
          gsub(%r((&?UMmagstripe=)[^&]*)i, '\1[FILTERED]\2').
          gsub(%r((&?UMaccount=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?UMkey=)[^&]*)i, '\1[FILTERED]')
      end

      private

      def add_amount(post, money)
        post[:amount] = amount(money)
      end

      def expdate(credit_card)
        year  = format(credit_card.year, :two_digits)
        month = format(credit_card.month, :two_digits)

        "#{month}#{year}"
      end

      def add_customer_data(post, options)
        address = options[:billing_address] || options[:address] || {}
        post[:street] = address[:address1]
        post[:zip] = address[:zip]

        if options.has_key? :email
          post[:custemail] = options[:email]
          if options[:cust_receipt]
            post[:custreceipt] = options[:cust_receipt]
            post[:custreceiptname] = options[:cust_receipt_name] if options[:cust_receipt_name]
          else
            post[:custreceipt] = 'No'
          end
        end

        post[:custid] = options[:customer] if options.has_key? :customer

        post[:ip] = options[:ip] if options.has_key? :ip
      end

      def add_address(post, payment, options)
        billing_address = options[:billing_address] || options[:address]

        add_address_for_type(:billing, post, payment, billing_address) if billing_address
        add_address_for_type(:shipping, post, payment, options[:shipping_address]) if options[:shipping_address]
      end

      def add_address_for_type(type, post, payment, address)
        prefix = address_key_prefix(type)
        first_name, last_name = split_names(address[:name])

        post[address_key(prefix, 'fname')]    = first_name.blank? && last_name.blank? ? payment.first_name : first_name
        post[address_key(prefix, 'lname')]    = first_name.blank? && last_name.blank? ? payment.last_name : last_name
        post[address_key(prefix, 'company')]  = address[:company]   unless address[:company].blank?
        post[address_key(prefix, 'street')]   = address[:address1]  unless address[:address1].blank?
        post[address_key(prefix, 'street2')]  = address[:address2]  unless address[:address2].blank?
        post[address_key(prefix, 'city')]     = address[:city]      unless address[:city].blank?
        post[address_key(prefix, 'state')]    = address[:state]     unless address[:state].blank?
        post[address_key(prefix, 'zip')]      = address[:zip]       unless address[:zip].blank?
        post[address_key(prefix, 'country')]  = address[:country]   unless address[:country].blank?
        post[address_key(prefix, 'phone')]    = address[:phone]     unless address[:phone].blank?
      end

      def address_key_prefix(type)
        case type
        when :shipping then 'ship'
        when :billing then 'bill'
        end
      end

      def address_key(prefix, key)
        "#{prefix}#{key}".to_sym
      end

      def add_invoice(post, options)
        post[:invoice]      = options[:invoice]
        post[:orderid]      = options[:order_id]
        post[:description]  = options[:description]
      end

      def add_payment(post, payment, options={})
        if payment.respond_to?(:routing_number)
          post[:checkformat] = options[:check_format] if options[:check_format]
          if payment.account_type
            account_type = payment.account_type.to_s.capitalize
            raise ArgumentError, 'account_type must be checking or savings' unless %w(Checking Savings).include?(account_type)

            post[:accounttype] = account_type
          end
          post[:account] = payment.account_number
          post[:routing] = payment.routing_number
          post[:name]    = payment.name unless payment.name.blank?
        elsif payment.respond_to?(:track_data) && payment.track_data.present?
          post[:magstripe] = payment.track_data
          post[:cardpresent] = true
        else
          post[:card]   = payment.number
          post[:cvv2]   = payment.verification_value if payment.verification_value?
          post[:expir]  = expdate(payment)
          post[:name]   = payment.name unless payment.name.blank?
          post[:cardpresent] = true if payment.manual_entry
        end
      end

      def add_test_mode(post, options)
        post[:testmode] = (options[:test_mode] ? 1 : 0) if options.has_key?(:test_mode)
      end

      # see: http://wiki.usaepay.com/developer/transactionapi#split_payments
      def add_split_payments(post, options)
        return unless options[:split_payments].is_a?(Array)

        options[:split_payments].each_with_index do |payment, index|
          prefix = '%02d' % (index + 2)
          post["#{prefix}key"]         = payment[:key]
          post["#{prefix}amount"]      = amount(payment[:amount])
          post["#{prefix}description"] = payment[:description]
        end

        # When blank it's 'Stop'. 'Continue' is another one
        post['onError'] = options[:on_error] || 'Void'
      end

      def add_recurring_fields(post, options)
        return unless options[:recurring_fields].is_a?(Hash)

        options[:recurring_fields].each do |key, value|
          if value == true
            value = 'yes'
          elsif value == false
            next
          end

          value = amount(value) if key == :bill_amount

          post[key.to_s.delete('_')] = value
        end
      end

      # see: https://wiki.usaepay.com/developer/transactionapi#merchant_defined_custom_fields
      def add_custom_fields(post, options)
        return unless options[:custom_fields].is_a?(Hash)

        options[:custom_fields].each do |index, custom|
          raise ArgumentError.new('Cannot specify custom field with index 0') if index.to_s.to_i.zero?

          post["custom#{index}"] = custom
        end
      end

      # see: https://wiki.usaepay.com/developer/transactionapi#line_item_details
      def add_line_items(post, options)
        return unless options[:line_items].is_a?(Array)

        options[:line_items].each_with_index do |line_item, index|
          %w(product_ref_num sku qty name description taxable tax_rate tax_amount commodity_code discount_rate discount_amount).each do |key|
            post["line#{index}#{key.delete('_')}"] = line_item[key.to_sym] if line_item.has_key?(key.to_sym)
          end

          {
            quantity: 'qty',
            unit: 'um'
          }.each do |key, umkey|
            post["line#{index}#{umkey}"] = line_item[key.to_sym] if line_item.has_key?(key.to_sym)
          end

          post["line#{index}cost"] = amount(line_item[:cost])
        end
      end

      def parse(body)
        fields = {}
        for line in body.split('&')
          key, value = *line.scan(%r{^(\w+)\=(.*)$}).flatten
          fields[key] = CGI.unescape(value.to_s)
        end

        {
          status: fields['UMstatus'],
          auth_code: fields['UMauthCode'],
          ref_num: fields['UMrefNum'],
          batch: fields['UMbatch'],
          avs_result: fields['UMavsResult'],
          avs_result_code: fields['UMavsResultCode'],
          cvv2_result: fields['UMcvv2Result'],
          cvv2_result_code: fields['UMcvv2ResultCode'],
          vpas_result_code: fields['UMvpasResultCode'],
          result: fields['UMresult'],
          error: fields['UMerror'],
          error_code: fields['UMerrorcode'],
          acs_url: fields['UMacsurl'],
          payload: fields['UMpayload']
        }.delete_if { |k, v| v.nil? }
      end

      def commit(action, parameters)
        url = (test? ? self.test_url : self.live_url)
        response = parse(ssl_post(url, post_data(action, parameters)))
        approved = response[:status] == 'Approved'
        error_code = nil
        error_code = (STANDARD_ERROR_CODE_MAPPING[response[:error_code]] || STANDARD_ERROR_CODE[:processing_error]) unless approved
        Response.new(approved, message_from(response), response,
          test: test?,
          authorization: response[:ref_num],
          cvv_result: response[:cvv2_result_code],
          avs_result: { code: response[:avs_result_code] },
          error_code: error_code
        )
      end

      def message_from(response)
        if response[:status] == 'Approved'
          return 'Success'
        else
          return 'Unspecified error' if response[:error].blank?

          return response[:error]
        end
      end

      def post_data(action, parameters = {})
        parameters[:command]  = TRANSACTIONS[action]
        parameters[:key]      = @options[:login]
        parameters[:software] = 'Active Merchant'
        parameters[:testmode] = (@options[:test] ? 1 : 0) unless parameters.has_key?(:testmode)
        seed = SecureRandom.hex(32).upcase
        hash = Digest::SHA1.hexdigest("#{parameters[:command]}:#{@options[:password]}:#{parameters[:amount]}:#{parameters[:invoice]}:#{seed}")
        parameters[:hash] = "s/#{seed}/#{hash}/n"

        parameters.collect { |key, value| "UM#{key}=#{CGI.escape(value.to_s)}" }.join('&')
      end
    end
  end
end
