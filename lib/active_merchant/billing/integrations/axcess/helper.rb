module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Axcess
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include ActiveMerchant::PostsData
          
          # Replace with the real mapping
          mapping :account, 'USER.LOGIN'
          mapping :credential2, 'USER.PWD'
          mapping :credential3, 'SECURITY.SENDER'
          mapping :credential4, 'TRANSACTION.CHANNEL'
          mapping :amount, 'PRESENTATION.AMOUNT'
          mapping :currency, 'PRESENTATION.CURRENCY'
        
          mapping :order, 'IDENTIFICATION.TRANSACTIONID'

          mapping :customer, :first_name => 'NAME.GIVEN',
                             :last_name  => 'NAME.FAMILY',
                             :email      => 'CONTACT.EMAIL',
                             :phone      => 'CONTACT.PHONE'

          mapping :billing_address, :city     => 'ADDRESS.CITY',
                                    :address => 'ADDRESS.STREET',
                                    :state    => '',
                                    :zip      => 'ADDRESS.ZIP',
                                    :country  => 'ADDRESS.COUNTRY'

          mapping :notify_url, 'FRONTEND.RESPONSE_URL'
          mapping :return_url, 'return_url'
          
          mapping :notify_url, 'notify_url'
          mapping :return_url, 'return_url'

          def get_wpf_url
            add_field('TRANSACTION.MODE',(test?)?'INTEGRATOR_TEST':'LIVE')
            add_field('REQUEST.VERSION','1.0')
            add_field('FRONTEND.ENABLED','true')
            add_field('FRONTEND.POPUP','true')
            add_field('FRONTEND.MODE','DEFAULT')
            add_field('FRONTEND.LANGUAGE','en')
            add_field('PAYMENT.CODE','CC.DB')
            
            @fields['FRONTEND.RESPONSE_URL'] ||= @fields.delete('notify_url')
            
            _url = (test?)?"#{Axcess.test_url}":"#{Axcess.service_url}"
            _data = @fields.map{|k,v| "#{k}=#{CGI.escape(v)}"}.join("&")
            response = ssl_post(_url, _data, 
              'Content-Length' => "#{_data.size}",
              'User-Agent'     => "Active Merchant -- http://activemerchant.org",
              'Content-Type'   => "application/x-www-form-urlencoded; charset=UTF-8"
            )

            raise StandardError.new("Faulty Axcess result") unless response
            
            ret_vals = Hash[*response.split('&').map{|_e| CGI.unescape(_e).split('=',2)}.flatten]  
            
            raise StandardError.new("Faulty Axcess result: #{response}") unless !ret_vals['FRONTEND.REDIRECT_URL'].scan('http').nil? && ret_vals['POST.VALIDATION'] == 'ACK'
            
            return ret_vals['FRONTEND.REDIRECT_URL']
          end
        end
      end
    end
  end
end
