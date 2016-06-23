require 'httparty'

class PagarmeService
  include HTTParty

  base_uri 'api.pagar.me/1/'

  def initialize(key)
    @options = {
        query: {
            api_key: key
        }
    }
  end

  def invoices_by_subscription(subscription_id)
    self.class.get("/subscriptions/#{subscription_id}/transactions", @options)
  end

  def payments_from_invoice(invoice_id)
    self.class.get("/transactions/#{invoice_id}/payables", @options)
  end

  def payment_from_invoice(invoice_id, payment_id)
    self.class.get("/transactions/#{invoice_id}/payables/#{payment_id}", @options)
  end

end
