module Braintree
  class Subscription
    include BaseModule
    include Braintree::Util::IdEquality

    module Source
      Api          = "api"
      ControlPanel = "control_panel"
      Recurring    = "recurring"
      Unrecognized = "unrecognized"
    end

    module Status
      Active = 'Active'
      Canceled = 'Canceled'
      Expired = 'Expired'
      PastDue = 'Past Due'
      Pending = 'Pending'

      All = constants.map { |c| const_get(c) }
    end

    module TrialDurationUnit
      Day = "day"
      Month = "month"
    end

    attr_reader :add_ons
    attr_reader :balance
    attr_reader :billing_day_of_month
    attr_reader :billing_period_end_date
    attr_reader :billing_period_start_date
    attr_reader :created_at
    attr_reader :current_billing_cycle
    attr_reader :days_past_due
    attr_reader :description
    attr_reader :descriptor
    attr_reader :discounts
    attr_reader :failure_count
    attr_reader :first_billing_date
    attr_reader :id
    attr_reader :merchant_account_id
    attr_reader :next_billing_date
    attr_reader :next_billing_period_amount
    attr_reader :number_of_billing_cycles
    attr_reader :paid_through_date
    attr_reader :payment_method_token
    attr_reader :plan_id
    attr_reader :price
    attr_reader :status
    attr_reader :status_history
    attr_reader :transactions
    attr_reader :trial_duration
    attr_reader :trial_duration_unit
    attr_reader :trial_period
    attr_reader :updated_at

    def self.cancel(*args)
      Configuration.gateway.subscription.cancel(*args)
    end

    def self.cancel!(*args)
      Configuration.gateway.subscription.cancel!(*args)
    end

    def self.create(*args)
      Configuration.gateway.subscription.create(*args)
    end

    def self.create!(*args)
      Configuration.gateway.subscription.create!(*args)
    end

    def self.find(*args)
      Configuration.gateway.subscription.find(*args)
    end

    def self.retry_charge(*args)
      Configuration.gateway.subscription.retry_charge(*args)
    end

    def self.search(&block)
      Configuration.gateway.subscription.search(&block)
    end

    def self.update(*args)
      Configuration.gateway.subscription.update(*args)
    end

    def self.update!(*args)
      Configuration.gateway.subscription.update!(*args)
    end

    def initialize(gateway, attributes) # :nodoc:
      @gateway = gateway
      set_instance_variables_from_hash(attributes)
      @balance = Util.to_big_decimal(balance)
      @price = Util.to_big_decimal(price)
      @descriptor = Descriptor.new(@descriptor)
      transactions.map! { |attrs| Transaction._new(gateway, attrs) }
      add_ons.map! { |attrs| AddOn._new(attrs) }
      discounts.map! { |attrs| Discount._new(attrs) }
      @status_history = attributes[:status_history] ? attributes[:status_history].map { |s| StatusDetails.new(s) } : []
    end

    def next_bill_amount
      warn "[DEPRECATED] Subscription.next_bill_amount is deprecated. Please use Subscription.next_billing_period_amount"
      @next_bill_amount
    end

    def never_expires?
      @never_expires
    end

    class << self
      protected :new
      def _new(*args) # :nodoc:
        self.new *args
      end
    end
  end
end
