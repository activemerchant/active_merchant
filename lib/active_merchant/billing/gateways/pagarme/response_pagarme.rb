require File.dirname(__FILE__) + '/status_pagarme.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module PagarmeRecurringApi #:nodoc:
      module ResponsePagarme #:nodoc:
        include ActiveMerchant::Billing::PagarmeRecurringApi::StatusPagarme

        def customer_response(customer)
          {
            document_number: customer['document_number'],
            name: customer['name'],
            email: customer['email'],
            address: {
              street: customer['addresses'][0]['street'],
              complementary: customer['addresses'][0]['complementary'],
              street_number: customer['addresses'][0]['street_number'],
              neighborhood: customer['addresses'][0]['neighborhood'],
              city: customer['addresses'][0]['city'],
              state: customer['addresses'][0]['state'],
              zipcode: customer['addresses'][0]['zipcode'],
              country: "Brasil"
            },
            phone: {
              ddi: customer['phones'][0]['ddi'],
              ddd: customer['phones'][0]['ddd'],
              number: customer['phones'][0]['number']
            }
          }
        end

        def customer_params(customer, address)
          zipcode  = address[:zip_code] || address[:zipcode]
          phone    = phone_formatted(customer[:phone])
          document = document_number_formatted(customer[:legal_identifier])

          {
            document_number: document,
            name: customer[:name],
            email: customer[:email],
            phone: phone,
            address: {
              street: address[:street],
              complementary: address[:complement],
              street_number: address[:number],
              neighborhood: address[:district],
              city: address[:city],
              state: address[:state],
              zipcode: zipcode,
              country: "Brasil"
            }
          }
        end

        def invoice_to_response(response)
          return {} unless response

          {
              id: response['id'],
              amount: response['amount'],
              created_at: response['date_created'],
              action: INVOICE_STATUS_MAP[response['status']],
              object: response['object'],
              refuse_reason: INVOICE_STATUS_REASON_MAP[response['refuse_reason']],
              status_reason: response['status_reason'],
              acquirer_response_code: response['acquirer_response_code'],
              acquirer_name: response['acquirer_name'],
              authorization_code: response['authorization_code'],
              soft_descriptor: response['soft_descriptor'],
              tid: response['tid'],
              nsu: response['nsu'],
              updated_at: response['date_updated'],
              installments: response['installments'],
              cost: response['cost'],
              postback_url: response['postback_url'],
              payment_method: PAYMENT_METHOD_MAP[response['payment_method']],
              antifraud_score: response['antifraud_score'],
              boleto_url: response['boleto_url'],
              boleto_barcode: response['boleto_barcode'],
              boleto_expiration_date: response['boleto_expiration_date'],
              referer: response['referer'],
              ip: response['ip'],
              subscription_id: response['subscription_id'],
              phone: phone_response_invoice(response),
              address: address_response_invoice(response),
              customer: customer_response_invoice(response),
              card: card_response_invoice(response),
              metadata: default_object_if_empty(response['metadata']),
              antifraud_metadata: default_object_if_empty(response['antifraud_metadata'])
          }

        end

        def card_response_invoice(response)
          return {} unless response['card']

          {
              object: response['card']['object'],
              id: response['card']['id'],
              date_created: response['card']['date_created'],
              date_updated: response['card']['date_updated'],
              brand: response['card']['brand'],
              holder_name: response['card']['holder_name'],
              first_digits: response['card']['first_digits'],
              last_digits: response['card']['last_digits'],
              fingerprint: response['card']['fingerprint'],
              valid: response['card']['valid']
          }

        end

        def customer_response_invoice(response)
          return {} unless response['customer']

          {
              object: response['customer']['object'],
              document_number: response['customer']['document_number'],
              document_type: response['customer']['document_type'],
              name: response['customer']['name'],
              email: response['customer']['email'],
              born_at: response['customer']['born_at'],
              gender: response['customer']['gender'],
              date_created: response['customer']['date_created'],
              id: response['customer']['id']
          }
        end

        def address_response_invoice(response)
          return {} unless response['address']

          {
              object: response['address']['object'],
              street: response['address']['street'],
              complementary: response['address']['complementary'],
              street_number: response['address']['street_number'],
              neighborhood: response['address']['neighborhood'],
              city: response['address']['city'],
              state: response['address']['state'],
              zipcode: response['address']['zipcode'],
              country: response['address']['country'],
              id: response['address']['id']
          }
        end

        def phone_response_invoice(response)
          return {} unless response['phone']

          {
              ddd: response['phone']['ddd'],
              ddi: response['phone']['ddi'],
              number: response['phone']['number'],
          }
        end

        def invoices_to_response(response)
          return {} unless response

          if !response.kind_of?(Array)
            if response.has_key?('errors')
              []
            end
          else
            response.map(&method(:invoice_to_response))
          end
        end


        def payments_to_response(response)
          return {} unless response

          response.map(&method(:payment_to_response))
        end

        def payment_to_response(response)
          return {} unless response

          {
              object: response['object'],
              id: response['id'],
              action: INVOICE_STATUS_MAP[response['status']],
              amount: response['amount'],
              fee: response['fee'],
              installment: response['installment'],
              transaction_id: response['transaction_id'],
              split_rule_id: response['split_rule_id'],
              payment_date: response['payment_date'],
              type: response['type'],
              payment_method: PAYMENT_METHOD_MAP[response['payment_method']],
              created_at: response['date_created']
          }
        end


        def subscription_to_response(response)
          return {} unless response

          {
              object: response['object'],
              plan: plan_response(response),
              id: response['id'],
              current_transaction: transaction_response_subscription(response),
              postback_url: response['postback_url'],
              payment_method: response['payment_method'],
              current_period_start: response['current_period_start'],
              current_period_end: response['current_period_end'],
              charges: response['charges'],
              action: SUBSCRIPTION_STATUS_MAP[response['status']],
              created_at: response['date_created'],
              phone: phone_response_invoice(response),
              address: address_response_invoice(response),
              customer: customer_response_invoice(response),
              card: card_response_invoice(response),
              metadata: default_object_if_empty(response['metadata']),
          }

        end

        def transaction_response_subscription(response)
          return {} unless response['current_transaction']

          {
              object: response['current_transaction']['object'],
              status: INVOICE_STATUS_MAP[response['current_transaction']['status']],
              refuse_reason: response['current_transaction']['refuse_reason'],
              status_reason: response['current_transaction']['status_reason'],
              acquirer_response_code: response['current_transaction']['acquirer_response_code'],
              acquirer_name: response['current_transaction']['acquirer_name'],
              authorization_code: response['current_transaction']['authorization_code'],
              soft_descriptor: response['current_transaction']['soft_descriptor'],
              tid: response['current_transaction']['tid'],
              nsu: response['current_transaction']['nsu'],
              created_at: response['current_transaction']['date_created'],
              updated_at: response['current_transaction']['date_updated'],
              amount: response['current_transaction']['amount'],
              installments: response['current_transaction']['installments'],
              id: response['current_transaction']['id'],
              cost: response['current_transaction']['cost'],
              postback_url: response['current_transaction']['postback_url'],
              payment_method: response['current_transaction']['payment_method'],
              antifraud_score: response['current_transaction']['antifraud_score'],
              boleto_url: response['current_transaction']['boleto_url'],
              boleto_barcode: response['current_transaction']['boleto_barcode'],
              boleto_expiration_date: response['current_transaction']['boleto_expiration_date'],
              referer: response['current_transaction']['referer'],
              ip: response['current_transaction']['ip'],
              subscription_id: response['current_transaction']['subscription_id'],
              metadata: default_object_if_empty(response['current_transaction']['metadata']),
          }
        end

        def plan_response(response)
          return {} unless response['plan']

          {
              object: response['plan']['object'],
              id: response['plan']['id'],
              amount: response['plan']['amount'],
              days: response['plan']['days'],
              name: response['plan']['name'],
              trial_days: response['plan']['trial_days'],
              created_at: response['plan']['date_created'],
              payment_methods: response['plan']['payment_methods'],
              color: response['plan']['color'],
              charges: response['plan']['charges'],
              installments: response['plan']['installments']
          }

        end

        def plan_params(params)

          unit, length, days = INTERVAL_MAP[params[:period]]
          default_name = "ONE INVOICE FOR #{length} #{unit} #{params[:plan_code]}"

          plan_params = {
            name:            params[:name] || default_name,
            days:            days,
            amount:          params[:price],
            trial_days:      params[:trials],
            payment_methods: params[:payment_methods],
            charges:         params[:cycles],
            color:           params[:color],
            installments:    params[:installments]
          }

          plan_params
        end

        def phone_formatted(phone)
          phone  = phone.strip.gsub(/\D/, '')
          ddd    = phone[0..1]
          number = phone[2..phone.size]

          {
            ddd:    ddd,
            number: number
          }
        end

        def document_number_formatted(legal_identifier)
          legal_identifier.strip.gsub(/\D/, '')
        end
      end
    end
  end
end
