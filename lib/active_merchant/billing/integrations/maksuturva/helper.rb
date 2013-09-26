module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Maksuturva
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order, account, options = {})
            md5secret options.delete(:credential2)
            super
            add_field("pmt_action", "NEW_PAYMENT_EXTENDED")
            add_field("pmt_version", "0004")
            add_field("pmt_sellerid", account)
            add_field("pmt_hashversion", "MD5")
          end

          def md5secret(value)
            @md5secret = value
          end

          def form_fields
            @fields.merge("pmt_hash" => generate_md5string)
          end

          def generate_md5string
            fields = [@fields["pmt_action"], @fields["pmt_version"]]
            fields += [@fields["pmt_selleriban"]] unless @fields["pmt_selleriban"].nil?
            fields += [@fields["pmt_id"], @fields["pmt_orderid"], @fields["pmt_reference"], @fields["pmt_duedate"],
            @fields["pmt_amount"], @fields["pmt_currency"], @fields["pmt_okreturn"], @fields["pmt_errorreturn"], @fields["pmt_cancelreturn"],
            @fields["pmt_delayedpayreturn"], @fields["pmt_escrow"], @fields["pmt_escrowchangeallowed"]]

            fields += [@fields["pmt_invoicefromseller"]] unless @fields["pmt_invoicefromseller"].nil?
            fields += [@fields["pmt_paymentmethod"]] unless @fields["pmt_paymentmethod"].nil?
            fields += [@fields["pmt_buyeridentificationcode"]] unless @fields["pmt_buyeridentificationcode"].nil?


            fields += [@fields["pmt_buyername"], @fields["pmt_buyeraddress"], @fields["pmt_buyerpostalcode"], @fields["pmt_buyercity"],
            @fields["pmt_buyercountry"], @fields["pmt_deliveryname"], @fields["pmt_deliveryaddress"], @fields["pmt_deliverypostalcode"], @fields["pmt_deliverycity"],
            @fields["pmt_deliverycountry"], @fields["pmt_sellercosts"]]

            (1..@fields["pmt_rows"].to_i).each do |i|
              fields += [@fields["pmt_row_name#{i}"], @fields["pmt_row_desc#{i}"], @fields["pmt_row_quantity#{i}"]]
              fields += [@fields["pmt_row_articlenr#{i}"]] unless @fields["pmt_row_articlenr#{i}"].nil?
              fields += [@fields["pmt_row_unit#{i}"]] unless @fields["pmt_row_unit#{i}"].nil?
              fields += [@fields["pmt_row_deliverydate#{i}"]]
              fields += [@fields["pmt_row_price_gross#{i}"]] unless @fields["pmt_row_price_gross#{i}"].nil?
              fields += [@fields["pmt_row_price_net#{i}"]] unless @fields["pmt_row_price_net#{i}"].nil?
              fields += [@fields["pmt_row_vat#{i}"], @fields["pmt_row_discountpercentage#{i}"], @fields["pmt_row_type#{i}"]]
            end
            fields += [@md5secret]
            fields = fields.join("&") + "&"
            Digest::MD5.hexdigest(fields).upcase
          end

          mapping :pmt_selleriban, "pmt_selleriban"
          mapping :pmt_reference, "pmt_reference"
          mapping :pmt_duedate, "pmt_duedate"
          mapping :pmt_userlocale, "pmt_userlocale"
          mapping :pmt_escrow, "pmt_escrow"
          mapping :pmt_escrowchangeallowed, "pmt_escrowchangeallowed"
          mapping :pmt_invoicefromseller, "pmt_invoicefromseller"
          mapping :pmt_paymentmethod, "pmt_paymentmethod"
          mapping :pmt_buyeridentificationcode, "pmt_buyeridentificationcode"
          mapping :pmt_buyername, "pmt_buyername"

          mapping :account, ''
          mapping :currency, 'pmt_currency'
          mapping :amount, 'pmt_amount'

          mapping :order, 'pmt_id'
          mapping :pmt_orderid, 'pmt_orderid'
          mapping :pmt_deliveryname, "pmt_deliveryname"
          mapping :pmt_deliveryaddress, "pmt_deliveryaddress"
          mapping :pmt_deliverypostalcode, "pmt_deliverypostalcode"
          mapping :pmt_deliverycity, "pmt_deliverycity"
          mapping :pmt_deliverycountry, "pmt_deliverycountry"
          mapping :pmt_sellercosts, "pmt_sellercosts"
          mapping :pmt_rows, "pmt_rows"

          (1..499.to_i).each do |i|
            mapping "pmt_row_name#{i}".to_sym, "pmt_row_name#{i}"
            mapping "pmt_row_desc#{i}".to_sym, "pmt_row_desc#{i}"
            mapping "pmt_row_quantity#{i}".to_sym, "pmt_row_quantity#{i}"
            mapping "pmt_row_articlenr#{i}".to_sym, "pmt_row_articlenr#{i}"
            mapping "pmt_row_unit#{i}".to_sym, "pmt_row_unit#{i}"
            mapping "pmt_row_deliverydate#{i}".to_sym, "pmt_row_deliverydate#{i}"
            mapping "pmt_row_price_gross#{i}".to_sym, "pmt_row_price_gross#{i}"
            mapping "pmt_row_price_net#{i}".to_sym, "pmt_row_price_net#{i}"
            mapping "pmt_row_vat#{i}".to_sym, "pmt_row_vat#{i}"
            mapping "pmt_row_discountpercentage#{i}".to_sym, "pmt_row_discountpercentage#{i}"
            mapping "pmt_row_type#{i}".to_sym, "pmt_row_type#{i}"
          end

          mapping :pmt_charset, "pmt_charset"
          mapping :pmt_charsethttp, "pmt_charsethttp"
          mapping :pmt_hashversion, "pmt_hashversion"
          mapping :pmt_keygeneration, "pmt_keygeneration"
          mapping :customer, :email      => 'pmt_buyeremail',
                             :phone      => 'pmt_buyerphone'

          mapping :billing_address, :city     => 'pmt_buyercity',
                                    :address1 => "pmt_buyeraddress",
                                    :address2 => '',
                                    :state    => '',
                                    :zip      => "pmt_buyerpostalcode",
                                    :country  => 'pmt_buyercountry'

          mapping :notify_url, ''
          mapping :return_url, 'pmt_okreturn'
          mapping :pmt_errorreturn, 'pmt_errorreturn'
          mapping :pmt_delayedpayreturn, 'pmt_delayedpayreturn'
          mapping :cancel_return_url, 'pmt_cancelreturn'

          mapping :description, ''
          mapping :tax, ''
          mapping :shipping, ''
        end
      end
    end
  end
end
