module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This module is included in both PaypalGateway and PaypalExpressGateway
    module PaypalCommonAPI
      API_VERSION = '72'

      URLS = {
        :test => { :certificate => 'https://api.sandbox.paypal.com/2.0/',
                   :signature   => 'https://api-3t.sandbox.paypal.com/2.0/' },
        :live => { :certificate => 'https://api-aa.paypal.com/2.0/',
                   :signature   => 'https://api-3t.paypal.com/2.0/' }
      }

      PAYPAL_NAMESPACE = 'urn:ebay:api:PayPalAPI'
      EBAY_NAMESPACE = 'urn:ebay:apis:eBLBaseComponents'

      ENVELOPE_NAMESPACES = { 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
                              'xmlns:env' => 'http://schemas.xmlsoap.org/soap/envelope/',
                              'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'
                            }
      CREDENTIALS_NAMESPACES = { 'xmlns' => PAYPAL_NAMESPACE,
                                 'xmlns:n1' => EBAY_NAMESPACE,
                                 'env:mustUnderstand' => '0'
                               }

      AUSTRALIAN_STATES = {
        'ACT' => 'Australian Capital Territory',
        'NSW' => 'New South Wales',
        'NT'  => 'Northern Territory',
        'QLD' => 'Queensland',
        'SA'  => 'South Australia',
        'TAS' => 'Tasmania',
        'VIC' => 'Victoria',
        'WA'  => 'Western Australia'
      }

      SUCCESS_CODES = [ 'Success', 'SuccessWithWarning' ]

      FRAUD_REVIEW_CODE = "11610"

      def self.included(base)
        base.default_currency = 'USD'
        base.cattr_accessor :pem_file
        base.cattr_accessor :signature
        base.live_url = URLS[:live][:signature]
        base.test_url = URLS[:test][:signature]
      end

      # The gateway must be configured with either your PayPal PEM file
      # or your PayPal API Signature.  Only one is required.
      #
      # <tt>:pem</tt>         The text of your PayPal PEM file. Note
      #                       this is not the path to file, but its
      #                       contents. If you are only using one PEM
      #                       file on your site you can declare it
      #                       globally and then you won't need to
      #                       include this option
      #
      # <tt>:signature</tt>   The text of your PayPal signature.
      #                       If you are only using one API Signature
      #                       on your site you can declare it
      #                       globally and then you won't need to
      #                       include this option
      def initialize(options = {})
        requires!(options, :login, :password)

        headers = {'X-PP-AUTHORIZATION' => options.delete(:auth_signature), 'X-PAYPAL-MESSAGE-PROTOCOL' => 'SOAP11'} if options[:auth_signature]
        options = {
          :pem => pem_file,
          :signature => signature,
          :headers => headers || {}
        }.update(options)


        if options[:pem].blank? && options[:signature].blank?
          raise ArgumentError, "An API Certificate or API Signature is required to make requests to PayPal"
        end

        super(options)
      end

      def reauthorize(money, authorization, options = {})
        commit 'DoReauthorization', build_reauthorize_request(money, authorization, options)
      end

      def capture(money, authorization, options = {})
        commit 'DoCapture', build_capture_request(money, authorization, options)
      end

      # Transfer money to one or more recipients.
      #
      #   gateway.transfer 1000, 'bob@example.com',
      #     :subject => "The money I owe you", :note => "Sorry it's so late"
      #
      #   gateway.transfer [1000, 'fred@example.com'],
      #     [2450, 'wilma@example.com', :note => 'You will receive another payment on 3/24'],
      #     [2000, 'barney@example.com'],
      #     :subject => "Your Earnings", :note => "Thanks for your business."
      #
      def transfer(*args)
        commit 'MassPay', build_mass_pay_request(*args)
      end

      def void(authorization, options = {})
        commit 'DoVoid', build_void_request(authorization, options)
      end

      # Refunds a transaction.
      #
      # For a full refund pass nil for the amount:
      #
      #    gateway.refund nil, 'G39883289DH238'
      #
      # This will automatically make the :refund_type be "Full".
      #
      # For a partial refund just pass the amount as usual:
      #
      #    gateway.refund 100, 'UBU83983N920'
      #
      def refund(money, identification, options = {})
        commit 'RefundTransaction', build_refund_request(money, identification, options)
      end

      def credit(money, identification, options = {})
        ActiveMerchant.deprecated Gateway::CREDIT_DEPRECATION_MESSAGE
        refund(money, identification, options)
      end

      # ==== For full documentation see {Paypal API Reference:}[https://cms.paypal.com/us/cgi-bin/?cmd=_render-content&content_ID=developer/e_howto_api_soap_r_DoReferenceTransaction]
      # ==== Parameter:
      # * <tt>:money</tt> -- (Required) The amount of this new transaction,
      # required fo the payment details portion of this request
      #
      # ==== Options:
      # * <tt>:reference_id</tt> -- (Required) A transaction ID from a previous purchase, such as a credit card charge using the DoDirectPayment API, or a billing agreement ID.
      # * <tt>:payment_action</tt> -- (Optional) How you want to obtain payment. It is one of the following values:
      #
      #     Authorization – This payment is a basic authorization subject to settlement with PayPal Authorization and Capture.
      #     Sale – This is a final sale for which you are requesting payment.
      #
      # * <tt>:ip_address</tt> -- (Optional) IP address of the buyer’s browser.
      # Note: PayPal records this IP addresses as a means to detect possible fraud.
      # * <tt>:req_confirm_shipping</tt> -- Whether you require that the buyer’s shipping address on file with PayPal be a confirmed address. You must have permission from PayPal to not require a confirmed address. It is one of the following values:
      #
      #     0 – You do not require that the buyer’s shipping address be a confirmed address.
      #     1 – You require that the buyer’s shipping address be a confirmed address.
      #
      # * <tt>:merchant_session_id</tt> -- (Optional) Your buyer session identification token.
      # * <tt>:return_fmf_details</tt> -- (Optional) Flag to indicate whether you want the results returned by Fraud Management Filters. By default, you do not receive this information. It is one of the following values:
      #
      #     0 – Do not receive FMF details (default)
      #     1 – Receive FMF details
      #
      # * <tt>:soft_descriptor</tt> -- (Optional) Per transaction description of the payment that is passed to the consumer’s credit card statement. If the API request provides a value for the soft descriptor field, the full descriptor displayed on the buyer’s statement has the following format:
      #
      #     <PP * | PAYPAL *><Merchant descriptor as set in the Payment Receiving Preferences><1 space><soft descriptor>
      #     The soft descriptor can contain only the following characters:
      #
      #     Alphanumeric characters
      #     - (dash)
      #     * (asterisk)
      #     . (period)
      #     {space}
      #
      def reference_transaction(money, options = {})
        requires!(options, :reference_id)
        commit 'DoReferenceTransaction', build_reference_transaction_request(money, options)
      end

      def transaction_details(transaction_id)
        commit 'GetTransactionDetails', build_get_transaction_details(transaction_id)
      end

      # ==== For full documentation see {PayPal API Reference}[https://cms.paypal.com/us/cgi-bin/?cmd=_render-content&content_ID=developer/e_howto_api_soap_r_TransactionSearch]
      # ==== Options:
      # * <tt>:payer </tt> -- (Optional) Search by the buyer’s email address.
      # * <tt>:receipt_id </tt> -- (Optional) Search by the PayPal Account Optional receipt ID.
      # * <tt>:receiver </tt> -- (Optional) Search by the receiver’s email address. If the merchant account has only one email address, this is the primary email. It can also be a non-primary email address.
      # * <tt>:transaction_id</tt> -- (Optional) Search by the transaction ID. The returned results are from the merchant’s transaction records.
      # * <tt>:invoice_id</tt> -- (Optional) Search by invoice identification key, as set by you for the original transaction. This field searches the records for items the merchant sells, not the items purchased.
      # * <tt>:card_number </tt> -- (Optional) Search by credit card number, as set by you for the original transaction. This field searches the records for items the merchant sells, not the items purchased.
      # * <tt>:auction_item_number </tt> -- (Optional) Search by auction item number of the purchased goods.
      # * <tt>:transaction_class </tt> -- (Optional) Search by classification of transaction. Some kinds of possible classes of transactions are not searchable with this field. You cannot search for bank transfer withdrawals, for example. It is one of the following values:
      #     All – All transaction classifications
      #     Sent – Only payments sent
      #     Received – Only payments received
      #     MassPay – Only mass payments
      #     MoneyRequest – Only money requests
      #     FundsAdded – Only funds added to balance
      #     FundsWithdrawn – Only funds withdrawn from balance
      #     Referral – Only transactions involving referrals
      #     Fee – Only transactions involving fees
      #     Subscription – Only transactions involving subscriptions
      #     Dividend – Only transactions involving dividends
      #     Billpay – Only transactions involving BillPay Transactions
      #     Refund – Only transactions involving funds
      #     CurrencyConversions – Only transactions involving currency conversions
      #     BalanceTransfer – Only transactions involving balance transfers
      #     Reversal – Only transactions involving BillPay reversals
      #     Shipping – Only transactions involving UPS shipping fees
      #     BalanceAffecting – Only transactions that affect the account balance
      #     ECheck – Only transactions involving eCheck
      #
      # * <tt>:currency_code </tt> -- (Optional) Search by currency code.
      # * <tt>:status</tt> -- (Optional) Search by transaction status. It is one of the following values:
      #     One of:
      #     Pending – The payment is pending. The specific reason the payment is pending is returned by the GetTransactionDetails API PendingReason field.
      #     Processing – The payment is being processed.
      #     Success – The payment has been completed and the funds have been added successfully to your account balance.
      #     Denied – You denied the payment. This happens only if the payment was previously pending.
      #     Reversed – A payment was reversed due to a chargeback or other type of reversal. The funds have been removed from your account balance and returned to the buyer.
      #
      def transaction_search(options)
        requires!(options, :start_date)
        commit 'TransactionSearch', build_transaction_search(options)
      end

      # ==== Parameters:
      # * <tt>:return_all_currencies</tt> -- Either '1' or '0'
      #     0 – Return only the balance for the primary currency holding.
      #     1 – Return the balance for each currency holding.
      #
      def balance(return_all_currencies = false)
        clean_currency_argument = case return_all_currencies
                                  when 1, '1' , true; '1'
                                  else
                                    '0'
                                  end
        commit 'GetBalance', build_get_balance(clean_currency_argument)
      end

      # DoAuthorization takes the transaction_id returned when you call
      # DoExpressCheckoutPayment with a PaymentAction of 'Order'.
      # When you did that, you created an order authorization subject to settlement
      # with PayPal DoAuthorization and DoCapture
      #
      # ==== Parameters:
      # * <tt>:transaction_id</tt> -- The ID returned by DoExpressCheckoutPayment with a PaymentAction of 'Order'.
      # * <tt>:money</tt> -- The amount of money to be authorized for this purchase.
      #
      def authorize_transaction(transaction_id, money, options = {})
        commit 'DoAuthorization', build_do_authorize(transaction_id, money, options)
      end

      # The ManagePendingTransactionStatus API operation accepts or denies a
      # pending transaction held by Fraud Management Filters.
      #
      # ==== Parameters:
      # * <tt>:transaction_id</tt> -- The ID of the transaction held by Fraud Management Filters.
      # * <tt>:action</tt> -- Either 'Accept' or 'Deny'
      #
      def manage_pending_transaction(transaction_id, action)
        commit 'ManagePendingTransactionStatus', build_manage_pending_transaction_status(transaction_id, action)
      end

      private
      def build_request_wrapper(action, options = {})
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! action + 'Req', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! action + 'Request', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            if options[:request_details]
              xml.tag! 'n2:' + action + 'RequestDetails' do
                yield(xml)
              end
            else
              yield(xml)
            end
          end
        end
        xml.target!
      end

      def build_do_authorize(transaction_id, money, options = {})
        build_request_wrapper('DoAuthorization') do |xml|
          xml.tag! 'TransactionID', transaction_id
          xml.tag! 'Amount', amount(money), 'currencyID' => options[:currency] || currency(money)
        end
      end

      def build_reauthorize_request(money, authorization, options)
        xml = Builder::XmlMarkup.new

        xml.tag! 'DoReauthorizationReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'DoReauthorizationRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'AuthorizationID', authorization
            xml.tag! 'Amount', amount(money), 'currencyID' => options[:currency] || currency(money)
          end
        end

        xml.target!
      end

      def build_capture_request(money, authorization, options)
        xml = Builder::XmlMarkup.new

        xml.tag! 'DoCaptureReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'DoCaptureRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'AuthorizationID', authorization
            xml.tag! 'Amount', amount(money), 'currencyID' => options[:currency] || currency(money)
            xml.tag! 'CompleteType',  options[:complete_type] || 'Complete'
            xml.tag! 'InvoiceID', options[:order_id] unless options[:order_id].blank?
            xml.tag! 'Note', options[:description]
          end
        end

        xml.target!
      end

      def build_refund_request(money, identification, options)
        xml = Builder::XmlMarkup.new

        xml.tag! 'RefundTransactionReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'RefundTransactionRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'TransactionID', identification
            xml.tag! 'Amount', amount(money), 'currencyID' => (options[:currency] || currency(money)) if money.present?
            xml.tag! 'RefundType', (options[:refund_type] || (money.present? ? 'Partial' : 'Full'))
            xml.tag! 'Memo', options[:note] unless options[:note].blank?
          end
        end

        xml.target!
      end

      def build_void_request(authorization, options)
        xml = Builder::XmlMarkup.new

        xml.tag! 'DoVoidReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'DoVoidRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'AuthorizationID', authorization
            xml.tag! 'Note', options[:description]
          end
        end

        xml.target!
      end

      def build_mass_pay_request(*args)
        default_options = args.last.is_a?(Hash) ? args.pop : {}
        recipients = args.first.is_a?(Array) ? args : [args]
        receiver_type = default_options[:receiver_type]

        xml = Builder::XmlMarkup.new

        xml.tag! 'MassPayReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'MassPayRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'EmailSubject', default_options[:subject] if default_options[:subject]
            xml.tag! 'ReceiverType', receiver_type if receiver_type
            recipients.each do |money, recipient, options|
              options ||= default_options
              xml.tag! 'MassPayItem' do
                if(!receiver_type || receiver_type == 'EmailAddress')
                  xml.tag! 'ReceiverEmail', recipient
                elsif receiver_type == 'UserID'
                  xml.tag! 'ReceiverID', recipient
                else
                  raise ArgumentError.new("Unknown receiver_type: #{receiver_type}")
                end
                xml.tag! 'Amount', amount(money), 'currencyID' => (options[:currency] || currency(money))
                xml.tag! 'Note', options[:note] if options[:note]
                xml.tag! 'UniqueId', options[:unique_id] if options[:unique_id]
              end
            end
          end
        end

        xml.target!
      end

      def build_manage_pending_transaction_status(transaction_id, action)
        build_request_wrapper('ManagePendingTransactionStatus') do |xml|
          xml.tag! 'TransactionID', transaction_id
          xml.tag! 'Action', action
        end
      end

      def build_reference_transaction_request(money, options)
        opts = options.dup
        opts[:ip_address] ||= opts[:ip]
        currency_code = opts[:currency] || currency(money)
        reference_transaction_optional_fields = %w{ n2:ReferenceID n2:PaymentAction
                                                    n2:PaymentType n2:IPAddress
                                                    n2:ReqConfirmShipping n2:MerchantSessionId
                                                    n2:ReturnFMFDetails n2:SoftDescriptor }
        build_request_wrapper('DoReferenceTransaction', :request_details => true) do |xml|
          add_optional_fields(xml, reference_transaction_optional_fields, opts)
          add_payment_details(xml, money, currency_code, opts)
        end
      end

      def build_get_transaction_details(transaction_id)
        build_request_wrapper('GetTransactionDetails') do |xml|
          xml.tag! 'TransactionID', transaction_id
        end
      end

      def build_transaction_search(options)
        currency_code = options[:currency_code]
        currency_code ||= currency(options[:amount]) if options[:amount]
        transaction_search_optional_fields = %w{ Payer ReceiptID Receiver
                                                 TransactionID InvoiceID CardNumber
                                                 AuctionItemNumber TransactionClass
                                                 CurrencyCode Status ProfileID }
        build_request_wrapper('TransactionSearch') do |xml|
          xml.tag! 'StartDate', date_to_iso(options[:start_date])
          xml.tag! 'EndDate', date_to_iso(options[:end_date]) unless options[:end_date].blank?
          add_optional_fields(xml, transaction_search_optional_fields, options)
          xml.tag! 'Amount', localized_amount(options[:amount], currency_code), 'currencyID' => currency_code  unless options[:amount].blank?
        end
      end


      def build_get_balance(return_all_currencies)
        build_request_wrapper('GetBalance') do |xml|
          xml.tag! 'ReturnAllCurrencies', return_all_currencies unless return_all_currencies.nil?
        end
      end

      def parse(action, xml)
        legacy_hash = legacy_parse(action, xml)
        xml = strip_attributes(xml)
        hash = Hash.from_xml(xml)
        hash = hash.fetch('Envelope').fetch('Body').fetch("#{action}Response")
        hash = hash["#{action}ResponseDetails"] if hash["#{action}ResponseDetails"]

        legacy_hash.merge(hash)
      rescue IndexError
        legacy_hash.merge(hash['Envelope']['Body'])
      end

      def strip_attributes(xml)
        xml = REXML::Document.new(xml)
        REXML::XPath.each(xml, '//SOAP-ENV:Envelope//*[@*]') do |el|
          el.attributes.each_attribute { |a| a.remove }
        end
        xml.to_s
      end

      def legacy_parse(action, xml)
        response = {}

        error_messages = []
        error_codes = []

        xml = REXML::Document.new(xml)
        if root = REXML::XPath.first(xml, "//#{action}Response")
          root.elements.each do |node|
            case node.name
            when 'Errors'
              short_message = nil
              long_message = nil

              node.elements.each do |child|
                case child.name
                when "LongMessage"
                  long_message = child.text unless child.text.blank?
                when "ShortMessage"
                  short_message = child.text unless child.text.blank?
                when "ErrorCode"
                  error_codes << child.text unless child.text.blank?
                end
              end

              if message = long_message || short_message
                error_messages << message
              end
            else
              legacy_parse_element(response, node)
            end
          end
          response[:message] = error_messages.uniq.join(". ") unless error_messages.empty?
          response[:error_codes] = error_codes.uniq.join(",") unless error_codes.empty?
        elsif root = REXML::XPath.first(xml, "//SOAP-ENV:Fault")
          legacy_parse_element(response, root)
          response[:message] = "#{response[:faultcode]}: #{response[:faultstring]} - #{response[:detail]}"
        end

        response
      end

      def legacy_parse_element(response, node)
        if node.has_elements?
          node.elements.each{|e| legacy_parse_element(response, e) }
        else
          response[node.name.underscore.to_sym] = node.text
          node.attributes.each do |k, v|
            response["#{node.name.underscore}_#{k.underscore}".to_sym] = v if k == 'currencyID'
          end
        end
      end

      def build_request(body)
        xml = Builder::XmlMarkup.new

        xml.instruct!
        xml.tag! 'env:Envelope', ENVELOPE_NAMESPACES do
          xml.tag! 'env:Header' do
            add_credentials(xml) unless @options[:headers] && @options[:headers]['X-PP-AUTHORIZATION']
          end

          xml.tag! 'env:Body' do
            xml << body
          end
        end
        xml.target!
      end

      def add_credentials(xml)
        xml.tag! 'RequesterCredentials', CREDENTIALS_NAMESPACES do
          xml.tag! 'n1:Credentials' do
            xml.tag! 'n1:Username', @options[:login]
            xml.tag! 'n1:Password', @options[:password]
            xml.tag! 'n1:Subject', @options[:subject]
            xml.tag! 'n1:Signature', @options[:signature] unless @options[:signature].blank?
          end
        end
      end

      def add_address(xml, element, address)
        return if address.nil?
        xml.tag! element do
          xml.tag! 'n2:Name', address[:name]
          xml.tag! 'n2:Street1', address[:address1]
          xml.tag! 'n2:Street2', address[:address2]
          xml.tag! 'n2:CityName', address[:city]
          xml.tag! 'n2:StateOrProvince', address[:state].blank? ? 'N/A' : address[:state]
          xml.tag! 'n2:Country', address[:country]
          xml.tag! 'n2:Phone', address[:phone] unless address[:phone].blank?
          xml.tag! 'n2:PostalCode', address[:zip]
        end
      end

      def add_payment_details_items_xml(xml, options, currency_code)
        options[:items].each do |item|
          xml.tag! 'n2:PaymentDetailsItem' do
            xml.tag! 'n2:Name', item[:name]
            xml.tag! 'n2:Number', item[:number]
            xml.tag! 'n2:Quantity', item[:quantity]
            if item[:amount]
              xml.tag! 'n2:Amount', item_amount(item[:amount], currency_code), 'currencyID' => currency_code
            end
            xml.tag! 'n2:Description', item[:description]
            xml.tag! 'n2:ItemURL', item[:url]
            xml.tag! 'n2:ItemCategory', item[:category] if item[:category]
          end
        end
      end

      def add_payment_details(xml, money, currency_code, options = {})
        xml.tag! 'n2:PaymentDetails' do
          xml.tag! 'n2:OrderTotal', localized_amount(money, currency_code), 'currencyID' => currency_code

          # All of the values must be included together and add up to the order total
          if [:subtotal, :shipping, :handling, :tax].all?{ |o| options.has_key?(o) }
            xml.tag! 'n2:ItemTotal', localized_amount(options[:subtotal], currency_code), 'currencyID' => currency_code
            xml.tag! 'n2:ShippingTotal', localized_amount(options[:shipping], currency_code),'currencyID' => currency_code
            xml.tag! 'n2:HandlingTotal', localized_amount(options[:handling], currency_code),'currencyID' => currency_code
            xml.tag! 'n2:TaxTotal', localized_amount(options[:tax], currency_code), 'currencyID' => currency_code
          end

          xml.tag! 'n2:InsuranceTotal', localized_amount(options[:insurance_total], currency_code),'currencyID' => currency_code unless options[:insurance_total].blank?
          xml.tag! 'n2:ShippingDiscount', localized_amount(options[:shipping_discount], currency_code),'currencyID' => currency_code unless options[:shipping_discount].blank?
          xml.tag! 'n2:InsuranceOptionOffered', options[:insurance_option_offered] if options.has_key?(:insurance_option_offered)

          xml.tag! 'n2:OrderDescription', options[:description] unless options[:description].blank?

          # Custom field Character length and limitations: 256 single-byte alphanumeric characters
          xml.tag! 'n2:Custom', options[:custom] unless options[:custom].blank?

          xml.tag! 'n2:InvoiceID', (options[:order_id] || options[:invoice_id]) unless (options[:order_id] || options[:invoice_id]).blank?
          xml.tag! 'n2:ButtonSource', application_id.to_s.slice(0,32) unless application_id.blank?

          # The notify URL applies only to DoExpressCheckoutPayment.
          # This value is ignored when set in SetExpressCheckout or GetExpressCheckoutDetails
          xml.tag! 'n2:NotifyURL', options[:notify_url] unless options[:notify_url].blank?

          add_address(xml, 'n2:ShipToAddress', options[:shipping_address]) unless options[:shipping_address].blank?

          add_payment_details_items_xml(xml, options, currency_code) unless options[:items].blank?

          add_express_only_payment_details(xml, options) if options[:express_request]

          # Any value other than Y – This is not a recurring transaction
          # To pass Y in this field, you must have established a billing agreement with
          # the buyer specifying the amount, frequency, and duration of the recurring payment.
          # requires version 80.0 of the API
          xml.tag! 'n2:Recurring', options[:recurring] unless options[:recurring].blank?
        end
      end

      def add_express_only_payment_details(xml, options = {})
        add_optional_fields(xml,
                            %w{n2:NoteText          n2:SoftDescriptor
                               n2:TransactionId     n2:AllowedPaymentMethodType
                               n2:PaymentRequestID  n2:PaymentAction},
                            options)
      end

      def add_optional_fields(xml, optional_fields, options = {})
        optional_fields.each do |optional_text_field|
          if optional_text_field =~ /(\w+:)(\w+)/
            ns = $1
            field = $2
            field_as_symbol = field.underscore.to_sym
          else
            ns = ''
            field = optional_text_field
            field_as_symbol = optional_text_field.underscore.to_sym
          end
          xml.tag! ns + field, options[field_as_symbol] unless options[field_as_symbol].blank?
        end
        xml
      end

      def endpoint_url
        URLS[test? ? :test : :live][@options[:signature].blank? ? :certificate : :signature]
      end

      def commit(action, request)
        response = parse(action, ssl_post(endpoint_url, build_request(request), @options[:headers]))

        build_response(successful?(response), message_from(response), response,
          :test => test?,
          :authorization => authorization_from(response),
          :fraud_review => fraud_review?(response),
          :avs_result => { :code => response[:avs_code] },
          :cvv_result => response[:cvv2_code]
        )
      end

      def fraud_review?(response)
        response[:error_codes] == FRAUD_REVIEW_CODE
      end

      def authorization_from(response)
        (
          response[:transaction_id] ||
          response[:authorization_id] ||
          response[:refund_transaction_id] ||
          response[:billing_agreement_id]
        )
      end

      def successful?(response)
        SUCCESS_CODES.include?(response[:ack])
      end

      def message_from(response)
        response[:message] || response[:ack]
      end

      def date_to_iso(date)
        (date.is_a?(Date) ? date.to_time : date).utc.iso8601
      end

      def item_amount(amount, currency_code)
        if amount.to_i < 0 && Gateway.non_fractional_currency?(currency_code)
          amount(amount).to_f.floor
        else
          localized_amount(amount, currency_code)
        end
      end
    end
  end
end
