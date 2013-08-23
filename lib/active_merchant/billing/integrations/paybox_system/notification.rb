require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayboxSystem
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def complete?
            status == '00000'
          end

          def item_id
            params['reference']
          end

          def transaction_id
            params['sign']
          end

          def security_key
            params['sign']
          end

          def currency
            'EUR'
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['amount']
          end

          # Paybox gross return is already in cents
          def gross_cents
            gross.to_i
          end

          # Was this a test transaction?
          def test?
            ActiveMerchant::Billing::Base.integration_mode == :test
          end

          # 00000 Opération réussie.
          # 00001 La connexion au centre d’autorisation a échoué. Vous pouvez dans ce cas là
          #           effectuer les redirections des internautes vers le FQDN tpeweb1.paybox.com.
          # 001xx Paiement refusé par le centre d’autorisation [voir §12.1 Codes réponses du centre
          #           d’autorisation].
          # En cas d’autorisation de la transaction par le centre d’autorisation de la banque ou de
          # l’établissement financier privatif, le code erreur “00100” sera en fait remplacé
          # directement par “00000”.
          # 00003 Erreur Paybox.
          # 00004 Numéro de porteur ou cryptogramme visuel invalide.
          # 00006 Accès refusé ou site/rang/identifiant incorrect.
          # 00008 Date de fin de validité incorrecte.
          # 00009 Erreur de création d’un abonnement.
          # 00010 Devise inconnue.
          # 00011 Montant incorrect.
          # 00015 Paiement déjà effectué.
          # 00016 Abonné déjà existant (inscription nouvel abonné). Valeur ‘U’ de la variable
          #              PBX_RETOUR.
          # 00021 Carte non autorisée.
          # 00029 Carte non conforme. Code erreur renvoyé lors de la documentation de la variable
          #       « PBX_EMPREINTE ».
          # 00030 Temps d’attente > 15 mn par l’internaute/acheteur au niveau de la page de
          #          paiements.
          # 00031 Réservé
          # 00032 Réservé
          # 00033 Code pays de l’adresse IP du navigateur de l’acheteur non autorisé.
          # 00040 Opération sans authentification 3DSecure, bloquée par le filtre.
          def status
            params['error']
          end

          # Acknowledge the transaction to PayboxSystem. This method has to be called after a new
          # apc arrives. PayboxSystem will verify that all the information we received are correct and will return a
          # ok or a fail.
          #
          # Example:
          #
          #   def ipn
          #     notify = PayboxSystemNotification.new(request.raw_post)
          #
          #     if notify.acknowledge
          #       ... process order ... if notify.complete?
          #     else
          #       ... log possible hacking attempt ...
          #     end
          def acknowledge
            payload = raw

            uri = URI.parse(PayboxSystem.service_url)

            request = Net::HTTP::Post.new(uri.path)

            request['Content-Length'] = "#{payload.size}"
            request['User-Agent'] = "Active Merchant -- http://home.leetsoft.com/am"
            request['Content-Type'] = "application/x-www-form-urlencoded"

            http = Net::HTTP.new(uri.host, uri.port)
            http.verify_mode    = OpenSSL::SSL::VERIFY_NONE unless @ssl_strict
            http.use_ssl        = true

            response = http.request(request, payload)

            # Replace with the appropriate codes
            raise StandardError.new("Faulty PayboxSystem result: #{response.body}") unless ["AUTHORISED", "DECLINED"].include?(response.body)
            response.body == "AUTHORISED"
          end

          private

          # Take the posted data and move the relevant data into a hash
          def parse(post)
            @raw = post.to_s
            for line in @raw.split('&')
              key, value = *line.scan( %r{^([A-Za-z0-9_.]+)\=(.*)$} ).flatten
              params[key] = CGI.unescape(value)
            end
          end
        end
      end
    end
  end
end
