require 'openssl'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayboxSystem
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          ##
          #
          # You connot use payment_service_for helper with PayboxSystem
          # since the params are very strict for the hmac generation and
          # on the POST method.
          #
          # But you can instantiate the helper and create the form:
          #
          #   @paybox ||= PayboxSystem::Helper.new(
          #     order.id,
          #     payment.paybox_system.business,
          #     {
          #       credential2: payment.paybox_system.secret_key,
          #       credential3: payment.paybox_system.site,
          #       credential4: payment.paybox_system.rang
          #     }
          #   )
          #
          # You need to set some important fields:
          #
          #   paybox.add_field('PBX_PORTEUR', ...)
          #   paybox.add_field('PBX_TOTAL', ...)
          #   paybox.add_field('PBX_CMD', ...)
          #   paybox.add_field('PBX_EFFECTUE', ...)
          #   paybox.add_field('PBX_REFUSE', ...)
          #   paybox.add_field('PBX_ANNULE', ...)
          #   paybox.add_field('PBX_REPONDRE_A', ...)
          #
          # You can use `paybox.query_with_hmac` for generate the form.
          #
          # As an example for our usage we using this:
          #
          #   %form{method: 'POST', action: ActiveMerchant::Billing::Integrations::PayboxSystem.service_url}
          #     // Generate hidden fields with `paybox.query_with_hmac`
          #     %input{type: 'submit', value: 'PayBox'}
          #

          mapping :account, 'PBX_IDENTIFIANT'
          mapping :amount, 'PBX_TOTAL'
          mapping :currency, 'PBX_DEVISE'
          mapping :order, 'PBX_CMD'

          mapping :notify_url, 'PBX_REPONDRE_A'
          mapping :return_url, 'PBX_EFFECTUE'
          mapping :cancel_return_url, 'PBX_ANNULE'
          mapping :return_error_url, 'PBX_REFUSE'
          mapping :email, 'PBX_PORTEUR'
          mapping :return, 'PBX_RETOUR'
          mapping :site, 'PBX_SITE'
          mapping :rang, 'PBX_RANG'

          def initialize(order, account, options = {})
            super
            add_field('PBX_DEVISE', '978') # euro
            add_field('PBX_HASH', 'SHA512')
            add_field('PBX_RETOUR', "amount:M;reference:R;autorization:A;error:E;sign:K")
            add_field('PBX_TIME', Time.now.utc.iso8601)
            add_field('PBX_SITE', options[:credential3])
            add_field('PBX_RANG', options[:credential4])
            add_field('PBX_PAYBOX', PayboxSystem.service_url)
            add_field('PBX_BACKUP1', PayboxSystem.service_url)
            add_field('PBX_BACKUP2', PayboxSystem.service_url)
            @secret_key = options[:credential2]
          end

          def query
            @query ||= {
              :PBX_SITE => fields['PBX_SITE'],
              :PBX_RANG => fields['PBX_RANG'],
              :PBX_IDENTIFIANT => fields['PBX_IDENTIFIANT'],
              :PBX_DEVISE => fields['PBX_DEVISE'],
              :PBX_PORTEUR => fields['PBX_PORTEUR'],
              :PBX_RETOUR => fields['PBX_RETOUR'],
              :PBX_self => fields['PBX_self'],
              :PBX_BACKUP1 => fields['PBX_BACKUP1'],
              :PBX_BACKUP2 => fields['PBX_BACKUP2'],
              :PBX_TOTAL => fields['PBX_TOTAL'],
              :PBX_CMD => fields['PBX_CMD'],
              :PBX_EFFECTUE => fields['PBX_EFFECTUE'],
              :PBX_REFUSE => fields['PBX_REFUSE'],
              :PBX_ANNULE => fields['PBX_ANNULE'],
              :PBX_REPONDRE_A => fields['PBX_REPONDRE_A'],
              :PBX_HASH => fields['PBX_HASH'],
              :PBX_TIME => fields['PBX_TIME'],
            }
          end

          def query_with_hmac
            query.merge(:PBX_HMAC => hmac(query_to_param))
          end

          private
          def query_to_param
            query.to_a.map { |a| a.join("=") }.join("&")
          end

          def hmac(query)
            OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('sha512'),
                                    [@secret_key].pack("H*"), query).upcase
          end
        end
      end
    end
  end
end
