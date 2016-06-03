module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module PagarmeRecurringApi #:nodoc:
      module StatusPagarme #:nodoc:

        INVOICE_STATUS_MAP = {
            'processing' => :processing,
            'authorized' => :authorized,
            'paid' => :paid,
            'refunded' => :refunded,
            'waiting_payment' => :waiting_payment,
            'pending_refund' => :pending_refund,
            'refused' => :refused
        }

        INVOICE_STATUS_REASON_MAP = {
            'acquirer' => :acquirer,
            'antifraud' => :antifraud,
            'internal_error' => :internal_error,
            'no_acquirer' => :no_acquirer,
            'acquirer_timeout' => :acquirer_timeout
        }


        PAYMENT_METHOD_MAP = {
            'credit_card' => :credit_card,
            'boleto' => :boleto
        }


      end
    end
  end
end