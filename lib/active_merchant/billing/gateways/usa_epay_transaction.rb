module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    class UsaEpayTransactionGateway < Gateway
      self.live_url = 'https://www.usaepay.com/gate'
      self.test_url = 'https://sandbox.usaepay.com/gate'

      self.supported_cardtypes  = [:visa, :master, :american_express]
      self.supported_countries  = ['US']
      self.homepage_url         = 'http://www.usaepay.com/'
      self.display_name         = 'USA ePay'

      TRANSACTIONS = {
        :authorization  => 'cc:authonly',
        :purchase       => 'cc:sale',
        :capture        => 'cc:capture',
        :refund         => 'cc:refund',
        :void           => 'cc:void',
        :void_release   => 'cc:void:release'
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
        '10128' => STANDARD_ERROR_CODE[:processing_error],
        '10132' => STANDARD_ERROR_CODE[:processing_error],
        '00043' => STANDARD_ERROR_CODE[:call_issuer]
      }

      def initialize(options = {})
        requires!(options, :login)
        super
      end

      def authorize(money, credit_card, options = {})
        post = {}

        add_amount(post, money)
        add_invoice(post, options)
        add_credit_card(post, credit_card)
        unless credit_card.track_data.present?
          add_address(post, credit_card, options)
          add_customer_data(post, options)
        end
        add_split_payments(post, options)
        add_test_mode(post, options)

        commit(:authorization, post)
      end

      def purchase(money, credit_card, options = {})
        post = {}

        add_amount(post, money)
        add_invoice(post, options)
        add_credit_card(post, credit_card)
        unless credit_card.track_data.present?
          add_address(post, credit_card, options)
          add_customer_data(post, options)
        end
        add_split_payments(post, options)
        add_test_mode(post, options)

        commit(:purchase, post)
      end

      def capture(money, authorization, options = {})
        post = { :refNum => authorization }

        add_amount(post, money)
        add_test_mode(post, options)
        commit(:capture, post)
      end

      def refund(money, authorization, options = {})
        post = { :refNum => authorization }

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
        post = { :refNum => authorization }
        add_test_mode(post, options)
        commit(command, post)
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
          post[:custreceipt] = 'No'
        end

        if options.has_key? :customer
          post[:custid] = options[:customer]
        end

        if options.has_key? :ip
          post[:ip] = options[:ip]
        end
      end

      def add_address(post, credit_card, options)
        billing_address = options[:billing_address] || options[:address]

        add_address_for_type(:billing, post, credit_card, billing_address) if billing_address
        add_address_for_type(:shipping, post, credit_card, options[:shipping_address]) if options[:shipping_address]
      end

      def add_address_for_type(type, post, credit_card, address)
        prefix = address_key_prefix(type)
        first_name, last_name = split_names(address[:name])

        post[address_key(prefix, 'fname')]    = first_name.blank? && last_name.blank? ? credit_card.first_name : first_name
        post[address_key(prefix, 'lname')]    = first_name.blank? && last_name.blank? ? credit_card.last_name : last_name
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
        post[:invoice]      = options[:order_id]
        post[:description]  = options[:description]
      end

      def add_credit_card(post, credit_card)
        if credit_card.track_data.present?
          post[:magstripe] = credit_card.track_data
          post[:cardpresent] = true
        else
          post[:card]   = credit_card.number
          post[:cvv2]   = credit_card.verification_value if credit_card.verification_value?
          post[:expir]  = expdate(credit_card)
          post[:name]   = credit_card.name unless credit_card.name.blank?
          post[:cardpresent] = true if credit_card.manual_entry
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

      def parse(body)
        fields = {}
        for line in body.split('&')
          key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
          fields[key] = CGI.unescape(value.to_s)
        end

        {
          :status           => fields['UMstatus'],
          :auth_code        => fields['UMauthCode'],
          :ref_num          => fields['UMrefNum'],
          :batch            => fields['UMbatch'],
          :avs_result       => fields['UMavsResult'],
          :avs_result_code  => fields['UMavsResultCode'],
          :cvv2_result      => fields['UMcvv2Result'],
          :cvv2_result_code => fields['UMcvv2ResultCode'],
          :vpas_result_code => fields['UMvpasResultCode'],
          :result           => fields['UMresult'],
          :error            => fields['UMerror'],
          :error_code       => fields['UMerrorcode'],
          :acs_url          => fields['UMacsurl'],
          :payload          => fields['UMpayload']
        }.delete_if{|k, v| v.nil?}
      end

      def commit(action, parameters)
        url = (test? ? self.test_url : self.live_url)
        response = parse(ssl_post(url, post_data(action, parameters)))
        Response.new(response[:status] == 'Approved', message_from(response), response,
          :test           => test?,
          :authorization  => response[:ref_num],
          :cvv_result     => response[:cvv2_result_code],
          :avs_result     => { :code => response[:avs_result_code] },
          :error_code     => STANDARD_ERROR_CODE_MAPPING[response[:error_code]]
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

      def post_data(action, parameters = {})
        parameters[:command]  = TRANSACTIONS[action]
        parameters[:key]      = @options[:login]
        parameters[:software] = 'Active Merchant'
        parameters[:testmode] = (@options[:test] ? 1 : 0) unless parameters.has_key?(:testmode)
        seed = SecureRandom.hex(32).upcase
        hash = Digest::SHA1.hexdigest("#{parameters[:command]}:#{@options[:password]}:#{parameters[:amount]}:#{parameters[:invoice]}:#{seed}")
        parameters[:hash] = "s/#{seed}/#{hash}/n"

        parameters.collect { |key, value| "UM#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end
    end
  end
end
