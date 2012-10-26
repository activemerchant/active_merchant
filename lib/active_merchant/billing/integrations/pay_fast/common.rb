module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayFast
        module Common
          def generate_signature(type)
            string = case type
            when :request
              request_signature_string
            when :notify
              notify_signature_string
            end

            Digest::MD5.hexdigest(string)
          end

          def request_attributes
            [:merchant_id, :merchant_key, :return_url, :cancel_url,
             :notify_url, :name_first, :name_last, :email_address,
             :payment_id, :amount, :item_name, :item_description,
             :custom_str1, :custom_str2, :custom_str3, :custom_str4,
             :custom_str5, :custom_int1, :custom_int2, :custom_int3,
             :custom_int4, :custom_int5, :email_confirmation,
             :confirmation_address]
          end

          def request_signature_string
            request_attributes.map do |attr|
              "#{mappings[attr]}=#{CGI.escape(@fields[mappings[attr]])}" if @fields[mappings[attr]].present?
            end.compact.join('&')
          end

          def notify_signature_string
            params.map do |key, value|
              "#{key}=#{CGI.escape(value)}" unless key == PayFast.signature_parameter_name
            end.compact.join('&')
          end
        end
      end
    end
  end
end
