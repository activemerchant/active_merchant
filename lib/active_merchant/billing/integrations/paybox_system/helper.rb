require 'openssl'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayboxSystem
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          # PBX_SITE = Numéro de site (fourni par Paybox)
          # PBX_RANG = Numéro de rang (fourni par Paybox)
          # PBX_IDENTIFIANT = Identifiant interne (fourni par Paybox)
          # PBX_TOTAL = Montant total de la transaction
          # PBX_DEVISE = Devise de la transaction
          # PBX_CMD = Référence commande côté commerçant
          # PBX_PORTEUR = Adresse E-mail de l’acheteur
          # PBX_RETOUR = Liste des variables à retourner par Paybox
          # PBX_HASH = Type d’algorithme de hachage pour le calcul de l’empreinte
          # PBX_TIME = Horodatage de la transaction
          # PBX_HMAC = Signature calculée avec la clé secrète
          def initialize(order, account, options = {})
            super
            add_field('PBX_DEVISE', '978') # euro
            add_field('PBX_HASH', 'SHA512')
            add_field('PBX_RETOUR', "amount:M;reference:R;autorization:A;error:E;sign:K")
            add_field('PBX_TIME', Time.now.utc.iso8601)
            add_field('PBX_HMAC', hmac(credential2, form_fields.to_query))
            add_field('PBX_SITE', credential3)
            add_field('PBX_RANG', credential4)
            add_field('PBX_PAYBOX', PayboxSystem.service_url)
            add_field('PBX_BACKUP1', PayboxSystem.service_url)
            add_field('PBX_BACKUP2', PayboxSystem.service_url)
          end

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

          private
          def hmac(key, query)
            OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('sha512'),
                                    [key].pack("H*"), query).upcase
          end
        end
      end
    end
  end
end
