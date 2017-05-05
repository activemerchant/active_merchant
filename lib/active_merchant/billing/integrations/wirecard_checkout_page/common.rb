=begin
 * Shop System Plugins - Terms of use
 *
 * This terms of use regulates warranty and liability between Wirecard Central Eastern Europe (subsequently referred to as WDCEE) and it's
 * contractual partners (subsequently referred to as customer or customers) which are related to the use of plugins provided by WDCEE.
 *
 * The Plugin is provided by WDCEE free of charge for it's customers and must be used for the purpose of WDCEE's payment platform
 * integration only. It explicitly is not part of the general contract between WDCEE and it's customer. The plugin has successfully been tested
 * under specific circumstances which are defined as the shopsystem's standard configuration (vendor's delivery state). The Customer is
 * responsible for testing the plugin's functionality before putting it into production enviroment.
 * The customer uses the plugin at own risk. WDCEE does not guarantee it's full functionality neither does WDCEE assume liability for any
 * disadvantage related to the use of this plugin. By installing the plugin into the shopsystem the customer agrees to the terms of use.
 * Please do not use this plugin if you do not agree to the terms of use!
=end

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module WirecardCheckoutPage
        module Common

          mattr_accessor :paymenttypes
          self.paymenttypes = %w(
              SELECT
              CCARD
              BANCONTACT_MISTERCASH
              C2P
              CCARD-MOTO
              EKONTO
              ELV
              EPS
              GIROPAY
              IDL
              INSTALLMENT
              INSTANTBANK
              INVOICE
              MAESTRO
              MONETA
              MPASS
              PRZELEWY24
              PAYPAL
              PBX
              POLI
              PSC
              QUICK
              SKRILLDIRECT
              SKRILLWALLET
              SOFORTUEBERWEISUNG)

          def message
            @message
          end

          def verify_response(params, secret)

            logstr = ''
            params.each { |key, value|
              logstr += "#{key} #{value}\n"
            }

            @paymentstate = 'FAILURE'

            unless params.has_key?('paymentState')
              @message = "paymentState is missing"
              return false
            end

            if params['paymentState'] == 'SUCCESS' || params['paymentState'] == 'PENDING'
              unless params.has_key?('responseFingerprint')
                @message = "responseFingerprint is missing"
                return false
              end

              unless params.has_key?('responseFingerprintOrder')
                @message = "responseFingerprintOrder is missing"
                return false
              end

            end

            if params['paymentState'] == 'SUCCESS' || params['paymentState'] == 'PENDING'
              fields = params['responseFingerprintOrder'].split(",")
              values = ''
              fields.each { |f|
                values += f == 'secret' ? secret : params[f]
              }


              if Digest::MD5.hexdigest(values) != params['responseFingerprint']
                @message = "responseFingerprint verification failed"
                return false
              end
            end

            @paymentstate = params['paymentState']
            true
          end

        end

      end
    end
  end
end
