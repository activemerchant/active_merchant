module Braintree
  class Dispute
    class HistoryEvent # :nodoc:
      include BaseModule

      attr_reader :disbursement_date
      attr_reader :effective_date
      attr_reader :status
      attr_reader :timestamp

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
      end
    end
  end
end
