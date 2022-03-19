module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayArcGateway < Gateway
      self.test_url = 'https://testapi.payarc.net/v1'
      self.live_url = 'https://api.payarc.net/v1'

      self.supported_countries = ['US']
      self.default_currency = 'usd'
      self.supported_cardtypes = %i[visa master american_express discover jcb]

      self.homepage_url = 'https://www.payarc.net/'
      self.display_name = 'PAYARC Gateway'

      STANDARD_ERROR_CODE_MAPPING = {}
      STANDARD_ACTIONS = {
        token:
          { end_point: 'tokens',
            allowed_fields: %i[card_source card_number exp_month exp_year cvv card_holder_name
                               address_line1 address_line2 city state zip country] },
        capture:
          { end_point: 'charges',
            allowed_fields: %i[amount statement_description card_id currency customer_id token_id card_source tip_amount
                               card_level sales_tax purchase_order supplier_reference_number customer_ref_id ship_to_zip
                               amex_descriptor customer_vat_number summary_commodity_code shipping_charges duty_charges
                               ship_from_zip destination_country_code vat_invoice order_date tax_category tax_type
                               tax_amount tax_rate address_line1 zip terminal_id surcharge description email receipt_phone statement_descriptor ] },
        void:
          { end_point: 'charges/{{chargeID}}/void',
            allowed_fields: %i[reason void_description] },
        refund:
          { end_point: 'charges/{{charge_id}}/refunds',
            allowed_fields: %i[amount reason description] },
        credit:
          { end_point: 'refunds/wo_reference',
            allowed_fields: %i[amount charge_description statement_description terminal_id card_source card_number
                               exp_month exp_year cvv card_holder_name address_line1 address_line2 city state zip
                               country currency reason receipt_phone receipt_email  ] }
      }

      SUCCESS_STATUS = %w[
        submitted_for_settlement authorized partially_submitted_for_settlement
        credit partial_refund void refunded settled
      ]

      FAILURE_STATUS = %w[not_processed failed_by_gateway invalid_track_data authorization_expired]

      # The gateway must be configured with Bearer token.
      #
      # <tt>:api_key</tt>     PAYARC's Bearer token must be passsed to initialise the gateway.

      def initialize(options = {})
        requires!(options, :api_key)
        super
      end

      #
      # Purchase API through PAYARC.
      #
      # <tt>:money</tt>       A positive integer in cents representing how much to charge. The minimum amount is 50c USD.
      #
      # <tt>:creditcard</tt>     <tt>CreditCard</tt> object with card details.
      #
      # <tt>:options</tt>     Other information like address, card source etc can be passed in options
      #
      # ==== Options
      #
      # * <tt>:card_source </tt> -- Source of payment (REQUIRED) ( INTERNET, SWIPE, PHONE, MAIL, MANUAL )
      # * <tt>:currency </tt> -- Three-letter ISO currency code, in lowercase (REQUIRED)
      # * <tt>:card_holder_name</tt> --Name of the Card Holder (OPTIONAL)
      # * <tt>:address_line1</tt> -- Set in payment method's billing address (OPTIONAL)
      # * <tt>:address_line2</tt> -- Set in payment method's billing address (OPTIONAL)
      # * <tt>:state </tt> -- State (OPTIONAL)
      # * <tt>:country </tt> -- Country (OPTIONAL)
      # * <tt>:statement_description </tt> -- An arbitrary string to be displayed on your costomer's credit card statement. This may be up to 22 characters. (OPTIONAL)
      # * <tt> :card_level </tt> -- Commercial card level - "LEVEL2" OR "LEVEL3" (OPTIONAL)
      # * <tt> :sales_tax  </tt> -- A positive integer in cents representing sales tax. (OPTIONAL)
      # * <tt> :terminal_id </tt> -- Optional terminal id. (OPTIONAL)
      # * <tt> :tip_amount </tt> -- A positive integer in cents representing tip amount. (OPTIONAL)
      # * <tt> :sales_tax </tt> -- Applicable for LEVEL2 or LEVEL3 Charge. A positive integer in cents representing sales tax. (REQUIRED for LEVEL2 0r LEVEL3)
      # * <tt> :purchase_order </tt> -- Applicable for Level2 or Level3 Charge. The value used by the customer to identify an order. Issued by the buyer to the seller. (REQUIRED for LEVEL2 0r LEVEL3)
      # * <tt> :order_date </tt> -- Applicable for Level2 Charge for AMEX card only or Level3 Charge. The date the order was processed. Format: Alphanumeric and Special Character |Min Length=0 Max Length=10|Allowed format: MM/DD/YYYY For example: 12/01/2016
      # * <tt> :customer_ref_id </tt> -- Applicable for Level2 Charge for AMEX card only or Level3 Charge. The reference identifier supplied by the Commercial Card cardholder. Format: Alphanumeric and Special Character |Min Length=0 Max Length=17| a-z A-Z 0-9 Space <>
      # * <tt> :ship_to_zip </tt> -- Applicable for Level2 Charge for AMEX card only or Level3 Charge. The postal code for the address to which the goods are being shipped. Format: Alphanumeric |Min Length=2 Max Length=10
      # * <tt> :amex_descriptor </tt> -- Applicable for Level2 Charge for AMEX card only. The value of the Transaction Advice Addendum field, displays descriptive information about a transactions on a customer's AMEX card statement. Format: Alphanumeric and Special Character |Min Length=0 Max Length=40|a-z A-Z 0-9 Space <>
      # * <tt> :supplier_reference_number </tt> --  Applicable for Level2 Charge for AMEX card only or Level3 charge. The value used by the customer to identify an order. Issued by the buyer to the seller.
      # * <tt> :tax_amount </tt> -- Applicable for Level3 Charge. The tax amount. Format: Numeric|Max Length=12|Allowed characters: 0-9 .(dot) Note: If a decimal point is included, the amount reflects a dollar value. If a decimal point is not included, the amount reflects a cent value.
      # * <tt> :tax_category </tt> -- Applicable for Level3 Charge. The type of tax. Formerly established through TaxCategory messages. Allowed values: SERVICE, DUTY, VAT, ALTERNATE, NATIONAL, TAX_EXEMPT
      # * <tt> :customer_vat_number </tt> -- Applicable for Level3 Charge. Indicates the customer's government assigned tax identification number or the identification number assigned to their purchasing company by the tax authorities. Format: Alphanumeric and Special Character|Min Length=0 Max Length=13| a-z A-Z 0-9 Space <>
      # * <tt> :summary_commodity_code </tt> -- Applicable for Level3 Charge. The international description code of the overall goods or services being supplied. Format: Alphanumeric and Special Character |Min Length=0 Max Length=4|Allowed character: a-z A-Z 0-9 Space <>
      # * <tt> :shipping_charges </tt> -- Applicable for Level3 Charge. The dollar amount for shipping or freight charges applied to a product or transaction. Format: Numeric |Max Length=12|Allowed characters: 0-9 .(dot) Note: If a decimal point is included, the amount reflects a dollar value. If a decimal point is not included, the amount reflects a cent value.
      # * <tt> :duty_charges </tt> -- Applicable for Level3 Charge. Indicates the total charges for any import or export duties included in the order. Format: Numeric |Max Length=12|Allowed characters: 0-9 . (dot) Note: If a decimal point is included, the amount reflects a dollar value. If a decimal point is not included, the amount reflects a cent value.
      # * <tt> :ship_from_zip </tt> -- Applicable for Level3 Charge. The postal code for the address to which the goods are being shipped. Format: Alphanumeric |Min Length=2 Max Length=10
      # * <tt> :destination_country_code </tt> -- Applicable for Level3 Charge. The destination country code indicator. Format: Alphanumeric.
      # * <tt> :tax_type  </tt> -- Applicable for Level3 Charge. The type of tax. For example, VAT, NATIONAL, Service Tax. Format: Alphanumeric and Special Character
      # * <tt> :vat_invoice </tt> -- Applicable for Level3 Charge. The Value Added Tax (VAT) invoice number associated with the transaction. Format: Alphanumeric and Special Character |Min Length=0 Max Length=15|Allowed character: a-z A-Z 0-9 Space <>
      # * <tt> :tax_rate </tt> -- Applicable for Level3 Charge. The type of tax rate. This field is used if taxCategory is not used. Default sale tax rate in percentage Must be between 0.1% - 22% ,Applicable only Level 2 AutoFill. Format: Decimal Number |Max Length=4|Allowed characters: 0-9 .(dot) Allowed range: 0.01 - 100
      # * <tt> :email </tt> -- Customer's email address sent with payment method.

      def purchase(money, creditcard, options = {})
        options[:capture] = 1
        MultiResponse.run do |r|
          r.process { token(creditcard, options) }
          r.process { charge(money, r.authorization, options) }
        end
      end

      #
      # Authorize the payment API through PAYARC.
      #
      # <tt>:money</tt>       A positive integer in cents representing how much to charge. The minimum amount is 50c USD.
      #
      # <tt>:creditcard</tt>     <tt>CreditCard</tt> object with card details.
      #
      # <tt>:options</tt>     Other information like address, card source etc can be passed in options
      #
      # ==== Options
      #
      # * <tt>:card_source </tt> -- Source of payment (REQUIRED) ( INTERNET, SWIPE, PHONE, MAIL, MANUAL )
      # * <tt>:currency </tt> -- Three-letter ISO currency code, in lowercase (REQUIRED)
      # * <tt>:card_holder_name</tt> --Name of the Card Holder (OPTIONAL)
      # * <tt>:address_line1</tt> -- Set in payment method's billing address (OPTIONAL)
      # * <tt>:address_line2</tt> -- Set in payment method's billing address (OPTIONAL)
      # * <tt>:state </tt> -- State (OPTIONAL)
      # * <tt>:country </tt> -- Country (OPTIONAL)
      # * <tt>:statement_description </tt> -- An arbitrary string to be displayed on your costomer's credit card statement. This may be up to 22 characters. (OPTIONAL)
      # * <tt> :card_level </tt> -- Commercial card level - "LEVEL2" OR "LEVEL3" (OPTIONAL)
      # * <tt> :sales_tax  </tt> -- A positive integer in cents representing sales tax. (OPTIONAL)
      # * <tt> :terminal_id </tt> -- Optional terminal id. (OPTIONAL)
      # * <tt> :tip_amount </tt> -- A positive integer in cents representing tip amount. (OPTIONAL)
      # * <tt> :sales_tax </tt> -- Applicable for LEVEL2 or LEVEL3 Charge. A positive integer in cents representing sales tax. (REQUIRED for LEVEL2 0r LEVEL3)
      # * <tt> :purchase_order </tt> -- Applicable for Level2 or Level3 Charge. The value used by the customer to identify an order. Issued by the buyer to the seller. (REQUIRED for LEVEL2 0r LEVEL3)
      # * <tt> :order_date </tt> -- Applicable for Level2 Charge for AMEX card only or Level3 Charge. The date the order was processed. Format: Alphanumeric and Special Character |Min Length=0 Max Length=10|Allowed format: MM/DD/YYYY For example: 12/01/2016
      # * <tt> :customer_ref_id </tt> -- Applicable for Level2 Charge for AMEX card only or Level3 Charge. The reference identifier supplied by the Commercial Card cardholder. Format: Alphanumeric and Special Character |Min Length=0 Max Length=17| a-z A-Z 0-9 Space <>
      # * <tt> :ship_to_zip </tt> -- Applicable for Level2 Charge for AMEX card only or Level3 Charge. The postal code for the address to which the goods are being shipped. Format: Alphanumeric |Min Length=2 Max Length=10
      # * <tt> :amex_descriptor </tt> -- Applicable for Level2 Charge for AMEX card only. The value of the Transaction Advice Addendum field, displays descriptive information about a transactions on a customer's AMEX card statement. Format: Alphanumeric and Special Character |Min Length=0 Max Length=40|a-z A-Z 0-9 Space <>
      # * <tt> :supplier_reference_number </tt> --  Applicable for Level2 Charge for AMEX card only or Level3 charge. The value used by the customer to identify an order. Issued by the buyer to the seller.
      # * <tt> :tax_amount </tt> -- Applicable for Level3 Charge. The tax amount. Format: Numeric|Max Length=12|Allowed characters: 0-9 .(dot) Note: If a decimal point is included, the amount reflects a dollar value. If a decimal point is not included, the amount reflects a cent value.
      # * <tt> :tax_category </tt> -- Applicable for Level3 Charge. The type of tax. Formerly established through TaxCategory messages. Allowed values: SERVICE, DUTY, VAT, ALTERNATE, NATIONAL, TAX_EXEMPT
      # * <tt> :customer_vat_number </tt> -- Applicable for Level3 Charge. Indicates the customer's government assigned tax identification number or the identification number assigned to their purchasing company by the tax authorities. Format: Alphanumeric and Special Character|Min Length=0 Max Length=13| a-z A-Z 0-9 Space <>
      # * <tt> :summary_commodity_code </tt> -- Applicable for Level3 Charge. The international description code of the overall goods or services being supplied. Format: Alphanumeric and Special Character |Min Length=0 Max Length=4|Allowed character: a-z A-Z 0-9 Space <>
      # * <tt> :shipping_charges </tt> -- Applicable for Level3 Charge. The dollar amount for shipping or freight charges applied to a product or transaction. Format: Numeric |Max Length=12|Allowed characters: 0-9 .(dot) Note: If a decimal point is included, the amount reflects a dollar value. If a decimal point is not included, the amount reflects a cent value.
      # * <tt> :duty_charges </tt> -- Applicable for Level3 Charge. Indicates the total charges for any import or export duties included in the order. Format: Numeric |Max Length=12|Allowed characters: 0-9 . (dot) Note: If a decimal point is included, the amount reflects a dollar value. If a decimal point is not included, the amount reflects a cent value.
      # * <tt> :ship_from_zip </tt> -- Applicable for Level3 Charge. The postal code for the address to which the goods are being shipped. Format: Alphanumeric |Min Length=2 Max Length=10
      # * <tt> :destination_country_code </tt> -- Applicable for Level3 Charge. The destination country code indicator. Format: Alphanumeric.
      # * <tt> :tax_type  </tt> -- Applicable for Level3 Charge. The type of tax. For example, VAT, NATIONAL, Service Tax. Format: Alphanumeric and Special Character
      # * <tt> :vat_invoice </tt> -- Applicable for Level3 Charge. The Value Added Tax (VAT) invoice number associated with the transaction. Format: Alphanumeric and Special Character |Min Length=0 Max Length=15|Allowed character: a-z A-Z 0-9 Space <>
      # * <tt> :tax_rate </tt> -- Applicable for Level3 Charge. The type of tax rate. This field is used if taxCategory is not used. Default sale tax rate in percentage Must be between 0.1% - 22% ,Applicable only Level 2 AutoFill. Format: Decimal Number |Max Length=4|Allowed characters: 0-9 .(dot) Allowed range: 0.01 - 100
      # * <tt> :email </tt> -- Customer's email address.

      def authorize(money, creditcard, options = {})
        options[:capture] = '0'
        MultiResponse.run do |r|
          r.process { token(creditcard, options) }
          r.process { charge(money, r.authorization, options) }
        end
      end

      #
      # Capture the payment of an existing, uncaptured, charge.
      # This is the second half of the two-step payment flow, where first you created / authorized a charge
      # with the capture option set to false.
      #
      # <tt>:money</tt>         A positive integer in cents representing how much to charge. The minimum amount is 50c USD.
      #
      # <tt>:tx_reference</tt>  charge_id from previously created / authorized a charge
      #
      # <tt>:options</tt>       Other information like address, card source etc can be passed in options

      def capture(money, tx_reference, options = {})
        post = {}
        add_money(post, money, options)
        action = "#{STANDARD_ACTIONS[:capture][:end_point]}/#{tx_reference}/capture"
        post = filter_gateway_fields(post, options, STANDARD_ACTIONS[:capture][:allowed_fields])
        commit(action, post)
      end

      #
      # Voids the transaction / charge.
      #
      # <tt>:tx_reference</tt>  charge_id from previously created  charge
      #
      # <tt>:options</tt>       Other information like address, card source etc can be passed in options
      #
      # ==== Options
      #
      # * <tt> :reason </tt> -- Reason for voiding transaction (REQUIRED) ( requested_by_customer, duplicate, fraudulent, other )

      def void(tx_reference, options = {})
        post = {}
        post['reason'] = options[:reason]
        action = STANDARD_ACTIONS[:void][:end_point].gsub(/{{chargeID}}/, tx_reference)
        post = filter_gateway_fields(post, options, STANDARD_ACTIONS[:void][:allowed_fields])
        commit(action, post)
      end

      #
      # Refund full / partial  payment of an successful charge / capture / purchase.
      #
      # <tt>:money</tt>         A positive integer in cents representing how much to charge. The minimum amount is 50c USD.
      #
      # <tt>:tx_reference</tt>  charge_id from previously created / authorized a charge
      #
      # <tt>:options</tt>       Other information like address, card source etc can be passed in options

      def refund(money, tx_reference, options = {})
        post = {}
        add_money(post, money, options)
        action = STANDARD_ACTIONS[:refund][:end_point].gsub(/{{charge_id}}/, tx_reference)
        post = filter_gateway_fields(post, options, STANDARD_ACTIONS[:refund][:allowed_fields])
        commit(action, post)
      end

      def credit(money, creditcard, options = {})
        post = {}
        add_money(post, money, options)
        add_creditcard(post, creditcard, options)
        add_address(post, options)
        add_phone(post, options)
        post['receipt_email'] = options[:email] if options[:email]
        action = STANDARD_ACTIONS[:credit][:end_point]
        post = filter_gateway_fields(post, options, STANDARD_ACTIONS[:credit][:allowed_fields])
        commit(action, post)
      end

      #
      # Verify the creditcard API through PAYARC.
      #
      # <tt>:creditcard</tt>     <tt>CreditCard</tt> object with card details.
      #
      # <tt>:options</tt>     Other information like address, card source etc can be passed in options
      #
      # ==== Options
      #
      # * <tt>:card_source </tt> -- Source of payment (REQUIRED) ( INTERNET, SWIPE, PHONE, MAIL, MANUAL )
      # * <tt>:card_holder_name</tt> --Name of the Card Holder (OPTIONAL)
      # * <tt>:address_line1</tt> -- Set in payment method's billing address (OPTIONAL)
      # * <tt>:address_line2</tt> -- Set in payment method's billing address (OPTIONAL)
      # * <tt>:state </tt> -- State (OPTIONAL)
      # * <tt>:country </tt> -- Country (OPTIONAL)

      def verify(creditcard, options = {})
        token(creditcard, options)
      end

      #:nodoc:
      def token(creditcard, options = {})
        post = {}
        post['authorize_card'] = 1
        post['card_source'] = options[:card_source]
        add_creditcard(post, creditcard, options)
        add_address(post, options)
        post = filter_gateway_fields(post, options, STANDARD_ACTIONS[:token][:allowed_fields])
        commit(STANDARD_ACTIONS[:token][:end_point], post)
      end

      def supports_scrubbing? #:nodoc:
        true
      end

      def scrub(transcript)
        #:nodoc:
        transcript.
          gsub(%r((Authorization: Bearer )[^\s]+\s)i, '\1[FILTERED]\2').
          gsub(%r((&?card_number=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?cvv=)[^&]*)i, '\1[BLANK]')
      end

      private

      def charge(money, authorization, options = {})
        post = {}
        post['token_id'] = authorization
        post['capture'] = options[:capture] || 1
        add_money(post, money, options)
        add_phone(post, options)
        post = filter_gateway_fields(post, options, STANDARD_ACTIONS[:capture][:allowed_fields])
        commit(STANDARD_ACTIONS[:capture][:end_point], post)
      end

      def add_creditcard(post, creditcard, options)
        post['card_number'] = creditcard.number
        post['exp_month'] = format(creditcard.month, :two_digits)
        post['exp_year'] = creditcard.year
        post['cvv'] = creditcard.verification_value unless creditcard.verification_value.nil?
        post['card_holder_name'] = options[:card_holder_name] || "#{creditcard.first_name} #{creditcard.last_name}"
      end

      def add_address(post, options)
        return unless billing_address = options[:billing_address]

        post['address_line1'] = billing_address[:address1]
        post['address_line2'] = billing_address[:address2]
        post['city'] = billing_address[:city]
        post['state'] = billing_address[:state]
        post['zip'] = billing_address[:zip]
        post['country'] = billing_address[:country]
      end

      def add_phone(post, options)
        post['phone_number'] = options[:billing_address][:phone] if options.dig(:billing_address, :phone)
      end

      def add_money(post, money, options)
        post['amount'] = money
        post['currency'] = currency(money) unless options[:currency]
        post['statement_description'] = options[:statement_description]
      end

      def headers(api_key)
        {
          'Authorization' => 'Bearer ' + api_key.strip,
          'Accept' => 'application/json',
          'User-Agent' => "PayArc ActiveMerchantBindings/#{ActiveMerchant::VERSION}"
        }
      end

      def parse(body)
        JSON.parse(body)
      rescue JSON::ParserError
        body
      end

      def filter_gateway_fields(post, options, gateway_fields)
        filtered_options = options.slice(*gateway_fields).compact
        post.update(filtered_options)
        post
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        headers = headers(@options[:api_key])
        end_point = "#{url}/#{action}"
        begin
          response = ssl_post(end_point, post_data(parameters), headers)
          parsed_response = parse(response)

          Response.new(
            success_from(parsed_response, action),
            message_from(parsed_response, action),
            parsed_response,
            test: test?,
            authorization: parse_response_id(parsed_response),
            error_code: error_code_from(parsed_response, action)
          )
        rescue ResponseError => e
          parsed_response = parse(e.response.body)
          Response.new(
            false,
            message_from(parsed_response, action),
            parsed_response,
            test: test?,
            authorization: nil,
            error_code: error_code_from(parsed_response, action)
          )
        end
      end

      def success_from(response, action)
        if action == STANDARD_ACTIONS[:token][:end_point]
          token = parse_response_id(response)
          (!token.nil? && !token.empty?)
        elsif response
          return SUCCESS_STATUS.include? response['data']['status'] if response['data']
        end
      end

      def message_from(response, action)
        if success_from(response, action)
          if action == STANDARD_ACTIONS[:token][:end_point]
            return response['data']['id']
          else
            return response['data']['status']
          end
        else
          return response['message']
        end
      end

      def parse_response_id(response)
        response['data']['id'] if response && response['data']
      end

      def post_data(params)
        params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      end

      def error_code_from(response, action)
        response['status_code'] unless success_from(response, action)
      end
    end
  end
end
