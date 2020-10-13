module Braintree
  class AccountUpdaterDailyReport # :nodoc:
    include BaseModule

    attr_reader :report_date
    attr_reader :report_url

    class << self
      protected :new
      def _new(*args) # :nodoc:
        self.new *args
      end
    end

    def initialize(attributes) # :nodoc:
      set_instance_variables_from_hash(attributes)
      @report_date = Date.parse(report_date)
    end
  end
end
