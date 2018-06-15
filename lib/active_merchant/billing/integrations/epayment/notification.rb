# frozen_string_literal: true

require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Epayment
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          %w[token
             partnerid
             sign
             orderid
             amount
             currency
             details
             nickname
             lifetime
             successurl
             declineurl].each do |param_name|
            define_method(param_name.underscore) { params[param_name] }
          end

          # def generate_sign
          #   Digest::MD5.hexdigest("#{params['partner_id']};
          #                    #{params['partner_secret']};
          #                    #{@payment.id};
          #                    #{@payment.amount};
          #                    #{@payment.payment_system.currency}")
          # end

          def downcase_sign
            sign = params['sign']
            params['sign'] = sign.downcase
          end

          def send_request
            headers = { 'Content-Type' => 'application/json' }
            url = URI.parse('https://api.sandbox.epayments.com/merchant/prepare')
            call = Net::HTTP::Post.new(url.path, headers)
            call.add_field('Authorization: Bearer', token)
            downcase_sign
            call.body = params.to_json

            request = Net::HTTP.new(url.host, url.port)
            request.use_ssl = true
            binding.pry
            response = request.start { |http| http.request(call) }
          end
        end
      end
    end
  end
end
