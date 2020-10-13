module Braintree
  class Dispute # :nodoc:
    include BaseModule
    include Braintree::Util::IdEquality

    attr_reader :amount
    attr_reader :amount_disputed
    attr_reader :amount_won
    attr_reader :case_number
    attr_reader :created_at
    attr_reader :currency_iso_code
    attr_reader :date_opened
    attr_reader :date_won
    attr_reader :evidence
    attr_reader :graphql_id
    attr_reader :id
    attr_reader :kind
    attr_reader :merchant_account_id
    attr_reader :original_dispute_id
    attr_reader :processor_comments
    attr_reader :reason
    attr_reader :reason_code
    attr_reader :reason_description
    attr_reader :received_date
    attr_reader :reference_number
    attr_reader :reply_by_date
    attr_reader :status
    attr_reader :status_history
    attr_reader :transaction
    attr_reader :transaction_details
    attr_reader :updated_at

    module Status
      Accepted = "accepted"
      Disputed = "disputed"
      Expired = "expired"
      Open = "open"
      Lost = "lost"
      Won = "won"

      All = constants.map { |c| const_get(c) }
    end

    module Reason
      CancelledRecurringTransaction = "cancelled_recurring_transaction"
      CreditNotProcessed = "credit_not_processed"
      Duplicate = "duplicate"
      Fraud = "fraud"
      General = "general"
      InvalidAccount = "invalid_account"
      NotRecognized = "not_recognized"
      ProductNotReceived = "product_not_received"
      ProductUnsatisfactory = "product_unsatisfactory"
      TransactionAmountDiffers = "transaction_amount_differs"
      Retrieval = "retrieval"

      All = constants.map { |c| const_get(c) }
    end

    module Kind
      Chargeback = "chargeback"
      PreArbitration = "pre_arbitration"
      Retrieval = "retrieval"

      All = constants.map { |c| const_get(c) }
    end

    class << self
      protected :new
      def _new(*args) # :nodoc:
        self.new *args
      end
    end

    def self.accept(*args)
      Configuration.gateway.dispute.accept(*args)
    end

    def self.add_file_evidence(*args)
      Configuration.gateway.dispute.add_file_evidence(*args)
    end

    def self.add_text_evidence(*args)
      Configuration.gateway.dispute.add_text_evidence(*args)
    end

    def self.finalize(*args)
      Configuration.gateway.dispute.finalize(*args)
    end

    def self.find(*args)
      Configuration.gateway.dispute.find(*args)
    end

    def self.remove_evidence(*args)
      Configuration.gateway.dispute.remove_evidence(*args)
    end

    def self.search(&block)
      Configuration.gateway.dispute.search(&block)
    end

    def initialize(attributes) # :nodoc:
      set_instance_variables_from_hash(attributes)
      @date_opened = Date.parse(date_opened) unless date_opened.nil?
      @date_won = Date.parse(date_won) unless date_won.nil?
      @received_date = Date.parse(received_date)
      @reply_by_date = Date.parse(reply_by_date) unless reply_by_date.nil?
      @amount = Util.to_big_decimal(amount)
      @amount_disputed = Util.to_big_decimal(amount_disputed)
      @amount_won = Util.to_big_decimal(amount_won)

      @evidence = evidence.map do |record|
        Braintree::Dispute::Evidence.new(record)
      end unless evidence.nil?

      @transaction_details = TransactionDetails.new(transaction)
      @transaction = Transaction.new(transaction)

      @status_history = status_history.map do |event|
        Braintree::Dispute::HistoryEvent.new(event)
      end unless status_history.nil?
    end

    def forwarded_comments
      # NEXT_MAJOR_VERSION delete this method since it never returned anything anyway.
      warn "[DEPRECATED] #forwarded_comments is deprecated. Please use #processor_comments"
      processor_comments
    end
  end
end
