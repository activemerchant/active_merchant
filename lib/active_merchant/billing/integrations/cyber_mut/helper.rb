require 'digest/sha1'
require 'openssl'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module CyberMut
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order, account, options = {})
            super
            # https://github.com/novelys/paiementcic/blob/master/lib/paiement_cic.rb#L41
            add_field('version', '3.0')
            add_field('montant', ("%.2f" % options[:amount]) + "EUR")
            add_field('lgue', 'FR')
            add_field('date', Time.now.strftime('"%d/%m/%Y:%H:%M:%S"'))
            add_field('reference', order)
            add_field('societe', 'masociete')
            add_field('TPE', '123456')
          end

          mapping :account, 'account'
          mapping :amount, 'amount'
          mapping :'text-libre', ''

          mapping :order, 'order'

          mapping :url_retour, 'url_retour'
          mapping :url_retour_ok, 'url_retour_ok'
          mapping :url_retour_err, 'url_retour_err'
        end
      end
    end
  end
end
