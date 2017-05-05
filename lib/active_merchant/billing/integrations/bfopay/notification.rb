require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Bfopay
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          %w(
            MemberID
            TerminalID
            TransID
            Result
            ResultDesc
            FactMoney
            AdditionalInfo
            SuccTime
            Md5Sign
          ).each do |param_name|
            define_method(param_name.underscore){ params[param_name] }
          end

          alias_method :account, :member_id
          alias_method :amount, :fact_money
          alias_method :order, :trans_id

          def acknowledge
            md5_sign == generate_signature
          end

          def generate_signature_string
            #{}"MemberID=#{member_id}~|~TerminalID=#{terminal_id}~|~TransID=#{TransID}~|~Result=#{Result}~|~ResultDesc=#{resultDesc}~|~FactMoney=#{FactMoney}~|~AdditionalInfo=#{additionalInfo}~|~SuccTime=#{SuccTime}~|~Md5Sign=#{
            %w(
              MemberID
              TerminalID
              TransID
              Result
              ResultDesc
              FactMoney
              AdditionalInfo
              SuccTime
            ).map{|key| "#{key}=#{params[key]}" }.join('~|~') + "~|~Md5Sign=#{@options[:secret]}"
          end

          def generate_signature
            Digest::MD5.hexdigest(generate_signature_string).downcase
          end

          def amount
            fact_money.to_f * 0.01
          end

        end
      end
    end
  end
end
