require File.dirname(__FILE__) + '/authorize_net'

module ActiveMerchant
  module Billing
    class AuthorizeNetCardPresentGateway < AuthorizeNetGateway
      # http://www.authorize.net/support/CP_guide.pdf
      API_VERSION = '1.0'
      
      self.test_url = 'https://test.authorize.net/gateway/transact.dll'
      self.live_url = 'https://cardpresent.authorize.net/gateway/transact.dll'
      
      # Only one supported market type
      MARKET_TYPE_RETAIL = 2
      
      # Device types
      DEVICE_TYPES = {
        :unknown => 1,
        :unattended_terminal => 2,
        :self_service_terminal => 3,
        :electronic_cash_register => 4,
        :pc_terminal => 5,
        :airpay => 6,
        :wireless_pos => 7,
        :website => 8,
        :dial_terminal => 9,
        :virtual_terminal => 10,
      }.freeze
      
      # These differ from AuthorizeNetGateway
      RESPONSE_CODE, RESPONSE_REASON_CODE, RESPONSE_REASON_TEXT = 1, 2, 3
      AUTHORIZATION_CODE, AVS_RESULT_CODE, CARD_CODE_RESPONSE_CODE, TRANSACTION_ID = 4, 5, 6, 7
      CARD_NUMBER, CARD_TYPE = 20, 21      

      # Perform a purchase, which is essentially an authorization and capture in a single operation.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be purchased as an Integer value in cents.
      # * <tt>creditcard</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      def purchase(money, creditcard, options = {track_type: 1})
        post = {}
        add_currency_code(post, money, options)
        add_invoice(post, options)
        add_creditcard(post, creditcard, options)
        add_address(post, options)
        add_customer_data(post, options)
        add_duplicate_window(post)

        commit('AUTH_CAPTURE', money, post)
      end

      # Captures the funds from an authorized transaction.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be captured.  Either an Integer value in cents or a Money object.
      # * <tt>authorization</tt> -- The authorization returned from the previous authorize request.
      def capture(money, authorization, options = {})
        post = {:ref_trans_id => authorization}
        add_customer_data(post, options)
        if test? && options[:mock_response] == true
          credit_card = CreditCard.new(:year => "15", :month => "01", :number => "4" + ("2" * 12))
          add_creditcard(post, credit_card)
        end
        commit('PRIOR_AUTH_CAPTURE', money, post)
      end

      # Void a previous transaction
      #
      # ==== Parameters
      #
      # * <tt>authorization</tt> - The authorization returned from the previous authorize request.
      def void(authorization, options = {})
        post = {:ref_trans_id => authorization}
        commit('VOID', nil, post)
      end

      # Refund an account.
      #
      # This transaction is also referred to as a Refund and indicates to the gateway that
      # money should flow from the merchant to the customer.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be refunded to the customer. Either an Integer value in cents or a Money object.
      # * <tt>identification</tt> -- The ID of the original transaction against which the refund is being issued.
      # * <tt>options</tt> -- A hash of parameters.
      #
      # ==== Options
      #
      # * <tt>:card_number</tt> -- The credit card number the refund is being issued to. (REQUIRED)
      def refund(money, identification, options = {})
        requires!(options, :card_number)

        post = { :ref_trans_id => identification,
                 :card_num => options[:card_number]
               }
        add_invoice(post, options)

        commit('CREDIT', money, post)
      end      

      def credit(money, identification, options = {})
        deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, identification, options)
      end
      
      private
      
      def commit(action, money, parameters)
        parameters[:amount] = amount(money) unless action == 'VOID'

        # Only activate the test_request when the :test option is passed in
        parameters[:test_request] = (@options[:test] || test?) ? 'TRUE' : 'FALSE'

        # Submit requests against the testing endpoint if the :test_url option is passed in 
        url = @options[:test_url].blank? ? self.live_url : self.test_url 

        data = ssl_post url, post_data(action, parameters)

        response = parse(data)

        message = message_from(response)

        # Return the response. The authorization can be taken out of the transaction_id
        # Test Mode on/off is something we have to parse from the response text.
        # It usually looks something like this
        #
        #   (TESTMODE) Successful Sale
        test_mode = test? || message =~ /TESTMODE/

        Response.new(success?(response), message, response, 
          :test => test_mode, 
          :authorization => response[:transaction_id],
          #:authorization_code => response[:authorization_code],
          :fraud_review => fraud_review?(response),
          :avs_result => { :code => response[:avs_result_code] },
          :cvv_result => response[:card_code]
        )
      end
         
      def parse(body)
        fields = split(body)

        results = {
          :response_code => fields[RESPONSE_CODE].to_i,
          :response_reason_code => fields[RESPONSE_REASON_CODE], 
          :response_reason_text => fields[RESPONSE_REASON_TEXT],
          :authorization_code => fields[AUTHORIZATION_CODE],
          :avs_result_code => fields[AVS_RESULT_CODE],
          :transaction_id => fields[TRANSACTION_ID],
          :card_code => fields[CARD_CODE_RESPONSE_CODE],
          :card_number => fields[CARD_NUMBER],
          :card_type => fields[CARD_TYPE]
        }
      end

      def post_data(action, parameters = {})
        post = {}

        post[:cpversion]        = API_VERSION
        post[:login]            = @options[:login]
        post[:tran_key]         = @options[:password]
        post[:market_type]      = MARKET_TYPE_RETAIL
        post[:device_type]      = @options[:device_type]
        post[:type]             = action
        post[:response_format]  = 1
        post[:delim_char]       = ","
        post[:encap_char]       = "$"

        request = post.merge(parameters).collect { |key, value| "x_#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end
      
      # http://www.gae.ucm.es/~padilla/extrawork/tracks.html
      def add_creditcard(post, creditcard, options={})
        super(post, creditcard)
        if options[:track_type] == 1
          post[:track1] = creditcard.track_data
        elsif options[:track_type] == 2
          post[:track2] = creditcard.track_data
        end
        if !post[:track1].blank? || !post[:track2].blank?
          post.delete :card_num
          post.delete :card_code
          post.delete :exp_date
        end
      end

      private

      def expdate(creditcard)
        if creditcard.year.blank? || creditcard.month.blank?
          return nil
        else
          super(creditcard)
        end
      end

    end
  end
end
