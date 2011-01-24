require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Valitor
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include RequiresParameters

          def initialize(order, account, options={})
            options[:currency] ||= 'ISK'
            super
            add_field 'Adeinsheimild', '0'
            add_field 'KaupandaUpplysingar', '0'
            add_field 'SlokkvaHaus', '0'
          end
          
          mapping :account, 'VefverslunID'
          mapping :currency, 'Gjaldmidill'

          mapping :order, 'Tilvisunarnumer'

          mapping :notify_url, 'SlodTokstAdGjaldfaeraServerSide'
          mapping :return_url, 'SlodTokstAdGjaldfaera'
          mapping :cancel_return_url, 'SlodNotandiHaettirVid'
          
          mapping :success_text, 'SlodTokstAdGjaldfaeraTexti'
          
          mapping :language, 'Lang'
          
          def password(number)
            @security_number = number
          end
          
          def authorize_only
            add_field 'Adeinsheimild', '1'
          end
          
          def collect_customer_info
            add_field 'KaupandaUpplysingar', '1'
          end
          
          def hide_header
            add_field 'SlokkvaHaus', '1'
          end
          
          def product(id, options={})
            raise ArgumentError, "Product id #{id} is not an integer between 1 and 500" unless id.to_i > 0 && id.to_i <= 500
            requires!(options, :amount, :description)
            options.assert_valid_keys([:description, :quantity, :amount, :discount])

            add_field("Vara_#{id}_Verd", options[:amount])
            add_field("Vara_#{id}_Fjoldi", options[:quantity] || "1")
            
            add_field("Vara_#{id}_Lysing", options[:description]) if options[:description]
            add_field("Vara_#{id}_Afslattur", options[:discount] || '0')
            
            @products ||= []
            @products << id.to_i
          end
          
          def signature
            raise ArgumentError, "Security number not set" unless @security_number
            parts = [@security_number, @fields['Adeinsheimild']]
            @products.sort.uniq.each do |id|
              parts.concat(["Vara_#{id}_Fjoldi", "Vara_#{id}_Verd", "Vara_#{id}_Afslattur"].collect{|e| @fields[e]})
            end if @products
            parts.concat(%w(VefverslunID Tilvisunarnumer SlodTokstAdGjaldfaera SlodTokstAdGjaldfaeraServerSide Gjaldmidill).collect{|e| @fields[e]})
            Digest::MD5.hexdigest(parts.compact.join(''))
          end

          def form_fields
            @fields.merge('RafraenUndirskrift' => signature)
          end
        end
      end
    end
  end
end
