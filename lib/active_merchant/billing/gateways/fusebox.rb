require 'active_support/core_ext/hash/slice'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FuseboxGateway < Gateway
      FIELD_NUMBERS = {
        :transaction_type =>     '0001',
        :transaction_amount =>   '0002',
        :account_number =>       '0003',
        :expiration =>           '0004',
        :approval_code =>        '0006',
        :unique_reference =>     '0007',
        :transaction_id =>       '0036',
        :cvc =>                  '0050',
        :customer_code =>        '0070',
        :tax1_indicator =>       '0071',
        :tax1_amount =>          '0072',
        :terminal_id =>          '0109',
        :cashier_id =>           '0110',
        :transaction_qualifier =>'0115',
        :ecommerce_indicator =>  '0190',
        :ecommerce_egi =>        '0191',
        :billing_zip_code =>     '0700',
        :billing_address =>      '0701',
        :mail_order_indicator => '0712',
        :recurring_flag =>       '0723',
        :card_type =>            '1000',
        :card_name =>            '1001',
        :gateway_code =>         '1003',
        :host_message =>         '1004',
        :token_request =>        '1008',
        :host_code =>            '1009',
        :gateway_message =>      '1010',
        :gateway_id =>           '7007',
        :location_name =>        '8002',
        :chain_code =>           '8006'
      }

      TRAN_TYPES = {
        :authorize =>     '01',
        :sale  =>         '02',
        :refund =>        '09',
        :void =>          '11',
        :inquiry =>       '22',
        :auth_reversal => '61'
      }

      GATEWAY_RETRYABLE_CODES = ['0003', '0004', '0015', '0016', '0017', '0155']

      self.test_url = 'https://gatewaydemomoc.elavon.net:7500'
      self.live_url = 'https://fuseboxtrant.elavon.net:7500'
      self.default_currency = 'USD'
      self.homepage_url = 'http://gateway.elavon.com/gateway-products/fusebox.aspx'
      self.money_format = :dollars
      self.display_name = 'Elavon Fusebox'
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      class << self
        attr_accessor :requests, :responses, :force_inquiry
      end

      def initialize(options = {})
        self.class.requests = []
        self.class.responses = []
        requires!(options, :terminal_id, :chain_code, :location_name)
        super
      end

      ###### TRANSACTIONS ######

      # Parameters passed in in the options hash: {
      #   "reference"  => "01234567"  # unique reference for each purchase (8 numeric digits required)
      # }

      # Parameters returned in response.params: {
      #   "transaction_id" => "xxxx",   # Payment processor's ID for the transaction
      #   "gateway_id"     => "xxxx"    # Fusebox's ID for current API call, whether it worked or failed
      #   "token"          => "ID:xxxx" # Credit card token (when storing a new credit card)
      # }

      def authorize(money, creditcard, options = {})
        commit(
          transaction_details(money, creditcard, options).merge(:transaction_type => TRAN_TYPES[:authorize])
        )
      end

      def purchase(money, creditcard, options = {})
        recurring_fields = case options[:recurring].to_s
          when 'first'      then { :mail_order_indicator => '2', :recurring_flag => 'F' }
          when 'subsequent' then { :mail_order_indicator => '2', :recurring_flag => 'S' }
          when ''           then { :mail_order_indicator => '1' }  # regular (non-recurring) sale
          else raise ArgumentError.new("Unknown :recurring option: #{options[:recurring].inspect}")
        end

        commit_and_inquiry(
          recurring_fields.merge!(sale_fields).merge!(transaction_details(money, creditcard, options))
        )
      end

      def commit_and_inquiry(fields)
        # Perform a transaction, consider it failed if network exception or certain gateway error codes.
        # If the transaction failed, perform an inquiry.
        #   -> If success, return the inquiry as if it was the sale transaction.
        #   -> If fails, return (or re-raise) the original sale error.
        # For testing, set force_inquiry=true to throw an exception.
        sale_result = begin
          commit_result = commit(fields)
          raise ActiveMerchant::ConnectionError.new if self.class.force_inquiry
          commit_result
        rescue ActiveMerchant::ConnectionError
          # Failure scenario 1: networking exception. re-raise if inquiry returns negative.
          self.class.force_inquiry = false
          inquiry(fields).tap {|inquiry_result| raise unless inquiry_result.success? }
        end

        if GATEWAY_RETRYABLE_CODES.include?(sale_result.params[:gateway_code])
          # Failure scenario 2: gateway error code returned, return original sale error if the inquiry returns negative
          inquiry_result = inquiry(fields)
          sale_result = inquiry_result if inquiry_result.success?
        end

        sale_result
      end

      def inquiry(fields)
        commit(
          fields.merge(:transaction_type => TRAN_TYPES[:inquiry])
        )
      end

      # Storing a card is done via an authorize for $0.00 with the string "ID:" in the token request field
      # NB: Some cards/banks return an error for $0 auth, so you have to use $1 auth and then reverse it.
      def store(creditcard, options = {})
        auth_amount = options[:auth_amount] || 0
        authorize(auth_amount, creditcard, options.merge(:token_request => 'ID:'))
      end

      # For a successful void, options must include same :reference of a
      # prior purchase, and the amount of money must be identical.
      def void(money, creditcard, options = {})
        commit(
          transaction_details(money, creditcard, options).merge(:transaction_type => TRAN_TYPES[:void])
        )
      end

      def auth_reversal(money, creditcard, options = {})
        commit(
          transaction_details(money, creditcard, options).merge(:transaction_type => TRAN_TYPES[:auth_reversal])
        )
      end

      # prior purchase, and the amount of money must be identical.
      def refund(money, creditcard, options = {})
        commit(
          refund_fields.merge(transaction_details(money, creditcard, options))
        )
      end

      # Create request hash in the fusebox expected format, ready to be converted to XML
      def transaction_details(money, creditcard, options = {})
        {}.tap {|details|
          details.merge! options.slice(:token_request, :cashier_id)
          details[:transaction_qualifier] ||= '010'
          details[:transaction_amount] = amount(money)
          details[:unique_reference]   = options[:reference] if options[:reference]
          details[:billing_zip_code]   = options[:billing_zip_code].to_s.gsub(/[^a-zA-Z0-9 ]/,  '').slice(0, 9)
          details[:billing_address]    = options[:billing_address].to_s.gsub(/[^a-zA-Z0-9 ]/,  '').slice(0, 20)
          details[:cashier_id]       ||= '0'
          details[:customer_code]    ||= details[:unique_reference]
          details[:tax1_indicator]     = options[:tax1_indicator] if options[:tax1_indicator]
          details[:tax1_amount]        = options[:tax1_amount] if options[:tax1_amount]

          if creditcard.to_s.strip =~ /^(ID:\d+)\/(\d+)$/
            details[:account_number] = $1
            details[:expiration] = $2
          else
            details[:account_number] = creditcard.number
            details[:expiration] = expdate(creditcard)
            details[:cvc] = creditcard.verification_value if creditcard.verification_value?
          end
        }
      end

      # POST the request and parse the response
      def commit(fields = {})
        url = test? ? test_url : live_url
        request = build_request(fields)
        self.class.requests << request
        response = ssl_post(url, request, "Content-Type" => "application/xml")
        self.class.responses << response
        parsed_response = parse(response)

        # 0 and 0000 response codes mean successful transaction, everything else is a failure.
        if ['0', '0000'].include? parsed_response[:gateway_code]
          success_response(parsed_response)
        else
          error_response(parsed_response)
        end
      end

      private

      def parse(raw_xml)
        raw_xml.gsub!("\u001D", '')  # required to avoid parse errors in certain responses
        doc = REXML::Document.new(raw_xml)
        result = Hash.new {|h, k| h[k] = h[FIELD_NUMBERS[k]] if FIELD_NUMBERS[k] }
        doc.elements['//ProtoBase_Transaction_Batch/Transaction'].each_element('API_Field') do |field|
          result.merge!(Hash[*field.elements.map(&:text)])
        end
        result
      end

      def success_response(r)
        Response.new(
          true,
          [:gateway_code, :gateway_message, :approval_code].map {|k| r[k] }.join(', '),
          response_params(r),
          :test => test?, :authorization => r[:unique_reference]
        )
      end

      def error_response(r)
        Response.new(
          false,
          "#{r[:gateway_code]} #{r[:gateway_message]} (Host response #{r[:host_code]} #{r[:host_message]})",
          response_params(r),
          :test => test?
        )
      end

      def response_params(r)
        {
          :transaction_id => r[:transaction_id],
          :gateway_id     => r[:gateway_id],
          :token          => "#{r[:account_number]}/#{r[:expiration]}",
          :reference      => r[:unique_reference],
          :approval_code  => r[:approval_code],
          :amount         => r[:transaction_amount],
          :gateway_code   => r[:gateway_code]
        }
      end

      def build_request(fields = {})
        xml = Builder::XmlMarkup.new(:indent => 2)
        xml.tag!('ProtoBase_Transaction_Batch',
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
          'xsi:noNamespaceSchemaLocation' => 'http://www.protobase.com/XML/PBAPI1.xsd'
        ) do
          xml.tag!('Settlement_Batch', 'false')
          xml.tag!('Transaction') do
            each_api_field(fields) do |key, number, value|
              xml.tag!('API_Field') do
                xml.comment!(key)
                xml.tag!('Field_Number', number)
                xml.tag!('Field_Value', value )
              end
            end
          end
        end
        xml.target!
      end

      def each_api_field(fields)
        all_fields = default_fields.merge(fields)
        all_fields.keys.sort_by {|k| FIELD_NUMBERS.fetch(k) }.each do |key|
          yield(key.to_s, FIELD_NUMBERS.fetch(key), all_fields[key].to_s)
        end
      end

      def default_fields
        options.slice(:terminal_id, :chain_code, :location_name)
      end

      def sale_fields
        {
          :transaction_type      => TRAN_TYPES[:sale],
          :tax1_indicator        => '0',
          :tax1_amount           => '0.00'
        }.merge!(
          options.slice(:ecommerce_indicator, :ecommerce_egi, :mail_order_indicator)
        )
      end

      def refund_fields
        sale_fields.merge(:transaction_type => TRAN_TYPES[:refund])
      end
    end
  end
end
