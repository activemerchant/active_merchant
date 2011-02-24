module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Moneybookers
        class Helper < ActiveMerchant::Billing::Integrations::Helper

					mapping :account, 'pay_to_email'
					mapping :order, 'transaction_id'
          mapping :amount, 'amount'
					mapping :currency, 'currency'
          mapping :customer, :first_name => 'firstname',
						:last_name  => 'lastname',
						:email      => 'pay_from_email',
						:phone      => 'phone_number'

          mapping :billing_address, :city     => 'city',
						:address1 => 'address',
						:address2 => 'address2',
						:state    => 'state',
						:zip      => 'postal_code',
						:country  => 'country'

          mapping :notify_url, 'status_url'
          mapping :return_url, 'return_url'
          mapping :cancel_return_url, 'cancel_url'
          mapping :description, 'detail1_text'
          mapping :tax, ''
          mapping :shipping, ''

				
					mapping :recipient_description, 'recipient_description'
					mapping :return_url_text, 'return_url_text'
					mapping :return_url_target, 'return_url_target'
					mapping :cancel_url_text, 'cancel_url_text'
					mapping :status_url2, 'status_url2'
					mapping :language, 'language'
					mapping :hide_login, 'hide_login'
					mapping :confirmation_note, 'confirmation_note'
					mapping :logo_url, 'logo_url'
					mapping :title, 'title'
					mapping :date_of_birth, 'date_of_birth'
					mapping :amount2_description, 'amount2_description'
					mapping :amount2, 'amount2'
					mapping :amount3_description, 'amount3_description'
					mapping :amount3, 'amount3'
					mapping :amount4_description, 'amount4_description'
					mapping :amount4, 'amount4'
					mapping :detail1_description, 'detail1_description'
					mapping :detail1_text, 'detail1_text'
					mapping :detail2_description, 'detail2_description'
					mapping :detail2_text, 'detail2_text'
					mapping :detail3_description, 'detail3_description'
					mapping :detail3_text, 'detail3_text'
					mapping :detail4_description, 'detail4_description'
					mapping :detail4_text, 'detail4_text'
					mapping :detail5_description, 'detail5_description'
					mapping :detail5_text, 'detail5_text'


        end
      end
    end
  end
end
