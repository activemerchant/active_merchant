module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    ##
    # Delegates to the appropriate gateway, either the Transaction or Advanced
    # depending on options passed to new.
    #
    class UsaEpayGateway < Gateway
      self.abstract_class = true

      ##
      # Creates an instance of UsaEpayTransactionGateway by default, but if
      # :software id or :live_url are passed in the options hash it will
      # create an instance of UsaEpayAdvancedGateway.
      #
      def self.new(options={})
        if options.has_key?(:software_id) || options.has_key?(:live_url)
          UsaEpayAdvancedGateway.new(options)
        else
          UsaEpayTransactionGateway.new(options)
        end
      end
    end
  end
end
