module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # === EVO Canada payment gateway.
    #
    # EVO returns two different identifiers for most transactions, the
    # +authcode+ and the +transactionid+.  Since +transactionid+ is used more
    # often (i.e. for {#capture}, {#refund}, {#void} and {#update}) we store it in the
    # Response#authorization attribute.  The +authcode+ from the merchant
    # account is accessible via {Response#params}.
    #
    # Two different but related response messages are also returned from EVO.
    # The message indicated by EVO's <tt>response_code</tt> parameter is returned as
    # {Response#message} (Those messages can be seen in the {MESSAGES} hash.)
    # The other, shorter message is available via {Response#params}.
    #
    # It's recommended to save the contents of the {Response#params} in your
    # transaction log for future reference.
    #
    # === Sample Use
    #
    #    gateway = ActiveMerchant::Billing::EvoCaGateway.new(username: 'demo', password: 'password')
    #
    #    response = gateway.authorize(1000, credit_card, options)
    #
    #    puts response.authorization          # the transactionid
    #    puts response.params['authcode']     # the authcode from the merchant account
    #    puts response.message                # the 'pretty' response message
    #    puts response.params['responsetext'] # the 'terse' response message
    #
    #    gateway.capture(1000, response.authorization)
    #    gateway.update(response.authorization, shipping_carrier: 'fedex')
    #    gateway.refund(500, response.authorization)
    #
    class EvoCaGateway < Gateway
      self.test_url = 'https://secure.evoepay.com/api/transact.php'
      self.live_url = 'https://secure.evoepay.com/api/transact.php'

      self.supported_countries  = ['CA']
      self.supported_cardtypes  = %i[visa master american_express jcb discover]
      self.money_format         = :dollars
      self.homepage_url         = 'http://www.evocanada.com/'
      self.display_name         = 'EVO Canada'

      APPROVED, DECLINED, ERROR = 1, 2, 3

      MESSAGES = {
        100 => 'Transaction was approved',
        200 => 'Transaction was declined by processor',
        201 => 'Do not honor',
        202 => 'Insufficient funds',
        203 => 'Over limit',
        204 => 'Transaction not allowed',
        220 => 'Incorrect payment data',
        221 => 'No such card issuer',
        222 => 'No card number on file with issuer',
        223 => 'Expired card',
        224 => 'Invalid expiration date',
        225 => 'Invalid card security code',
        240 => 'Call issuer for futher information',
        250 => 'Pick up card',
        251 => 'Lost card',
        252 => 'Stolen card',
        253 => 'Fraudulant card',
        260 => 'Declined with further instructions available',
        261 => 'Declined - stop all recurring payments',
        262 => 'Declined - stop this recurring program',
        263 => 'Declined - updated cardholder data available',
        264 => 'Declined - retry in a few days',
        300 => 'Transaction was rejected by gateway',
        400 => 'Transaction error returned by processor',
        410 => 'Invalid merchant configuration',
        411 => 'Merchant account is inactive',
        420 => 'Communication error',
        421 => 'Communication error with issuer',
        430 => 'Duplicate transaction at processor',
        440 => 'Processor format error',
        441 => 'Invalid transaction information',
        460 => 'Processor feature not available',
        461 => 'Unsupported card type'
      }

      # This gateway requires that a valid username and password be passed
      # in the +options+ hash.
      #
      # === Required Options
      #
      # * <tt>:username</tt>
      # * <tt>:password</tt>
      def initialize(options = {})
        requires!(options, :username, :password)
        super
      end

      # Transaction sales are submitted and immediately flagged for settlement.
      # These transactions will automatically be settled.
      #
      # Payment source can be either a {CreditCard} or {Check}.
      #
      # === Additional Options
      # In addition to the standard options, this gateway supports
      #
      # * <tt>:tracking_number</tt> - Shipping tracking number
      # * <tt>:shipping_carrier</tt> - ups/fedex/dhl/usps
      # * <tt>:po_number</tt> - Purchase order
      # * <tt>:tax</tt> - Tax amount
      # * <tt>:shipping</tt> - Shipping cost
      def purchase(money, credit_card_or_check, options = {})
        post = {}
        add_invoice(post, options)
        add_order(post, options)
        add_paymentmethod(post, credit_card_or_check)
        add_address(post, options)
        add_customer_data(post, options)
        commit('sale', money, post)
      end

      # Transaction authorizations are authorized immediately but are not
      # flagged for settlement. These transactions must be flagged for
      # settlement using the _capture_ transaction type. Authorizations
      # typically remain activate for three to seven business days.
      #
      # Payment source must be a {CreditCard}.
      def authorize(money, credit_card, options = {})
        post = {}
        add_invoice(post, options)
        add_order(post, options)
        add_paymentmethod(post, credit_card)
        add_address(post, options)
        add_customer_data(post, options)
        commit('auth', money, post)
      end

      # Transaction captures flag existing _authorizations_ for settlement. Only
      # authorizations can be captured. Captures can be submitted for an amount
      # equal to or less than the original authorization.
      #
      # The <tt>authorization</tt> parameter is the transaction ID, retrieved
      # from Response#authorization. See EvoCaGateway#purchase for the
      # <tt>options</tt>.
      def capture(money, authorization, options = {})
        post = {
          amount: amount(money),
          transactionid: authorization
        }
        add_order(post, options)
        commit('capture', money, post)
      end

      # Transaction refunds will reverse a previously settled transaction. If
      # the transaction has not been settled, it must be _voided_ instead of
      # refunded.
      #
      # The <tt>identification</tt> parameter is the transaction ID, retrieved
      # from {Response#authorization}.
      def refund(money, identification)
        post = {transactionid: identification}
        commit('refund', money, post)
      end

      # Transaction credits apply a negative amount to the cardholder's card.
      # In most situations credits are disabled as transaction refunds should
      # be used instead.
      #
      # Note that this is different from a {#refund} (which is usually what
      # you'll be looking for).
      def credit(money, credit_card, options = {})
        post = {}
        add_invoice(post, options)
        add_order(post, options)
        add_paymentmethod(post, credit_card)
        add_address(post, options)
        add_customer_data(post, options)
        commit('credit', money, post)
      end

      # Transaction voids will cancel an existing sale or captured
      # authorization. In addition, non-captured authorizations can be voided to
      # prevent any future capture. Voids can only occur if the transaction has
      # not been settled.
      #
      # The <tt>identification</tt> parameter is the transaction ID, retrieved
      # from {Response#authorization}.
      def void(identification)
        post = {transactionid: identification}
        commit('void', nil, post)
      end

      # Transaction updates can be used to update previous transactions with
      # specific order information, such as a tracking number and shipping
      # carrier. See EvoCaGateway#purchase for <tt>options</tt>.
      #
      # The <tt>identification</tt> parameter is the transaction ID, retrieved
      # from {Response#authorization}.
      def update(identification, options)
        post = {transactionid: identification}
        add_order(post, options)
        commit('update', nil, post)
      end

      private

      def add_customer_data(post, options)
        post[:email]      = options[:email]
        post[:ipaddress]  = options[:ip]
      end

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:firstname]    = address[:first_name]
          post[:lastname]     = address[:last_name]
          post[:address1]     = address[:address1]
          post[:address2]     = address[:address2]
          post[:company]      = address[:company]
          post[:phone]        = address[:phone]
          post[:city]         = address[:city]
          post[:state]        = address[:state]
          post[:zip]          = address[:zip]
          post[:country]      = address[:country]
        end

        if address = options[:shipping_address]
          post[:shipping_firstname]   = address[:first_name]
          post[:shipping_lastname]    = address[:last_name]
          post[:shipping_address1]    = address[:address1]
          post[:shipping_address2]    = address[:address2]
          post[:shipping_company]     = address[:company]
          post[:shipping_zip]         = address[:zip]
          post[:shipping_city]        = address[:city]
          post[:shipping_state]       = address[:state]
          post[:shipping_country]     = address[:country]
        end
      end

      def add_order(post, options)
        post[:orderid]          = options[:order_id]
        post[:tracking_number]  = options[:tracking_number]
        post[:shipping_carrier] = options[:shipping_carrier]
      end

      def add_invoice(post, options)
        post[:orderdescription] = options[:description]
        post[:ponumber]         = options[:po_number]
        post[:shipping]         = amount(options[:shipping])
        post[:tax]              = amount(options[:tax])
      end

      def add_paymentmethod(post, payment)
        if card_brand(payment) == 'check'
          post[:payment]              = 'check'
          post[:checkname]            = payment.name
          post[:checkaba]             = payment.routing_number
          post[:checkaccount]         = payment.account_number
          post[:account_holder_type]  = payment.account_holder_type
          post[:account_type]         = payment.account_type
        else
          post[:payment]  = 'creditcard'
          post[:ccnumber] = payment.number
          post[:ccexp]    = "#{format(payment.month, :two_digits)}#{format(payment.year, :two_digits)}"
          post[:cvv]      = payment.verification_value
        end
      end

      def parse(body)
        fields = {}
        CGI::parse(body).each do |k, v|
          fields[k.to_s] = v.kind_of?(Array) ? v[0] : v
        end
        fields
      end

      def success?(response)
        response['response'].to_i == APPROVED
      end

      def commit(action, money, parameters)
        parameters[:amount] = amount(money) unless action == 'void'

        data = ssl_post self.live_url, post_data(action, parameters)
        response = parse(data)
        message = message_from(response)

        Response.new(success?(response), message, response,
          test: test?,
          authorization: response['transactionid'],
          avs_result: { code: response['avsresponse'] },
          cvv_result: response['cvvresponse']
        )
      end

      def message_from(response)
        MESSAGES.fetch(response['response_code'].to_i, false) || response['message']
      end

      def post_data(action, parameters = {})
        post = {type: action}

        if test?
          post[:username] = 'demo'
          post[:password] = 'password'
        else
          post[:username] = options[:username]
          post[:password] = options[:password]
        end
        post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" unless value.nil? }.compact.join('&')
      end
    end
  end
end
