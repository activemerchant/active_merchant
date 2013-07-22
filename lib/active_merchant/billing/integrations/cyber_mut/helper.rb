require 'digest/sha1'
require 'openssl'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module CyberMut
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          mapping :account, 'account'
          mapping :amount, 'amount'
          mapping :'text-libre', ''

          mapping :order, 'order'
          mapping :societe, 'masociete'
          mapping :hmac_key, 'ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ'
          mapping :TPE, '123456'

          mapping :url_retour, 'url_retour'
          mapping :url_retour_ok, 'url_retour_ok'
          mapping :url_retour_err, 'url_retour_err'

          def initialize(order, account, options = {})
            super
            # https://github.com/novelys/paiementcic/blob/master/lib/paiement_cic.rb#L41
            version = '3.0'
            add_field('version', version)
            montant = ("%.2f" % options[:amount]) + "EUR"
            add_field('montant', montant)
            langue = 'FR'
            add_field('lgue', langue)
            date = Time.now.strftime('"%d/%m/%Y:%H:%M:%S"')
            add_field('date', date)
            add_field('reference', order)

            add_field('TPE', mappings[:TPE])
            mac_data = [
              mappings[:TPE], date, montant, order,
              options['text-libre'], version, langue, mappings[:societe],
              "", "", "", "", "", "", "", "", "", "", ""
            ].join('*')
            add_field('MAC', compute_HMACSHA1(mac_data))
          end


          # Return the HMAC for a data string
          def compute_HMACSHA1(data)
            hmac_sha1(usable_key(mappings[:hmac_key]), data).downcase
          end

          def hmac_sha1(key, data)
            length = 64

            if (key.length > length)
              key = [Digest::SHA1.hexdigest(key)].pack("H*")
            end

            key = key.ljust(length, 0.chr)

            OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new("sha1"), key, data)
          end

          private
          # Return the key to be used in the hmac function
          def usable_key(hmac_key)
            hex_string_key = hmac_key[0..37]
            hex_final = hmac_key[38..40] + "00"

            cca0 = hex_final[0].ord

            if cca0 > 70 && cca0 < 97
              hex_string_key += (cca0 - 23).chr + hex_final[1..2]
            elsif hex_final[1..2] == "M"
              hex_string_key += hex_final[0..1] + "0"
            else
              hex_string_key += hex_final[0..2]
            end

            [hex_string_key].pack("H*")
          end
        end
      end
    end
  end
end
