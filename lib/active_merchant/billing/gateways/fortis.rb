module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class FortisGateway < Gateway
      self.test_url = 'https://api.sandbox.fortis.tech/v1'
      self.live_url = 'https://api.fortis.tech/v1'

      self.supported_countries = %w{US CA}
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover jbc unionpay]
      self.money_format = :cents
      self.homepage_url = 'https://fortispay.com'
      self.display_name = 'Fortis'

      STATUS_MAPPING = {
        101 => 'Sale cc Approved',
        102 => 'Sale cc AuthOnly',
        111 => 'Refund cc Refunded',
        121 => 'Credit/Debit/Refund cc AvsOnly',
        131 => 'Credit/Debit/Refund ach Pending Origination',
        132 => 'Credit/Debit/Refund ach Originating',
        133 => 'Credit/Debit/Refund ach Originated',
        134 => 'Credit/Debit/Refund ach Settled',
        191 => 'Settled (deprecated - batches are now settled on the /v2/transactionbatches endpoint)',
        201 => 'All cc/ach Voided',
        301 => 'All cc/ach Declined',
        331 => 'Credit/Debit/Refund ach Charged Back'
      }

      REASON_MAPPING = {
        0 => 'N/A',
        1000 => 'CC - Approved / ACH - Accepted',
        1001 => 'AuthCompleted',
        1002 => 'Forced',
        1003 => 'AuthOnly Declined',
        1004 => 'Validation Failure (System Run Trx)',
        1005 => 'Processor Response Invalid',
        1200 => 'Voided',
        1201 => 'Partial Approval',
        1240 => 'Approved, optional fields are missing (Paya ACH only)',
        1301 => 'Account Deactivated for Fraud',
        1500 => 'Generic Decline',
        1510 => 'Call',
        1518 => 'Transaction Not Permitted - Terminal',
        1520 => 'Pickup Card',
        1530 => 'Retry Trx',
        1531 => 'Communication Error',
        1540 => 'Setup Issue, contact Support',
        1541 => 'Device is not signature capable',
        1588 => 'Data could not be de-tokenized',
        1599 => 'Other Reason',
        1601 => 'Generic Decline',
        1602 => 'Call',
        1603 => 'No Reply',
        1604 => 'Pickup Card - No Fraud',
        1605 => 'Pickup Card - Fraud',
        1606 => 'Pickup Card - Lost',
        1607 => 'Pickup Card - Stolen',
        1608 => 'Account Error',
        1609 => 'Already Reversed',
        1610 => 'Bad PIN',
        1611 => 'Cashback Exceeded',
        1612 => 'Cashback Not Available',
        1613 => 'CID Error',
        1614 => 'Date Error',
        1615 => 'Do Not Honor',
        1616 => 'NSF',
        1618 => 'Invalid Service Code',
        1619 => 'Exceeded activity limit',
        1620 => 'Violation',
        1621 => 'Encryption Error',
        1622 => 'Card Expired',
        1623 => 'Renter',
        1624 => 'Security Violation',
        1625 => 'Card Not Permitted',
        1626 => 'Trans Not Permitted',
        1627 => 'System Error',
        1628 => 'Bad Merchant ID',
        1629 => 'Duplicate Batch (Already Closed)',
        1630 => 'Batch Rejected',
        1631 => 'Account Closed',
        1632 => 'PIN tries exceeded',
        1640 => 'Required fields are missing (ACH only)',
        1641 => 'Previously declined transaction (1640)',
        1650 => 'Contact Support',
        1651 => 'Max Sending - Throttle Limit Hit (ACH only)',
        1652 => 'Max Attempts Exceeded',
        1653 => 'Contact Support',
        1654 => 'Voided - Online Reversal Failed',
        1655 => 'Decline (AVS Auto Reversal)',
        1656 => 'Decline (CVV Auto Reversal)',
        1657 => 'Decline (Partial Auth Auto Reversal)',
        1658 => 'Expired Authorization',
        1659 => 'Declined - Partial Approval not Supported',
        1660 => 'Bank Account Error, please delete and re-add Token',
        1661 => 'Declined AuthIncrement',
        1662 => 'Auto Reversal - Processor cant settle',
        1663 => 'Manager Needed (Needs override transaction)',
        1664 => 'Token Not Found: Sharing Group Unavailable',
        1665 => 'Contact Not Found: Sharing Group Unavailable',
        1666 => 'Amount Error',
        1667 => 'Action Not Allowed in Current State',
        1668 => 'Original Authorization Not Valid',
        1701 => 'Chip Reject',
        1800 => 'Incorrect CVV',
        1801 => 'Duplicate Transaction',
        1802 => 'MID/TID Not Registered',
        1803 => 'Stop Recurring',
        1804 => 'No Transactions in Batch',
        1805 => 'Batch Does Not Exist'
      }

      def initialize(options = {})
        requires!(options, :user_id, :user_api_key, :developer_id)
        super
      end

      def authorize(money, payment, options = {})
        commit path(:authorize, payment_type(payment)), auth_purchase_request(money, payment, options)
      end

      def purchase(money, payment, options = {})
        commit path(:purchase, payment_type(payment)), auth_purchase_request(money, payment, options)
      end

      def capture(money, authorization, options = {})
        commit path(:capture, authorization), { transaction_amount: money }, :patch
      end

      def void(authorization, options = {})
        commit path(:void, authorization), {}, :put
      end

      def refund(money, authorization, options = {})
        commit path(:refund, authorization), { transaction_amount: money }, :patch
      end

      def credit(money, payment, options = {})
        commit path(:credit), auth_purchase_request(money, payment, options)
      end

      def store(payment, options = {})
        post = {}
        add_payment(post, payment, include_cvv: false)
        add_address(post, payment, options)

        commit path(:store), post
      end

      def unstore(authorization, options = {})
        commit path(:unstore, authorization), nil, :delete
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(\\?"account_number\\?":\\?")\d+/, '\1[FILTERED]').
          gsub(/(\\?"cvv\\?":\\?")\d+/, '\1[FILTERED]').
          gsub(%r((user-id: )[\w =]+), '\1[FILTERED]').
          gsub(%r((user-api-key: )[\w =]+), '\1[FILTERED]').
          gsub(%r((developer-id: )[\w =]+), '\1[FILTERED]')
      end

      private

      def path(action, value = '')
        {
          authorize: '/transactions/cc/auth-only/{placeholder}',
          purchase: '/transactions/cc/sale/{placeholder}',
          capture: '/transactions/{placeholder}/auth-complete',
          void: '/transactions/{placeholder}/void',
          refund: '/transactions/{placeholder}/refund',
          credit: '/transactions/cc/refund/keyed',
          store: '/tokens/cc',
          unstore: '/tokens/{placeholder}'
        }[action]&.gsub('{placeholder}', value.to_s)
      end

      def payment_type(payment)
        payment.is_a?(String) ? 'token' : 'keyed'
      end

      def auth_purchase_request(money, payment, options = {})
        {}.tap do |post|
          add_invoice(post, money, options)
          add_payment(post, payment)
          add_address(post, payment, options)
        end
      end

      def add_address(post, payment_method, options)
        address = address_from_options(options)
        return unless address.present?

        post[:billing_address] = {
          postal_code: address[:zip],
          street: address[:address1],
          city: address[:city],
          state: address[:state],
          phone: address[:phone],
          country: lookup_country_code(address[:country])
        }.compact
      end

      def address_from_options(options)
        options[:billing_address] || options[:address] || {}
      end

      def lookup_country_code(country_field)
        return unless country_field.present?

        country_code = Country.find(country_field)
        country_code&.code(:alpha3)&.value
      end

      def add_invoice(post, money, options)
        post[:transaction_amount] = amount(money)
        post[:order_number] = options[:order_id]
        post[:transaction_api_id] = options[:order_id]
        post[:notification_email_address] = options[:email]
      end

      def add_payment(post, payment, include_cvv: true)
        case payment
        when CreditCard
          post[:account_number] = payment.number
          post[:exp_date] = expdate(payment)
          post[:cvv] = payment.verification_value if include_cvv
          post[:account_holder_name] = payment.name
        when String
          post[:token_id] = payment
        end
      end

      def parse(body)
        JSON.parse(body).with_indifferent_access
      rescue JSON::ParserError, TypeError => e
        {
          errors: body,
          status: 'Unable to parse JSON response',
          message: e.message
        }.with_indifferent_access
      end

      def request_headers
        CaseSensitiveHeaders.new.reverse_merge!({
          'Accept' => 'application/json',
          'Content-Type' => 'application/json',
          'user-id' => @options[:user_id],
          'user-api-key' => @options[:user_api_key],
          'developer-id' => @options[:developer_id]
        })
      end

      def add_location_id(post, options)
        post[:location_id] = @options[:location_id] || options[:location_id]
      end

      def commit(path, post, method = :post, options = {})
        add_location_id(post, options) if post.present?

        http_code, raw_response = ssl_request(method, url(path), post&.compact&.to_json, request_headers)
        response = parse(raw_response)

        Response.new(
          success_from(http_code, response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response.dig(:data, :avs_enhanced)),
          cvv_result: CVVResult.new(response.dig(:data, :cvv_response)),
          test: test?,
          error_code: error_code_from(http_code, response)
        )
      rescue ResponseError => e
        response = parse(e.response.body)
        Response.new(false, message_from(response), response, test: test?)
      end

      def handle_response(response)
        case response.code.to_i
        when 200...300
          return response.code.to_i, response.body
        else
          raise ResponseError.new(response)
        end
      end

      def url(path)
        "#{test? ? test_url : live_url}#{path}"
      end

      def success_from(http_code, response)
        return true if http_code == 204
        return response[:data][:active] == true if response[:type] == 'Token'
        return false if response.dig(:data, :status_code) == 301

        STATUS_MAPPING[response.dig(:data, :status_code)].present?
      end

      def message_from(response)
        return '' if response.blank?

        response[:type] == 'Error' ? error_message_from(response) : success_message_from(response)
      end

      def error_message_from(response)
        response[:detail] || response[:title]
      end

      def success_message_from(response)
        response.dig(:data, :verbiaje) || get_reason_description_from(response) || STATUS_MAPPING[response.dig(:data, :status_code)] || response.dig(:data, :status_code)
      end

      def get_reason_description_from(response)
        code_id = response.dig(:data, :reason_code_id)
        REASON_MAPPING[code_id] || ((1302..1399).include?(code_id) ? 'Reserved for Future Fraud Reason Codes' : nil)
      end

      def authorization_from(response)
        response.dig(:data, :id)
      end

      def error_code_from(http_code, response)
        [response.dig(:data, :status_code), response.dig(:data, :reason_code_id)].compact.join(' - ') unless success_from(http_code, response)
      end
    end
  end
end
