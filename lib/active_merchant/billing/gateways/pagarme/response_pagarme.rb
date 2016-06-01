module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module PagarmeRecurringApi #:nodoc:
      module ResponsePagarme #:nodoc:

        def customerResponse(customer)
          {
              :document_number => customer.document_number,
              :name => customer.name,
              :email => customer.email,
              :address => {
                  :street => customer.addresses[0].street,
                  :complementary => customer.addresses[0].complementary,
                  :street_number => customer.addresses[0].street_number,
                  :neighborhood => customer.addresses[0].neighborhood,
                  :city => customer.addresses[0].city,
                  :state => customer.addresses[0].state,
                  :zipcode => customer.addresses[0].zipcode,
                  :country => "Brasil"
              },
              :phone => {
                  :ddi => customer.phones[0].ddi,
                  :ddd => customer.phones[0].ddd,
                  :number => customer.phones[0].number
              }
          }
        end

        def customer_params(customer, address)
          {
              :document_number => customer[:document_number],
              :name => customer[:name],
              :email => customer[:email],
              :address => {
                  :street => address[:street],
                  :complementary => address[:complement],
                  :street_number => address[:number],
                  :neighborhood => address[:district],
                  :city => address[:city],
                  :state => address[:state],
                  :zipcode => address[:zipcode],
                  :country => "Brasil"
              },
              :phone => {
                  :ddi => customer[:ddi],
                  :ddd => customer[:ddd],
                  :number => customer[:number]
              }
          }
        end

        def invoice_to_response(response)
          return {} unless response

          {
              object: response.object,
              plan: {
                  object: response.plan.object,
                  id: response.plan.id,
                  amount: response.plan.amount,
                  days: response.plan.days,
                  name: response.plan.name,
                  trial_days: response.plan.trial_days,
                  date_created: response.plan.date_created,
                  payment_methods: response.plan.payment_methods,
                  color: response.plan.color,
                  charges: response.plan.charges,
                  installments: response.plan.installments
              },
              id: response.id,
              current_transaction: {
                  object: response.current_transaction.object,
                  status: response.current_transaction.status,
                  refuse_reason: response.current_transaction.refuse_reason,
                  status_reason: response.current_transaction.status_reason,
                  acquirer_response_code: response.current_transaction.acquirer_response_code,
                  acquirer_name: response.current_transaction.acquirer_name,
                  authorization_code: response.current_transaction.authorization_code,
                  soft_descriptor: response.current_transaction.soft_descriptor,
                  tid: response.current_transaction.tid,
                  nsu: response.current_transaction.nsu,
                  date_created: response.current_transaction.date_created,
                  date_updated: response.current_transaction.date_updated,
                  amount: response.current_transaction.amount,
                  installments: response.current_transaction.installments,
                  id: response.current_transaction.id,
                  cost: response.current_transaction.cost,
                  postback_url: response.current_transaction.postback_url,
                  payment_method: response.current_transaction.payment_method,
                  antifraud_score: response.current_transaction.antifraud_score,
                  boleto_url: response.current_transaction.boleto_url,
                  boleto_barcode: response.current_transaction.boleto_barcode,
                  boleto_expiration_date: response.current_transaction.boleto_expiration_date,
                  referer: response.current_transaction.referer,
                  ip: response.current_transaction.ip,
                  subscription_id: response.current_transaction.subscription_id,
                  metadata: default_object_if_empty(response.current_transaction.metadata)
              },
              postback_url: response.postback_url,
              payment_method: response.payment_method,
              current_period_start: response.current_period_start,
              current_period_end: response.current_period_end,
              charges: response.charges,
              status: response.status,
              date_created: response.date_created,
              phone: {
                  ddd: response.phone.ddd,
                  ddi: response.phone.ddi,
                  number: response.phone.number,
              },
              address: {
                  object: response.address.object,
                  street: response.address.street,
                  complementary: response.address.complementary,
                  street_number: response.address.street_number,
                  neighborhood: response.address.neighborhood,
                  city: response.address.city,
                  state: response.address.state,
                  zipcode: response.address.zipcode,
                  country: response.address.country,
                  id: response.address.id
              },
              customer: {
                  object: response.customer.object,
                  document_number: response.customer.document_number,
                  document_type: response.customer.document_type,
                  name: response.customer.name,
                  email: response.customer.email,
                  born_at: response.customer.born_at,
                  gender: response.customer.gender,
                  date_created: response.customer.date_created,
                  id: response.customer.id
              },
              card: {
                  object: response.card.object,
                  id: response.card.id,
                  date_created: response.card.date_created,
                  date_updated: response.card.date_updated,
                  brand: response.card.brand,
                  holder_name: response.card.holder_name,
                  first_digits: response.card.first_digits,
                  last_digits: response.card.last_digits,
                  fingerprint: response.card.fingerprint,
                  valid: response.card.valid
              },
              metadata: default_object_if_empty(response.metadata)
          }
        end

        def invoices_to_response(response)
          return {} unless response

          response.map(&method(:invoice_to_response))
        end

      end
    end
  end
end
