module ActiveMerchant
  module Billing
    class AuthorizeNetCardPresentGateway < AuthorizeNetGateway
      # http://www.authorize.net/support/CP_guide.pdf
      API_VERSION = '1.0'
      
      # There is no test-only endpoint
      self.test_url = 'https://cardpresent.authorize.net/gateway/transact.dll'
      self.live_url = 'https://cardpresent.authorize.net/gateway/transact.dll'

      # These differ from AuthorizeNetGateway
      RESPONSE_CODE, RESPONSE_REASON_CODE, RESPONSE_REASON_TEXT = 1, 2, 3
      AVS_RESULT_CODE, CARD_CODE_RESPONSE_CODE, TRANSACTION_ID  = 5, 6, 7
      
      # Captures the funds from an authorized transaction.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be captured.  Either an Integer value in cents or a Money object.
      # * <tt>authorization</tt> -- The authorization returned from the previous authorize request.
      def capture(money, authorization, options = {})
        post = {:ref_trans_id => authorization}
        add_customer_data(post, options)
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

      # Credit an account.
      #
      # This transaction is also referred to as a Refund and indicates to the gateway that
      # money should flow from the merchant to the customer.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be credited to the customer. Either an Integer value in cents or a Money object.
      # * <tt>identification</tt> -- The ID of the original transaction against which the credit is being issued.
      # * <tt>options</tt> -- A hash of parameters.
      #
      # ==== Options
      #
      # * <tt>:card_number</tt> -- The credit card number the credit is being issued to. (REQUIRED)
      def credit(money, identification, options = {})
        requires!(options, :card_number)

        post = { :ref_trans_id => identification,
                 :card_num => options[:card_number]
               }
        add_invoice(post, options)

        commit('CREDIT', money, post)
      end      
      
      private
      
      def parse(body)
        fields = split(body)

        results = {
          :response_code => fields[RESPONSE_CODE].to_i,
          :response_reason_code => fields[RESPONSE_REASON_CODE], 
          :response_reason_text => fields[RESPONSE_REASON_TEXT],
          :avs_result_code => fields[AVS_RESULT_CODE],
          :transaction_id => fields[TRANSACTION_ID],
          :card_code => fields[CARD_CODE_RESPONSE_CODE]
        }
        results
      end

      def post_data(action, parameters = {})
        post = {}

        post[:login]            = @options[:login]
        post[:tran_key]         = @options[:password]
        post[:cpversion]        = API_VERSION
        post[:type]             = action
        post[:response_format]  = 1
        post[:delim_char]       = ","
        post[:encap_char]       = "$"
        
        parameters[:test_request]     = test? ? 'TRUE' : 'FALSE'

        request = post.merge(parameters).collect { |key, value| "x_#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end
      
      # http://www.gae.ucm.es/~padilla/extrawork/tracks.html
      def add_creditcard(post, creditcard)
        super(post, creditcard)
        unless creditcard.track2.blank?
          post[:track2] = creditcard.track2
          post.delete :card_num
          post.delete :card_code
          post.delete :exp_date
        end
      end
    end
  end
end
