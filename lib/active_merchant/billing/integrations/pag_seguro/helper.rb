# encoding: utf-8
require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PagSeguro
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order_id, account, options)
            super
            @account = account

            add_field('itemAmount1', sprintf("%0.02f", options[:amount]))
            add_field('itemId1', '1')
            add_field('itemQuantity1', '1')
            add_field('shippingType', '3')
            add_field('currency', 'BRL')
          end

          mapping :account, 'email'
          mapping :credential2, 'token'

          mapping :order, 'reference'

          mapping :billing_address, :city     => 'shippingAddressCity',
                                    :address1 => 'shippingAddressStreet',
                                    :address2 => 'shippingAddressNumber',
                                    :state    => 'shippingAddressState',
                                    :zip      => 'shippingAddressPostalCode',
                                    :country  => 'shippingAddressCountry'

          mapping :notify_url, 'notificationURL'
          mapping :return_url, 'redirectURL'
          mapping :description, 'itemDescription1'

          def form_fields
            invoice_id = fetch_token

            {"code" => invoice_id}
          end

          def shipping(value)
            add_field("shippingCost", sprintf("%0.02f", value))
          end

          def customer(params = {})
            phone = area_code_and_number(params[:phone])

            add_field("senderAreaCode", phone[0])
            add_field("senderPhone", phone[1])
            add_field("senderEmail", params[:email])
            add_field('senderName', "#{params[:first_name]} #{params[:last_name]}")
          end

          def fetch_token
            uri = URI.parse(PagSeguro.invoicing_url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true

            request = Net::HTTP::Post.new(uri.request_uri)
            request.content_type = "application/x-www-form-urlencoded"
            request.set_form_data @fields

            response = http.request(request)
            xml = Nokogiri::XML.parse(response.body)

            check_for_errors(response, xml)

            extract_token(xml)
          rescue Timeout::Error, Errno::ECONNRESET => e
            raise ActionViewHelperError, "Erro ao conectar-se ao PagSeguro. Por favor, tente novamente."
          end

          def area_code_and_number(phone)
            phone.gsub!(/[^\d]/, '')

            ddd    = phone.slice(0..1)
            number = phone.slice(2..12)

            [ddd, number]
          end

          def check_for_errors(response, xml)
            return if response.code == "200"

            case response.code
            when "400"
              raise ActionViewHelperError, humanize_errors(xml)
            when "401"
              raise ActionViewHelperError, "Token do PagSeguro inválido."
            else
              raise ActiveMerchant::ResponseError, response
            end
          end

          def extract_token(xml)
            xml.css("code").text
          end

          def humanize_errors(xml)
            # reference: https://pagseguro.uol.com.br/v2/guia-de-integracao/codigos-de-erro.html

            xml.css("errors").children.map do |error|
              case error.css('code').text
              when "11013"
                "Código de área inválido"
              when "11014"
                "Número de telefone inválido. Formato esperado: (DD) XXXX-XXXX"
              when "11017"
                "Código postal (CEP) inválido."
              else
                error.css('message').text
              end
            end.join(", ")
          end

        end
      end
    end
  end
end
