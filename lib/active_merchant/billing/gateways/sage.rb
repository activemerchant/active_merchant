require File.dirname(__FILE__) + '/sage/sage_bankcard'
require File.dirname(__FILE__) + '/sage/sage_virtual_check'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SageGateway < Gateway
      self.supported_cardtypes = SageBankcardGateway.supported_cardtypes
      
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end
      
      def authorize(money, credit_card, options = {})
        bankcard.authorize(money, credit_card, options)
      end
      
      def purchase(money, source, options = {})
        if source.type == "check"
          virtual_check.purchase(money, source, options)
        else
          bankcard.purchase(money, source, options)
        end
      end                       
    
      # The +money+ amount is not used. The entire amount of the 
      # initial authorization will be captured.
      def capture(money, reference, options = {})
        bankcard.capture(money, reference, options)
      end
      
      def void(reference, options = {})
        if reference.split(";").last == "virtual_check"
          virtual_check.void(reference, options)
        else
          bankcard.void(reference, options)
        end
      end
      
      def credit(money, source, options = {})
        if source.type == "check"
          virtual_check.credit(money, source, options)
        else
          bankcard.credit(money, source, options)
        end
      end
          
      private
      def bankcard
        @bankcard ||= SageBankcardGateway.new(@options)
      end
      
      def virtual_check
        @virtual_check ||= SageVirtualCheckGateway.new(@options)
      end 
    end
  end
end

