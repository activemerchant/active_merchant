module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      class Return
        attr_accessor :params
        attr_reader :notification
      
        def initialize(query_string, options = {})
          @params  = parse(query_string)
          @options = options
        end
      
        # Successful by default. Overridden in the child class
        def success?
          true
        end

        # Not cancelled by default.  Overridden in the child class.
        def cancelled?
          false
        end

        def message
          
        end
        
        def parse(query_string)
          Rack::Utils.parse_query(query_string.force_encoding('ASCII-8BIT'))
        end 
      end
    end
  end
end
