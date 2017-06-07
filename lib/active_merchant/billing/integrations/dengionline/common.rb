module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dengionline
        module Common
          
          # url
          def service_url
            @service_url || ActiveMerchant::Billing::Integrations::Dengionline.service_url
          end
          
          def service_url= (value)
            @service_url = value || ActiveMerchant::Billing::Integrations::Dengionline.service_url
          end
          
          # pay method
          def pay_method
            @pay_method
          end
          
          def pay_method= (value)
            methods =  [ :general, :easypay, :mailru, :alfaclick, :qiwi, :mobile, :remittance, :credit_card ]
            @pay_method = methods.include?(value) ? value : methods[0]
          end
          
          def general?;     @pay_method == :general;      end
          def easypay?;     @pay_method == :easypay;      end
          def mailru?;      @pay_method == :mailru;       end
          def qiwi?;        @pay_method == :qiwi;         end
          def mobile?;      @pay_method == :mobile;       end
          def remittance?;  @pay_method == :remittance;   end
          def credit_card?; @pay_method == :credit_card;  end
          def alfaclick?;   @pay_method == :alfaclick;    end
          
          # background
          def background
            @background
          end
          
          def background= (value)
            if [:qiwi, :mobile, :credit_card, :alfaclick].include?(@pay_method)
              @background = value == :background
            elsif @pay_method == :remittance
              @background = true
            else
              @background = false
            end
          end
          
          def background?
            @background
          end
          
          # secret
          def secret
            @secret
          end
          
          def secret= (value)
            @secret = value.to_s
          end
          
          # hash generators
          def generate_qiwi_signature
            amount = params['amount'].to_s.gsub(/(\.\d*?)0*$/, '\1').gsub(/\.$/, '')
            s = secret + params['project'].to_s + params['nickname'].to_s + amount + params['qiwi_phone'].to_s + secret
            Digest::MD5.hexdigest s.downcase
          end
          
          def generate_mobile_signature
            amount = params['amount'].to_s.gsub(/(\.\d*?)0*$/, '\1').gsub(/\.$/, '')
            s = secret + params['project'].to_s + params['nickname'].to_s + amount + params['qiwi_phone'].to_s + secret
            Digest::MD5.hexdigest s.downcase
          end
          
          def generate_remittance_signature
            amount = params['amount'].to_s.gsub(/(\.\d*?)0*$/, '\1').gsub(/\.$/, '')
            s = secret + params['project'].to_s + amount + params['mode_type'].to_s + params['source'].to_s + params['order_id'].to_s
            Digest::MD5.hexdigest s
          end
          
        end
      end
    end
  end
end
