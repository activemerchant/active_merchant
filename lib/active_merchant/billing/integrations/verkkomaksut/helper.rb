module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Verkkomaksut
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          # Fetches the md5secret and adds MERCHANT_ID and API TYPE to the form
          def initialize(order, account, options = {})
            md5secret options.delete(:credential2)
            super
            add_field("MERCHANT_ID", account)
            add_field("TYPE", "E1")
          end

          def md5secret(value)
            @md5secret = value
          end

          # Adds the AUTHCODE to the form
          def form_fields
            @fields.merge("AUTHCODE" => generate_md5string)
          end

          # Calculates the AUTHCODE
          def generate_md5string
            fields = [@md5secret, @fields["MERCHANT_ID"], @fields["ORDER_NUMBER"], @fields["REFERENCE_NUMBER"], @fields["ORDER_DESCRIPTION"], @fields["CURRENCY"], @fields["RETURN_ADDRESS"], @fields["CANCEL_ADDRESS"], @fields["PENDING_ADDRESS"],
                      @fields["NOTIFY_ADDRESS"], @fields["TYPE"], @fields["CULTURE"], @fields["PRESELECTED_METHOD"], @fields["MODE"], @fields["VISIBLE_METHODS"], @fields["GROUP"], @fields["CONTACT_TELNO"], @fields["CONTACT_CELLNO"],
                      @fields["CONTACT_EMAIL"], @fields["CONTACT_FIRSTNAME"], @fields["CONTACT_LASTNAME"], @fields["CONTACT_COMPANY"], @fields["CONTACT_ADDR_STREET"], @fields["CONTACT_ADDR_ZIP"], @fields["CONTACT_ADDR_CITY"], @fields["CONTACT_ADDR_COUNTRY"], @fields["INCLUDE_VAT"],
                      @fields["ITEMS"]]

            (0..@fields["ITEMS"].to_i-1).each do |i|
              fields += [@fields["ITEM_TITLE[#{i}]"], @fields["ITEM_NO[#{i}]"], @fields["ITEM_AMOUNT[#{i}]"], @fields["ITEM_PRICE[#{i}]"], @fields["ITEM_TAX[#{i}]"], @fields["ITEM_DISCOUNT[#{i}]"], @fields["ITEM_TYPE[#{i}]"]]
            end

            fields = fields.join("|")

            return Digest::MD5.hexdigest(fields).upcase
          end

          # Mappings
          mapping :merchant_id, "MERCHANT_ID"
          mapping :order, "ORDER_NUMBER"
          mapping :reference_number, "REFERENCE_NUMBER"
          mapping :customer, :first_name => "CONTACT_FIRSTNAME",
                             :last_name  => "CONTACT_LASTNAME",
                             :email      => "CONTACT_EMAIL",
                             :phone      => "CONTACT_CELLNO",
                             :tellno     => "CONTACT_TELLNO",
                             :company    => "CONTACT_COMPANY"


          mapping :billing_address, :city     => "CONTACT_ADDR_CITY",
                                    :address1 => "CONTACT_ADDR_STREET",
                                    :address2 => "",
                                    :state    => "",
                                    :zip      => "CONTACT_ADDR_ZIP",
                                    :country  => "CONTACT_ADDR_COUNTRY"

          mapping :notify_url, "NOTIFY_ADDRESS"
          mapping :currency, "CURRENCY"
          mapping :return_url, "RETURN_ADDRESS"
          mapping :cancel_return_url, "CANCEL_ADDRESS"
          mapping :description, "ORDER_DESCRIPTION"
          mapping :tax, ""
          mapping :shipping, ""
          mapping :include_vat, "INCLUDE_VAT"
          mapping :pending_address, "PENDING_ADDRESS"
          mapping :culture, "CULTURE"
          mapping :items, "ITEMS"
          mapping :preselected_method, "PRESELECTED_METHOD"
          mapping :mode, "MODE"
          mapping :visible_methods, "VISIBLE_METHODS"
          mapping :group, "GROUP"

          (0..499.to_i).each do |i|
            mapping "item_title_#{i}".to_sym, "ITEM_TITLE[#{i}]"
            mapping "item_no_#{i}".to_sym, "ITEM_NO[#{i}]"
            mapping "item_amount_#{i}".to_sym, "ITEM_AMOUNT[#{i}]"
            mapping "item_price_#{i}".to_sym, "ITEM_PRICE[#{i}]"
            mapping "item_tax_#{i}".to_sym, "ITEM_TAX[#{i}]"
            mapping "item_discount_#{i}".to_sym, "ITEM_DISCOUNT[#{i}]"
            mapping "item_type_#{i}".to_sym, "ITEM_TYPE[#{i}]"
          end
        end
      end
    end
  end
end
