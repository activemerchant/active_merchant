module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Axcess
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          # Replace with the real mapping
          mapping :account, 'USER.LOGIN'
          mapping :password, 'USER.PWD'
          mapping :sender, 'SECURITY.SENDER'
          mapping :channel, 'TRANSACTION.CHANNEL'
          mapping :amount, 'PRESENTATION.AMOUNT'
          mapping :currency, 'PRESENTATION.CURRENCY'
        
          mapping :order, 'IDENTIFICATION.TRANSACTIONID'

          mapping :customer, :first_name => 'NAME.GIVEN',
                             :last_name  => 'NAME.FAMILY',
                             :email      => 'CONTACT.EMAIL',
                             :phone      => 'CONTACT.PHONE'

          mapping :billing_address, :city     => 'ADDRESS.CITY',
                                    :address1 => 'ADDRESS.STREET',
                                    :address2 => '',
                                    :state    => '',
                                    :zip      => 'ADDRESS.ZIP',
                                    :country  => 'ADDRESS.COUNTRY'

          mapping :notify_url, 'FRONTEND.RESPONSE_URL'
          mapping :return_url, ''
          mapping :cancel_return_url, ''
          mapping :description, ''
          mapping :tax, ''
          mapping :shipping, ''
          
          def redirect_to_wpf
            add_field('TRANSACTION.MODE',(test?)?'INTEGRATOR_TEST':'LIVE')
            add_field('REQUEST.VERSION','1.0')
            add_field('FRONTEND.ENABLED','true')
            add_field('FRONTEND.POPUP','true')
            add_field('FRONTEND.MODE','DEFAULT')
            add_field('FRONTEND.LANGUAGE','en')
            add_field('PAYMENT.CODE','CC.DB')
            
            response = ssl_post((test?)?"#{test_url}":"#{service_url}", @fields, 
              'Content-Length' => "#{@fields.size}",
              'User-Agent'     => "Active Merchant -- http://activemerchant.org",
              'Content-Type'   => "application/x-www-form-urlencoded"
            )

            raise StandardError.new("Faulty Axcess result: #{response}") unless response = Net::HTTPSuccess
            
            ret_vals = Hash[*response.body.split('&').map{|_e| URI.unescape(_e).split('=',2)}.flatten]  
            
            raise StandardError.new("Faulty Axcess result: #{response}") unless ret_vals['FRONTEND.REDIRECT_URL'].scan('http') && ret_vals['POST.VALIDATION'] == 'ACK'
            
            redirect_to ret_vals['FRONTEND.REDIRECT_URL']
          end
        end
      end
    end
  end
end
