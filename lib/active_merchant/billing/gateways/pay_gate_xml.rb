require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This gateway accepts the following arguments:
    #   :login    => your PayJunction username
    #   :password => your PayJunction pass
    # Example use:
    #
    #   gateway = ActiveMerchant::Billing::Base.gateway(:pay_gate_xml).new(
    #               :login => "my_account",
    #               :password => "my_pass"
    #            )
    #
    #   # set up credit card obj as in main ActiveMerchant example
    #   creditcard = ActiveMerchant::Billing::CreditCard.new(
    #     :type       => 'visa',
    #     :number     => '4242424242424242',
    #     :month      => 8,
    #     :year       => 2009,
    #     :first_name => 'Bob',
    #     :last_name  => 'Bobsen'
    #   )
    #
    #   # run request
    #   response = gateway.purchase(1000, creditcard) # charge 10 dollars
    #
    # 1) Check whether the transaction was successful
    #
    #   response.success?
    #
    # 2) Retrieve the message returned by PayJunction
    #
    #   response.message
    #
    # 3) Retrieve the unique transaction ID returned by PayGateXML
    #
    #   response.authorization
    #
    # This gateway has many other features which are not implemented here yet
    # The basic setup here only supports auth/capture transactions.
    #
    # Test Transactions
    #
    # PayGateXML has a global test user/pass, but you can also sign up for your own.
    # The class and the test come equipped with the global test creds
    #
    # Usage Details
    #
    # Below is a map of only SOME of the values accepted by PayGateXML and how you should submit
    # each to ActiveMerchant
    #
    # PayGateXML Field        ActiveMerchant Use
    #
    # pgid                    use :login value to gateway instantiation
    # pwd                     use :password value to gateway instantiation
    #
    # cname                   credit_card.name
    # cc                      credit_card.number
    # exp                     credit_card values formatted to YYYYMMDD
    # budp                    South Africa only - set to 0 if purchase is not on budget
    # amt                     include as argument to method for your transaction type
    # ver                     do nothing, always set to current API version
    #
    # cref                    provide as :invoice in options, varchar(80)
    # cur                     3 char field, currently only ZAR
    # cvv                     credit_card.verification
    # bno                     batch processing number, i.e. you supply this
    #
    # others -- not used in this implementation
    # nurl, rurl - must remain blank or absent or they will use an alternative authentication mechanism
    # email, ip  - must remain blank or absent or they will use a PayGate extra service call PayProtector
    # threed     - must remain blank unless you are using your own 3D Secure server
    #
    class PayGateXmlGateway < Gateway
      self.live_url = 'https://www.paygate.co.za/payxml/process.trans'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = %w[US ZA]

      # The card types supported by the payment gateway
      self.supported_cardtypes = %i[visa master american_express diners_club]

      # The homepage URL of the gateway
      self.homepage_url = 'http://paygate.co.za/'

      # The name of the gateway
      self.display_name = 'PayGate PayXML'

      # PayGate only supports Rands
      self.default_currency = 'ZAR'

      # PayGate accepts only lowest denomination
      self.money_format = :cents

      # PayGateXML public test account - you can get a private one too
      TEST_ID_3DSECURE  = '10011013800'
      TEST_ID           = '10011021600'
      TEST_PWD          = 'test'

      API_VERSION = '4.0'

      DECLINE_CODES = {
        # Credit Card Errors - These RESULT_CODEs are returned if the transaction cannot be authorized due to a problem with the card.  The TRANSACTION_STATUS will be 2
        900001  => 'Call for Approval',
        900002  => 'Card Expired',
        900003  => 'Insufficient Funds',
        900004  => 'Invalid Card Number',
        900005  => 'Bank Interface Timeout', # indicates a communications failure between the banks systems
        900006  => 'Invalid Card',
        900007  => 'Declined',
        900009  => 'Lost Card',
        900010  => 'Invalid Card Length',
        900011  => 'Suspected Fraud',
        900012  => 'Card Reported As Stolen',
        900013  => 'Restricted Card',
        900014  => 'Excessive Card Usage',
        900015  => 'Card Blacklisted',

        900207  => 'Declined; authentication failed', # indicates the cardholder did not enter their MasterCard SecureCode / Verified by Visa password correctly

        990020  => 'Auth Declined',

        991001  => 'Invalid expiry date',
        991002  => 'Invalid amount',

        # Communication Errors - These RESULT_CODEs are returned if the transaction cannot be completed due to an unexpected error.  TRANSACTION_STATUS will be 0.
        900205  => 'Unexpected authentication result (phase 1)',
        900206  => 'Unexpected authentication result (phase 1)',

        990001  => 'Could not insert into Database',

        990022  => 'Bank not available',

        990053  => 'Error processing transaction',

        # Miscellaneous - Unless otherwise noted, the TRANSACTION_STATUS will be 0.
        900209  => 'Transaction verification failed (phase 2)', # Indicates the verification data returned from MasterCard SecureCode / Verified by Visa has been altered
        900210  => 'Authentication complete; transaction must be restarted', # Indicates that the MasterCard SecuerCode / Verified by Visa transaction has already been completed.  Most likely caused by the customer clicking the refresh button

        990024  => 'Duplicate Transaction Detected.  Please check before submitting',

        990028  => 'Transaction cancelled' # Customer clicks the 'Cancel' button on the payment page
      }

      SUCCESS_CODES = %w(990004 990005 990017 990012 990018 990031)

      TRANSACTION_CODES = {
        0 => 'Not Done',
        1 => 'Approved',
        2 => 'Declined',
        3 => 'Paid',
        4 => 'Refunded',
        5 => 'Received by PayGate',
        6 => 'Replied to Client'
      }

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, creditcard, options = {})
        MultiResponse.run do |r|
          r.process { authorize(money, creditcard, options) }
          r.process { capture(money, r.authorization, options) }
        end
      end

      def authorize(money, creditcard, options = {})
        action = 'authtx'

        options[:money] = money
        options[:creditcard] = creditcard
        commit(action, build_request(action, options))
      end

      def capture(money, authorization, options = {})
        action = 'settletx'

        options[:money] = money
        options[:authorization] = authorization
        commit(action, build_request(action, options), authorization)
      end

      def refund(money, authorization, options={})
        action = 'refundtx'

        options[:money] = money
        options[:authorization] = authorization
        commit(action, build_request(action, options))
      end

      private

      def successful?(response)
        SUCCESS_CODES.include?(response[:res])
      end

      def build_request(action, options={})
        xml = Builder::XmlMarkup.new
        xml.instruct!

        xml.tag! 'protocol', ver: API_VERSION, pgid: (test? ? TEST_ID : @options[:login]), pwd: @options[:password] do |protocol|
          money         = options.delete(:money)
          authorization = options.delete(:authorization)
          creditcard    = options.delete(:creditcard)
          case action
          when 'authtx'
            build_authorization(protocol, money, creditcard, options)
          when 'settletx'
            build_capture(protocol, money, authorization, options)
          when 'refundtx'
            build_refund(protocol, money, authorization, options)
          else
            raise 'no action specified for build_request'
          end
        end

        xml.target!
      end

      def build_authorization(xml, money, creditcard, options={})
        xml.tag! 'authtx', {
          cref: options[:order_id],
          cname: creditcard.name,
          cc: creditcard.number,
          exp: "#{format(creditcard.month, :two_digits)}#{format(creditcard.year, :four_digits)}",
          budp: 0,
          amt: amount(money),
          cur: (options[:currency] || currency(money)),
          cvv: creditcard.verification_value,
          email: options[:email],
          ip: options[:ip]
        }
      end

      def build_capture(xml, money, authorization, options={})
        xml.tag! 'settletx', {
          tid: authorization
        }
      end

      def build_refund(xml, money, authorization, options={})
        xml.tag! 'refundtx', {
          tid: authorization,
          amt: amount(money)
        }
      end

      def parse(action, body)
        hash  = {}
        xml   = REXML::Document.new(body)

        response_action = action.gsub(/tx/, 'rx')
        root  = REXML::XPath.first(xml.root, response_action)
        # we might have gotten an error
        root  = REXML::XPath.first(xml.root, 'errorrx') if root.nil?
        root.attributes.each do |name, value|
          hash[name.to_sym] = value
        end
        hash
      end

      def commit(action, request, authorization = nil)
        response = parse(action, ssl_post(self.live_url, request))
        Response.new(successful?(response), message_from(response), response,
          test: test?,
          authorization: authorization || response[:tid]
        )
      end

      def message_from(response)
        (response[:rdesc] || response[:edesc])
      end
    end
  end
end
