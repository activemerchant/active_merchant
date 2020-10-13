module Braintree
  class Disbursement
    include BaseModule

    module Types
      Credit = "credit"
      Debit  = "debit"
    end

    attr_reader :amount
    attr_reader :disbursement_date
    attr_reader :disbursement_type
    attr_reader :exception_message
    attr_reader :follow_up_action
    attr_reader :id
    attr_reader :merchant_account
    attr_reader :retry
    attr_reader :success
    attr_reader :transaction_ids

    alias_method :success?, :success

    def initialize(gateway, attributes) # :nodoc:
      @gateway = gateway
      set_instance_variables_from_hash(attributes)
      @amount = Util.to_big_decimal(amount)
      @disbursement_date = Date.parse(disbursement_date)
      @merchant_account = MerchantAccount._new(gateway, @merchant_account)
    end

    def transactions
      transactions = @gateway.transaction.search do |search|
        search.ids.in transaction_ids
      end
    end

    def inspect # :nodoc:
      nice_attributes = self.class._inspect_attributes.map { |attr| "#{attr}: #{send(attr).inspect}" }
      nice_attributes << "amount: #{self.amount.to_s("F").inspect}"
      nice_attributes << "disbursement_date: #{self.disbursement_date.to_s}"
      "#<#{self.class} #{nice_attributes.join(', ')}>"
    end

    def debit?
      disbursement_type == Types::Debit
    end

    def credit?
      disbursement_type == Types::Credit
    end

    class << self
      protected :new
      def _new(*args) # :nodoc:
        self.new *args
      end
    end

    def self._inspect_attributes # :nodoc:
      [:id, :exception_message, :follow_up_action, :merchant_account, :transaction_ids, :retry, :success]
    end
  end
end
