require 'net/http'
require File.dirname(__FILE__) + '/currency.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayVector
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def complete?
            status == "Completed"
          end

          def item_id
            params['OrderID']
          end

          def transaction_id
            params['CrossReference']
          end
          
          def message
            params['Message']
          end
          
          def card_type
            params['CardType']
          end

          # When was this payment received by the client.
          def received_at
            params['TransactionDateTime']
          end

          def payer_email
            params['EmailAddress']
          end

          def security_key
            params['HashDigest']
          end

          # the money amount we received in X.2 decimal.
          def gross
            exponent = ActiveMerchant::Billing::Integrations::PayVector::ISOCurrencies::get_exponent_from_ISO_code(@params["CurrencyCode"])
            gross = @params['Amount'].to_f
            gross /= 10**exponent
            gross = sprintf('%.0' + exponent.to_i.to_s + 'f', gross)
          end
          
          def currency
            ActiveMerchant::Billing::Integrations::PayVector::ISOCurrencies::get_short_from_ISO_code(@params["CurrencyCode"])
          end

          # No way to tell if using a test transaction as the only difference is in authentication credentials
          def test?
            params[''] == 'test'
          end

          def status
            if(params['StatusCode'] == "0")
              return "Completed"
            elsif(params['StatusCode'] == "20" && params['PreviousStatusCode'] == "0")
              return "Duplicate transaction"
            else
              return "Failed"
            end
          end

          # Acknowledge the transaction to PayVector. This method has to be called after a new
          # apc arrives. PayVector will verify that all the information we received is correct and will return an
          # ok or a fail.
          def acknowledge(authcode = nil)
            if(security_key.blank? || @options[:credential2].blank? || @options[:credential3].blank?)
              return false
            end

            return generate_hash_digest == security_key
          end

          private

          # Take the posted data and move the relevant data into a hash
          def parse(post)
            @raw = post.to_s
            for line in @raw.split('&')
              key, value = *line.scan( %r{^([A-Za-z0-9_.-]+)\=(.*)$} ).flatten
              params[key] = CGI.unescape(value.to_s) if key.present?
            end
          end
          
          def generate_hash_digest
            stringToHash = 
            "PreSharedKey=" + @options[:credential3] +
            "&MerchantID=" + @params["MerchantID"] +
            "&Password=" + @options[:credential2] +
            "&StatusCode=" + @params["StatusCode"] +
            "&Message=" + @params["Message"] +
            "&PreviousStatusCode=" + @params["PreviousStatusCode"] +
            "&PreviousMessage=" + @params["PreviousMessage"] +
            "&CrossReference=" + @params["CrossReference"] +
            "&AddressNumericCheckResult=" + @params["AddressNumericCheckResult"] +
            "&PostCodeCheckResult=" + @params["PostCodeCheckResult"] +
            "&CV2CheckResult=" + @params["CV2CheckResult"] +
            "&ThreeDSecureAuthenticationCheckResult=" + @params["ThreeDSecureAuthenticationCheckResult"] +
            "&CardType=" + @params["CardType"] +
            "&CardClass=" + @params["CardClass"] +
            "&CardIssuer=" + @params["CardIssuer"] +
            "&CardIssuerCountryCode=" + @params["CardIssuerCountryCode"] +
            "&Amount=" + @params["Amount"] +
            "&CurrencyCode=" + @params["CurrencyCode"] +
            "&OrderID=" + @params["OrderID"] +
            "&TransactionType=" + @params["TransactionType"] +
            "&TransactionDateTime=" + @params["TransactionDateTime"] +
            "&OrderDescription=" + @params["OrderDescription"] +
            "&CustomerName=" + @params["CustomerName"] +
            "&Address1=" + @params["Address1"] +
            "&Address2=" + @params["Address2"] +
            "&Address3=" + @params["Address3"] +
            "&Address4=" + @params["Address4"] +
            "&City=" + @params["City"] +
            "&State=" + @params["State"] +
            "&PostCode=" + @params["PostCode"] +
            "&CountryCode=" + @params["CountryCode"] +
            "&EmailAddress=" + @params["EmailAddress"] +
            "&PhoneNumber=" + @params["PhoneNumber"]
            
            return Digest::SHA1.hexdigest stringToHash
          end
          
        end
      end
    end
  end
end
