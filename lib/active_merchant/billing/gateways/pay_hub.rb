module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayHubGateway < Gateway
      self.live_url = 'http://payhub.com/payhubws/api/'
      self.test_url = 'https://sandbox-api.payhub.com/api/'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.payhub.com/'
     
      CVV_CODE_TRANSLATOR = {
        'M' => 'CVV matches',
        'N' => 'CVV does not match',
        'P' => 'CVV not processed',
        'S' => 'CVV should have been present',
        'U' => 'CVV request unable to be processed by issuer'
      }

      AVS_CODE_TRANSLATOR = {
        '0' =>  "Approved, Address verification was not requested.",
        'A' =>  "Approved, Address matches only.",
        'B' =>  "Address Match. Street Address math for international transaction Postal Code not verified because of incompatible formats (Acquirer sent both street address and Postal Code)",
        'C' =>  "Serv Unavailable. Street address and Postal Code not verified for international transaction because of incompatible formats (Acquirer sent both street and Postal Code).",
        'D' =>  "Exact Match, Street Address and Postal Code match for international transaction.",
        'F' =>  "Exact Match, Street Address and Postal Code match. Applies to UK only.",
        'G' =>  "Ver Unavailable, Non-U.S. Issuer does not participate.",
        'I' =>  "Ver Unavailable, Address information not verified for international transaction",
        'M' =>  "Exact Match, Street Address and Postal Code match for international transaction",
        'N' =>  "No - Address and ZIP Code does not match",
        'P' =>  "Zip Match, Postal Codes match for international transaction Street address not verified because of incompatible formats (Acquirer sent both street address and Postal Code).",
        'R' =>  "Retry - Issuer system unavailable",
        'S' =>  "Serv Unavailable, Service not supported",
        'U' =>  "Ver Unavailable, Address unavailable.",
        'W' =>  "ZIP match - Nine character numeric ZIP match only.",
        'X' =>  "Exact match, Address and nine-character ZIP match.",
        'Y' =>  "Exact Match, Address and five character ZIP match.",
        'Z' =>  "Zip Match, Five character numeric ZIP match only.",
        '1' =>  "Cardholder name and ZIP match AMEX only.",
        '2' =>  "Cardholder name, address, and ZIP match AMEX only.",
        '3' =>  "Cardholder name and address match AMEX only.",
        '4' =>  "Cardholder name match AMEX only.",
        '5' =>  "Cardholder name incorrect, ZIP match AMEX only.",
        '6' =>  "Cardholder name incorrect, address and ZIP match AMEX only.",
        '7' =>  "Cardholder name incorrect, address match AMEX only.",
        '8' =>  "Cardholder, all do not match AMEX only."
      }

      STANDARD_ERROR_CODE_MAPPING = {
        '00'   => "VALID_OPERATION",
        '02'   => "CARD_NUMBER_MISSING_CODE",
        '1009' => "INVALID_REFERENCE_NUMBER",
        '4006' => "INVALID_MERCHANT",
        '4007' => "INVALID_TERMINAL",
        '4008' => "INVALID_USER_NAME",
        '4009' => "INVALID_USER_PASSWORD",
        '4010' => "INVALID_RECORD_FORMAT",
        '4011' => "INACTIVE_TERMINAL",
        '4012' => "INVALID_AUTHENTICATION",
        '4013' => "INVALID_TRANSACTION_CD",
        '4014' => "INVALID_OFFLINE_APPROVAL_CD",
        '4015' => "INVALID_CARDHOLDER_ID_CODE",
        '4016' => "INVALID_CARD_HOLDER_ID_DATA",
        '4017' => "INVALID_ACCOUNT_DATA_SOURCE",
        '4018' => "INVALID_CUSTOMER_DATA_FIELD",
        '4019' => "INVALID_CVV_CODE",
        '4020' => "INVALID_CVV_DATA",
        '4021' => "INVALID_TRANSACTION_AMOUNT",
        '4022' => "INVALID_CARD_NUMBER",
        '4023' => "INVALID_BATCH_ID",
        '4024' => "INVALID_TRANSACTION_ID",
        '4025' => "INVALID_CARD_EXPIRY_DATE",
        '4026' => "INVALID_AVS_DATA_FLAG",
        '4027' => "INVALID_CUSTOMER_ID",
        '4028' => "INVALID_CUSTOMER_WEB",
        '4029' => "INVALID_CUSTOMER_EMAIL_ID",
        '4030' => "INVALID_CUSTOMER_BILLING_ADD_ZIP",
        '4031' => "INVALID_CUSTOMER_SHIPPING_ADD_ZIP",
        '4032' => "INACTIVE_MERCHANT",
        '4033' => "INVALID_TERMINAL_ORIGIN",
        '4034' => "INVALID_CARD_DATA_FOR_DEBIT",
        '4035' => "INVALID_TRANSACTION_CODE_FOR_DEBIT",
        '4036' => "INVALID_CUSTOMER_ADDRESS",
        '4037' => "INVALID_CUSTOMER_COMPANY_NAME",
        '4038' => "INVALID_CUSTOMER_DATA",
        '4039' => "INVALID_TRANSACTION_NOTE",
        '4040' => "CARD_NOT_SUPPORT_CODE",
        '4041' => "CVV_REQUIRED_CODE",
        '4042' => "AVS_REQUIRED_CODE",
        '4043' => "CARD_REQUIRED_CODE",
        '4044' => "EXPIRY_REQUIRED_CODE",
        '4045' => "TRACK_DATA_REQUIRED_CODE",
        '4046' => "CARD_TOKEN_GENRATION_FAILED_CODE",
        '4047' => "PAYMENT_TYPE_REQUIRED_CODE",
        '4048' => "TRANSACTION_TYPE_REQUIRED_CODE",
        '4049' => "TRANSACTION_ID_REQUIRED_CODE",
        '4050' => "BATCH_ID_REQUIRED_CODE",
        '4051' => "TERMINAL_ID_REQUIRED_CODE",
        '4052' => "ORGANIZATION_REQUIRED_CODE",
        '4053' => "BATCH_TRANSACTION_NOT_FOUND_CODE",
        '4054' => "ALREADY_SETTLED_BATCH_CODE",
        '4055' => "DUPLICATE_BATCH_CODE",
        '4056' => "BATCH_SETTLED_SUCCESSFULLY_CODE",
        '4057' => "BATCH_SETTLEMENT_FAILD_CODE",
        '4058' => "BATCH_REJECTED_CODE",
        '4059' => "NETWORK_UNAVAILABLE_CODE",
        '4060' => "UNABLE_TO_BUILT_REQUEST_CODE",
        '4061' => "RECORD_NOT_FOUND_CODE",
        '4062' => "RECURRING_SAVED_CODE",
        '4063' => "RECURRING_SAVING_FAILED_CODE",
        '4064' => "RECURRING_UPDATION_CODE",
        '4065' => "RECURRING_UPDATION_FAILED_CODE",
        '4066' => "RECURRING_STATUS_CHANGED_SUCCESSFULLY",
        '4067' => "RECURRING_STATUS_CHANGING_FAILED",
        '4068' => "INVALID_TRANSACTION_ID_CODE",
        '4069' => "TRANSACTION_ALREADY_VOIDED_CODE",
        '4070' => "CARD_TYPE_REQUIRED_CODE",
        '4071' => "INVALID_BATCH_NO_CODE",
        '4072' => "TRANSACTION_ALREADY_REFUNDED_CODE",
        '4073' => "UNABLE_TO_VOID_CODE",
        '4074' => "UNABLE_TO_REFUND_CODE",
        '4075' => "UNABLE_TO_CAPTURE_CODE",
        '4076' => "CAPTURED_TRANSACTION_SENT_CODE",
        '4077' => "CAPTURED_TRANSACTION_FAILED_CODE",
        '4078' => "INVALID_INVOICE_NUMBER",
        '4080' => "INVALID_BILL_TYPE_CODE",
        '4081' => "INVALID_BILL_GENERATION_SPAN_CODE",
        '4082' => "INVALID_END_DATE_TYPE_CODE",
        '4083' => "INVALID_END_BILL_COUNT_CODE",
        '4084' => "INVALID_END_BILL_DATE_CODE",
        '4085' => "INVALID_WEEK_DAYS_CODE",
        '4086' => "INVALID_MONTHLY_TYPE_CODE",
        '4087' => "INVALID_MONTHLY_WEEK_DAYS_CODE",
        '4088' => "INVALID_MONTHLY_DAYS_POSSION_CODE",
        '4089' => "INVALID_MONTHLY_DAYS_CODE",
        '4090' => "INVALID_START_DATE_CODE",
        '4091' => "INVALID_SPECIFIC_DATES_CODE",
        '4092' => "SPECIFIC_SAME_DATES_CODE",
        '4093' => "INVALID_RECURRING_DATA_CODE",
        '4094' => "END_BILL_DATE_BEFORE_START_CODE",
        '4095' => "CARD_HOLDER_DATA_REQUIRED_CODE",
        '4096' => "CARD_HOLDER_CODE_REQUIRED_CODE",
        '4097' => "INVALID_STATUS_CODE",
        '4098' => "UNABLE_TO_CHANGE_STATUS",
        '4099' => "CARD_VALIDATION_FAILED_CODE",
        '4100' => "RECURRING_CIS_FAILED_CODE",
        '4101' => "UNABLE_BUILT_RECURRING_FILTER__CODE",
        '4103' => "UNABLE_TO_BUILT_NEXT_BILL_CODE",
        '4501' => "INVALID_PHONE_TYPE",
        '4502' => "INVALID_PHONE_NUMBER",
        '4503' => "INVALID_ZIP_CODE",
        '4504' => "INVALID_STATE_CODE",
        '4505' => "INVALID_INTERVAL_TYPE",
        '4506' => "INVALID_END_DATE",
        '4507' => "INVALID_BILL_WEEKLY_DAYS",
        '4508' => "INVALID_YEAR_MONTH_DAYS",
        '4509' => "INVALID_YEAR_BILL_ON_MONTH_NO",
        '4510' => "INVALID_MONTHLY_BILL_TYPE",
        '4511' => "INVALID_MDAYS_POSITION",
        '4512' => "INVALID_MDAYS",
        '4513' => "INVALID_MDAY_EACH_POSITIONS",
        '4514' => "INCONSISTENT_SCHEDULE_FIELDS",
        '4515' => "ACCOUNT_IS_NOT_ADMINISTRATOR",
        '4516' => "INCONSISTENT_CARD_DATA_FIELDS",
        '4517' => "WRONG_OAUTH_TOKEN_FOR_MERCHANT",
        '4518' => "NO_MERCHANT_ACCOUNT_FOR_OUTH_TOKEN_FOR_MERCHANT",
        '4519' => "NO_SETUP_ACCOUNT_FOR_OUTH_TOKEN_FOR_MERCHANT",
        '4520' => "NO_VT_CLIENT_ACCOUNT_FOR_OUTH_TOKEN_FOR_MERCHANT",
        '4521' => "INVALID_CURRENCY_CODE",
        '4522' => "INVALID_RECURRING_BILL_STATUS_CHANGE_CODE",
        '4523' => "INCONSISTENT_CURRENCIES",
        '4524' => "MISSING_PROPERTY_CODE",
        '4525' => "INCONSISTENT_CUSTOMER_DATA_CODE",
        '4526' => "DUPLICATE_DEVELOPER_CODE",
        '9989' => "METHOD_REQUEST_BODY_VALIDATION_ERROR_CODE",
        '9990' => "HTTP_NOT_READABLE_EXCEPTION_CODE",
        '9991' => "JSONPARSE_EXCEPTION_CODE",
        '9992' => "MAPPING_EXCEPTION_CODE",
        '9993' => "MEDIA_TYPE_NOT_SUPPORTED_CODE",
        '9994' => "METHOD_NOT_SUPPORTED_CODE",
        '9995' => "PAGE_NOT_FOUND_ERROR_CODE",
        '9996' => "ACCESS_DENIED_ERROR_CODE",
        '9997' => "JSON_SYNTAX_ERROR_CODE",
        '9998' => "NOT_FOUND_ERROR_CODE",
        '9999' => "INTERNAL_SERVER_ERROR_CODE"
      }

      def initialize(options={})
        requires!(options, :organization_id, :oauth_token, :terminal_id, :version)
        super
      end
      
      def purchase(amount, creditcard, options={})
        post = setup_post(options)
        add_bill(post, amount, options)
        add_creditcard(post, creditcard, options)
        add_customer_data(post, options)
        
        commit(:post, "sale", post, options)
      end

      def recurring(amount, creditcard, options={})
        post = setup_post(options)
        add_bill(post, amount, options)
        add_creditcard(post, creditcard, options)
        add_customer_data(post, options)
        add_schedule(post, options)
        
        commit(:post, "recurring-bill", post, options)
      end

      def refund(trans_id, options={})
        post = setup_post(options)
        post[:record_format] = options[:record_format] || "CREDIT_CARD"
        add_reference(post, trans_id)
        
        commit(:post, "refund", post, options)
      end
      
      def void(trans_id, options={})
        post = setup_post(options)
        add_reference(post, trans_id)
        
        commit(:post, "void", post, options)
      end
      
      private

      def setup_post(options={})
        post = {}
        merchant= {}
        merchant[:organization_id] = @options[:organization_id]
        merchant[:terminal_id] = @options[:terminal_id]
        post["merchant"] = merchant
        post
      end

      def add_reference(post, trans_id)
        post[:transaction_id] = trans_id
      end

      def add_customer_data(post, options = {})
        customer = {}
        customer[:first_name] = options[:first_name]
        customer[:last_name] = options[:last_name]
        customer[:email_address] = options[:email]
        customer[:company_name] = options[:company] if options[:company]
        customer[:phone_number] = options[:phone] if options[:phone]
        customer[:job_title] = options[:job_title] if options[:job_title]
        customer[:web_address] = options[:web_address] if options[:web_address]
        customer[:phone_ext] = options[:phone_ext] if options[:phone_ext]
        customer[:phone_type] = options[:phone_type] if options[:phone_type] &&  ['H', 'W', 'M'].include?(options[:phone_type])
        post[:customer] = customer
      end

      def add_address(post, options = {})
        return unless post[:card_data] && post[:card_data].kind_of?(Hash)
        if address = options[:address] || options[:billing_address]
          post[:card_data][:billing_address_1] = address[:address1] if address[:address1]
          post[:card_data][:billing_address_2] = address[:address2] if address[:address2]
          post[:card_data][:billing_city] = address[:city] if address[:city]
          post[:card_data][:billing_state] = address[:state] if address[:state]
          post[:card_data][:billing_zip] = address[:zip] if address[:zip]
        end  
      end

      def add_bill(post, amount, options = {})
        bill = {}
        bill[:note] = options[:note] if options[:note]
        bill[:invoice_number] = options[:invoice_number] if options[:invoice_number]
        bill[:po_number] = options[:po_number] if options[:po_number]
        post[:bill] = bill
        
        add_amount(post, amount)
        add_shipping_amount(post, options)
        add_tax_amount(post, options)
      end

      def add_amount(post, amount)
        base_amount = {}
        base_amount[:amount] =  amount(amount)
        
        post[:bill][:base_amount] = base_amount
      end

      def add_shipping_amount(post, options = {})
        return unless options[:shipping_amount] 
        add_shipping_amount = {}
        add_shipping_amount[:amount] = options[:shipping_amount]
        
        post[:bill][:add_shipping_amount] = add_shipping_amount
      end

      def add_tax_amount(post, options = {})
        return unless options[:tax_amount]
        tax_amount = {}
        tax_amount[:amount] = options[:tax_amount]
        post[:bill][:tax_amount] = tax_amount
      end

      def add_creditcard(post, creditcard, options)
        card_data = {}
        card_data[:card_number] = creditcard.number
        card_data[:card_expiry_date] = creditcard.year.to_s + creditcard.month.to_s
        card_data[:cvv_data] = creditcard.verification_value
        post[:card_data] = card_data
        
        add_address(post, options)
      end

      def add_schedule(post, options ={})
        schedule = {}
        schedule[:schedule_type] = options[:schedule][:schedule_type]
        unless options[:schedule][:schedule_type] == "S"
          schedule[:bill_generation_interval] = options[:schedule][:bill_generation_interval]
          schedule_start_and_end(schedule, options)
        end
        add_schedule_type(schedule, options)
        post[:schedule] = schedule
      end
     
      def add_schedule_type(schedule, options = {})
        #~ return unless post[:schedule] && post[:schedule].kind_of?(Hash)
        if options[:schedule][:schedule_type]
          case options[:schedule][:schedule_type]
            when "S"
              specific_dates_schedule(schedule, options)
            when "W"
              weekly_schedule(schedule, options)
            when "M"
              monthly_schedule(schedule, options)
            when "Y"
              yearly_schedule(schedule, options)
          end
        end    
      end

      def specific_dates_schedule(schedule, options = {})
        specific_dates_schedule = {}
        specific_dates_schedule[:specific_dates] = options[:schedule][:specific_dates_schedule][:specific_dates]
        
        schedule[:specific_dates_schedule] = specific_dates_schedule
      end

      def weekly_schedule(schedule, options = {})
        weekly_schedule = {}
        weekly_schedule[:weekly_bill_days] = options[:weekly_bill_days]
        
        schedule[:weekly_schedule] = weekly_schedule
      end

      def monthly_schedule(schedule, options = {})
        monthly_schedule = {}
        case options[:monthly_type]
          when "O"
            monthly_schedule[:monthly_each_days] = options[:monthly_each_days]
          when "E"
            monthly_schedule[:monthly_on_the_day_of_week_in_month ] = options[:monthly_on_the_day_of_week_in_month ]
        end
          
        schedule[:monthly_schedule] = monthly_schedule  
      end

      def yearly_schedule(schedule, options = {})
        yearly_schedule  = {}
        yearly_schedule[:year_to_start] = options[:year_to_start]
        yearly_schedule[:yearly_bill_on_day_of_month ] = options[:yearly_bill_on_day_of_month]
        
        schedule[:yearly_schedule] = yearly_schedule  
      end

      def schedule_start_and_end(schedule, options = {})
        schedule_start_and_end  = {}
        schedule_start_and_end[:start_date] = options[:start_date]
        case options[:end_date_type]
          when "A"
            schedule_start_and_end[:end_after_bill_count] =  options[:end_after_bill_count]
          when "O"
            schedule_start_and_end[:end_date] = options[:end_date]
        end  
        schedule[:schedule_start_and_end] = schedule_start_and_end
      end

      def parse(body)
        JSON.parse(body)
      end

      def headers(options = {})
        oauth_token = options[:oauth_token] || @options[:oauth_token]

        headers = {
          "Authorization" => "Bearer " + oauth_token,
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
        headers
      end

      def api_version(options)
        options[:version] || @options[:version] || "v2"
      end
      
      def commit(method, endpoint, post, options)
        begin
          url = (test? ? self.test_url : self.live_url)
          raw_response = ssl_post(url + api_version(options) +"/"+ endpoint, post.to_json, headers(options))
          
          response = get_transaction_data(endpoint, raw_response["location"], options)
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        end
        
        get_response(response, endpoint)
      end

      def get_transaction_data(endpoint, url, options)
        begin
          raw_response = ssl_get(url, headers(options))
          response = parse(raw_response.body)
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end
        response
      end
      
      def get_response(response, endpoint)
        response_key = get_response_key(endpoint)
        response_message = response_message(response)
        success = (response_message == "SUCCESS")
        response = response[response_key] || response["errors"][0]
        
        Response.new(success,
          response_message,
          response,
          test: test?,
          avs_result: {code: response['avsResultCode']},
          cvv_result: response['verificationResultCode'],
          error_code: (success ? nil : STANDARD_ERROR_CODE_MAPPING[response['code']]),
          sale_id: response['saleId'],
          recurring_bill_id: response['recurringBillId'],
          transaction_id: response['saleTransactionId'],
          refund_transaction_id: response['refundTransactionId'],
          void_transaction_id: response['voidTransactionId']
        )
      end
      
      def get_response_key(endpoint)
        response_key = case endpoint
          when "sale"
            "saleResponse"
          when "recurring-bill"
            "lastRecurringBillResponse"
          when "refund"
            "lastRefundResponse"
          when "void"
            "lastVoidResponse"
        end
        response_key
      end

      def response_error(raw_response)
        parse(raw_response)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def json_error(raw_response)
        {
          "errors" => [{
            error_message: 'Invalid response received from the Payhub API.  Please contact wecare@payhub.com if you continue to receive this message.' +
              '  (The raw response returned by the API was #{raw_response.inspect})'
          }]
        }
      end

      def response_message(response)
        response["errors"].present? ? (response["errors"][0][:error_message] || "DECLINE") : "SUCCESS"
      end
    end
  end
end
