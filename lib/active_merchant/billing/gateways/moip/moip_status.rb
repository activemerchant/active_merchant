module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module MoipStatus #:nodoc:

      INTERVAL_MAP = {
        'monthly' => ['MONTH', 1],
        'quarterly' => ['MONTH', 3],
        'semesterly' => ['MONTH', 6],
        'yearly' => ['YEAR', 1]
      }

      INVOICE_TO_SUBSCRIPTION_STATUS_MAP = {
        1 => :process,
        2 => :process,
        3 => :confirm,
        4 => :canceled,
        5 => :process
      }

      SUBSCRIPTION_STATUS_MAP = {
        'active'    => :confirm,
        'suspended' => :cancel,
        'expired'   => :process,
        'overdue'   => :process,
        'canceled'  => :cancel,
        'trial'     => :no_wait_process
      }

      INVOICE_STATUS_MAP = {
        1 => :open,
        2 => :wait_confirmation,
        3 => :confirm,
        4 => :not_pay,
        5 => :expire
      }

      PAYMENT_STATUS_MAP = {
        1 => :authorize,
        2 => :initiate,
        3 => :wait_boleto,
        4 => :confirm,
        5 => :cancel,
        6 => :wait_analysis,
        7 => :reverse,
        9 => :refund,
        10 => :wait_boleto
      }

      PAYMENT_METHOD_MAP = {
        1 => 'credit_card',
        2 => 'boleto'
      }
    end
  end
end
