module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module PagarmeRecurringApi #:nodoc:
      module StatusPagarme #:nodoc:

        INVOICE_STATUS_MAP = {
            'processing' => 'processing',
            'authorized' => 'authorized',
            'paid' => 'paid',
            'refunded' => 'refunded',
            'waiting_payment' => 'waiting_payment',
            'pending_refund' => 'pending_refund',
            'refused' => 'refused',
            'waiting_funds' => 'waiting_funds'
        }


        INVOICE_STATUS_REASON_MAP = {
            'acquirer' => 'acquirer',
            'antifraud' => 'antifraud',
            'internal_error' => 'internal_error',
            'no_acquirer' => 'no_acquirer',
            'acquirer_timeout' => 'acquirer_timeout'
        }

        SUBSCRIPTION_STATUS = {
            'trialing' => 'trialing',
            'paid' => 'paid',
            'pending_payment' => 'pending_payment',
            'unpaid' => 'unpaid',
            'canceled' => 'canceled',
            'ended' => 'ended'
        }


        PAYMENT_METHOD_MAP = {
            'credit_card' => 'credit_card',
            'boleto' => 'boleto'
        }

        INTERVAL_MAP = {
          'monthly' => ['MONTH', 1],
          'quarterly' => ['MONTH', 3],
          'semesterly' => ['MONTH', 6],
          'yearly' => ['YEAR', 1]
        }

      end
    end
  end
end
