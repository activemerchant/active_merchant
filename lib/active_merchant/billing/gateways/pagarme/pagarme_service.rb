require 'httparty'

class PagarmeService
  include HTTParty
  base_uri 'api.pagar.me/1/'

  def initialize(key)
    @options = { query: { api_key: key } }
  end

  def invoices_by_subscription(subscription_id)
    self.class.get("/subscriptions/#{subscription_id}/transactions", @options) #pagarme dont have invoice
  end

  def payments_from_invoice(invoice_id)
    self.class.get("/subscriptions/#{invoice_id}/transactions", @options) #pagarme dont have invoice
  end

  def payment(payment_id)
    self.class.get("/transactions/#{payment_id}", @options)
  end
end
