module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module PagarmeRecurringApi #:nodoc:
      module StatusPagarme #:nodoc:

        PAYMENT_STATUS_MAP = {
          'paid'            => :authorize,
          'authorized'      => :authorize,
          'processing'      => :initiate,
          'chargedback'     => :cancel,
          'waiting_payment' => :wait_boleto,
          'refused'         => :reverse,
          'refunded'        => :refund,
          'pending_refund'  => :wait_boleto
        }

        SUBSCRIPTION_STATUS_MAP = {
          'trialing'        => :no_wait_process,
          'paid'            => :confirm,
          'pending_payment' => :process,
          'unpaid'          => :cancel,
          'canceled'        => :cancel,
          'ended'           => :cancel
        }

        INVOICE_STATUS_MAP = {
            'processing' => :open,
            'authorized' => :confirm,
            'paid' => :confirm,
            'refunded' => :not_pay,
            'waiting_payment' => :wait_confirmation,
            'pending_refund' => :wait_confirmation,
            'refused' => :not_pay,
            'waiting_funds' => :wait_confirmation
        }

        INVOICE_STATUS_REASON_MAP = {
            'acquirer' => :acquirer,
            'antifraud' => :antifraud,
            'internal_error' => :internal_error,
            'no_acquirer' => :no_acquirer,
            'acquirer_timeout' => :acquirer_timeout
        }

        PAYMENT_METHOD_MAP = {
            'credit_card' => 'credit_card',
            'boleto' => 'boleto'
        }

        INTERVAL_MAP = {
          'monthly' => ['MONTH', 1, 30],
          'quarterly' => ['MONTH', 3, 90],
          'semesterly' => ['MONTH', 6, 180],
          'yearly' => ['YEAR', 1, 360]
        }

      end
    end
  end
end
