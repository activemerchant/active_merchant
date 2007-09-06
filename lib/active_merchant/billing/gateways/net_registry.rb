#
# Gateway for netregistry.com.au.
#
# Note that NetRegistry itself uses gateway service providers.  At the
# time of this writing, there are at least two (Quest and Ingenico).
# This module has only been tested with Quest.
#
# Also note that NetRegistry does not offer a test mode, nor does it
# have support for the authorize/capture/void functionality by default
# (you may arrange for this as described in "Programming for
# NetRegistry's E-commerce Gateway." [http://rubyurl.com/hNG]), and no
# #void functionality is documented.  As a result, the #authorize and
# #capture have not yet been tested through a live gateway, and #void
# will raise an error.
#
# If you have this functionality enabled, please consider contributing
# to ActiveMerchant by writing tests/code for these methods, and
# submitting a patch.
#
# In addition to the standard ActiveMerchant functionality, the
# response will contain a 'receipt' parameter
# (response.params['receipt']) if a receipt was issued by the gateway.
# Also, a logger may be provided when instantiating the gateway to log
# all data sent to/from the gateway (with sensitive information
# hidden).
#
module ActiveMerchant
  module Billing
    class NetRegistryGateway < Gateway
      LIVE_URL = 'https://4tknox.au.com/cgi-bin/themerchant.au.com/ecom/external2.pl'
      
      self.supported_countries = ['AU']
      
      # Note that support for Diners, Amex, and JCB require extra
      # steps in setting up your account, as detailed in
      # "Programming for NetRegistry's E-commerce Gateway."
      # [http://rubyurl.com/hNG]
      self.supported_cardtypes = [:visa, :master, :diners_club, :american_express, :jcb]
      self.display_name = 'NetRegistry'
      self.homepage_url = 'http://www.netregistry.com.au'
      
      # Create a new NetRegistry gateway.
      #
      # Options :login and :password must be given.
      #
      def initialize(options = {})
        requires!(options, :login, :password)
        @logger = options[:logger]
        @options = options
        super
      end

      #
      # A Logger object used to write extra debugging output to.  nil
      # for none.
      #
      attr_accessor :logger

      #
      # Note that #authorize and #capture only work if your account
      # vendor is St George, and if your account has been setup as
      # described in "Programming for NetRegistry's E-commerce
      # Gateway." [http://rubyurl.com/hNG]
      #
      def authorize(money, credit_card, options = {})
        post(options[:description],
             'COMMAND' => 'preauth',
             'AMOUNT'  => amount(money),
             'CCNUM'   => credit_card.number,
             'CCEXP'   => expiry(credit_card))
      end

      #
      # Note that #authorize and #capture only work if your account
      # vendor is St George, and if your account has been setup as
      # described in "Programming for NetRegistry's E-commerce
      # Gateway." [http://rubyurl.com/hNG]
      #
      def capture(money, authorization, options = {})
        credit_card = options[:credit_card]
        post(options[:description],
             'COMMAND'    => 'completion',
             'PREAUTHNUM' => authorization,
             'AMOUNT'     => amount(money),
             'CCNUM'      => credit_card.number,
             'CCEXP'      => expiry(credit_card))
      end

      def purchase(money, credit_card, options = {})
        post(options[:description],
             'COMMAND' => 'purchase',
             'AMOUNT'  => amount(money),
             'CCNUM'   => credit_card.number,
             'CCEXP'   => expiry(credit_card))
      end

      def credit(money, identification, options = {})
        post(options[:description],
             'COMMAND' => 'refund',
             'AMOUNT'  => amount(money),
             'TXNREF'  => identification)
      end
      
      # Specific to NetRegistry.
      #
      # Run a 'status' command.  This lets you view the status of a
      # completed transaction.
      #
      def status(identification)
        post(options[:description],
             'COMMAND' => 'status',
             'TXNREF'  => identification)
      end

      private  # -----------------------------------------------------

      #
      # Return the expiry for the given creditcard in the required
      # format for a command.
      #
      def expiry(credit_card)
        month = format(credit_card.month, :two_digits)
        year  = format(credit_card.year , :two_digits)
        "#{month}/#{year}"
      end

      #
      # Post the a request with the given parameters and return the
      # response object.
      #
      # Login and password are added automatically, and the comment is
      # omitted if nil.
      #
      def post(comment, keyvals)
        if result = test_result_from_cc_number(keyvals['CCNUM'])
          return result
        end
        
        log "Executing #{keyvals['COMMAND']}:"
        login    = @options[:login]
        password = @options[:password]

        # make query
        keyvals['COMMENT'] = comment if comment
        keyvals['LOGIN'] = "#{login}/#{password}"
        str = URI.encode(keyvals.map{|k,v| "#{k}=#{v}"}.join('&'))
        log "  ActiveMerchant/NetRegistry: sending: #{obscure_send_string(str)}"

        # get gateway response
        text = ssl_post(LIVE_URL, str)
        log "  ActiveMerchant/NetRegistry: received:"
        obscure_recv_string(text).each do |line|
          log "    #{line}"
        end

        # make response object
        response = parse_response(text, keyvals['COMMAND'])

        return response
      end

      #
      # Parse the text returned from the gateway into a Response object.
      #
      def parse_response(text, command)
        params = {'original_text' => text}
        sio = StringIO.new(text)
        params['status'] = sio.gets.chomp
        params['rrn'] = sio.gets.chomp

        if sio.eof?
          # some short errors have nothing else, e.g., "Invalid expiry
          # format"
          message = params.delete('rrn')
          return Response.new(false, message, params)
        end

        # parse receipt
        receipt = ''
        while (line = sio.gets)
          break if line.strip == '.'
          receipt << line
        end

        # parse params
        while (line = sio.gets)
          line.chomp!
          key, val = line.split(/=/, 2)
          params[key] = val
        end

        params['receipt'] = receipt
        authorization =
          case command
          when 'purchase'
            params['txn_ref']
          when 'preauth'
            params['transaction_no']
          else
            nil
          end

        Response.new(params['status'] == 'approved',
                     params['response_text'],
                     params,
                     :authorization => authorization)
      end

      #
      # Log a message if logging is enabled.
      #
      def log(msg)
        logger.info(msg.chomp) unless logger.nil?
      end

      #
      # Return a copy of the given string (to be sent to the gateway),
      # with sensitive information hidden.
      #
      def obscure_send_string(string)
        string.gsub(/LOGIN=[^&]+/) do |keyval|
          keyval.sub(/[^\/]+\z/){|pass| '*'*pass.size}
        end.gsub(/CCNUM=[^&]+/) do |keyval|
          keyval.sub(/[^=]+\z/){|num| obscure_card_number(num)}
        end.gsub(/CCEXP=[^&]+/) do |keyval|
          keyval.sub(/[^=]+\z/){|num| obscure_card_expiry(num)}
        end
      end

      #
      # Return a copy of the given string (received from the gateway),
      # with sensitive information hidden.
      #
      def obscure_recv_string(string)
        string.
          gsub(/(card_(?:no|number)=)(.*)$/){$1 << obscure_card_number($2)}.
          gsub(/(card_expiry=)(.*)$/){$1 << obscure_card_expiry($2)}
      end

      #
      # Obscure a credit card number.
      #
      def obscure_card_number(number)
        return number if number.size < 4
        number[0...-4] = '*'*(number.size-4)
        return number
      end

      #
      # Obscure a credit card expiry.
      #
      def obscure_card_expiry(expiry)
        expiry.gsub(/\d/, '*')
      end
    end
  end
end
