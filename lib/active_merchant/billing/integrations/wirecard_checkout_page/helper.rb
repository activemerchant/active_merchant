module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module WirecardCheckoutPage
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include Common

          PLUGIN_NAME = 'ActiveMerchant_WirecardCheckoutPage'
          PLUGIN_VERSION = '1.0.0'

          # Replace with the real mapping
          mapping :account, 'customerId'
          mapping :amount, 'amount'

          mapping :order, 'xActiveMerchantOrderId'

          mapping :customer, :first_name => 'consumerBillingFirstName',
                  :last_name => 'consumerBillingLastName',
                  :email => 'consumerEmail',
                  :phone => 'consumerBillingPhone',
                  :ipaddress => 'consumerIpAddress',
                  :user_agent => 'consumerUserAgent',
                  :fax => 'consumerBillingFax',
                  :birthdate => 'consumerBirthDate' # mandatory for INVOICE and INSTALLMENT

          mapping :billing_address, :city => 'consumerBillingCity',
                  :address1 => 'consumerBillingAddress1',
                  :address2 => 'consumerBillingAddress2',
                  :state => 'consumerBillingState',
                  :zip => 'consumerBillingZipCode',
                  :country => 'consumerBillingCountry'

          mapping :shipping_address, :first_name => 'consumerShippingFirstName',
                  :last_name => 'consumerShippingLastName',
                  :address1 => 'consumerShippingAddress1',
                  :address2 => 'consumerShippingAddress2',
                  :city => 'consumerShippingCity',
                  :state => 'consumerShippingState',
                  :country => 'consumerShippingCountry',
                  :zip => 'consumerShippingZipCode',
                  :phone => 'consumerShippingPhone',
                  :fax => 'consumerShippingFax'

          mapping :currency, 'currency'
          mapping :language, 'language' # language for displayed texts on payment page

          mapping :description, 'orderDescription' # unique description of the consumer's order in a human readable form

          mapping :shop_service_url, 'serviceUrl' # URL of your service page containing contact information

          mapping :notify_url, 'confirmUrl'
          mapping :return_url, 'successUrl'

          # defaulting to return_url
          mapping :cancel_return_url, 'cancelUrl'
          mapping :pending_url, 'pendingUrl'
          mapping :failure_url, 'failureUrl'

          # optional parameters
          mapping :window_name, 'windowName' # window.name of browser window where payment page is opened
          mapping :duplicate_request_check, 'duplicateRequestCheck' # check for duplicate requests done by your consumer
          mapping :customer_statement, 'customerStatement' # text displayed on invoice of financial institution of your consumer
          mapping :order_reference, 'orderReference' # unique order reference id sent from merchant to financial institution
          mapping :display_text, 'displayText' # text displayed to your consumer within the payment page
          mapping :image_url, 'imageUrl' #  URL of your web shop where your web shop logo is located
          mapping :max_retries, 'maxRetries' # maximum number of attempted payments for the same order
          mapping :auto_deposit, 'autoDeposit' # enable automated debiting of payments
          mapping :financial_institution, 'financialInstitution' # based on pre-selected payment type a sub-selection of financial institutions regarding to pre-selected payment type

          # not used
          mapping :tax, ''
          mapping :shipping, ''

          def initialize(order, customer_id, options = {})
            @paymenttype = options.delete(:paymenttype)

            raise "Unknown Paymenttype: " + @paymenttype if paymenttypes.find_index(@paymenttype) == nil

            @secret = options.delete(:secret)
            @customer_id = customer_id
            @shop_id = options.delete(:shop_id)
            super
          end

          def add_version(shop_name, shop_version)
            add_field('pluginVersion', Base64.encode64(shop_name + ';' + shop_version + ';ActiveMerchant;' + PLUGIN_NAME + ';' + PLUGIN_VERSION))
          end

          def add_standard_fields
            addfields = {}
            addfields['shopId'] = @shop_id if !@shop_id.blank?
            addfields['paymentType'] = @paymenttype

            addfields[mappings[:pending_url]] = @fields[mappings[:return_url]] unless @fields.has_key?(mappings[:pending_url])
            addfields[mappings[:cancel_return_url]] = @fields[mappings[:return_url]] unless @fields.has_key?(mappings[:cancel_return_url])
            addfields[mappings[:failure_url]] = @fields[mappings[:return_url]] unless @fields.has_key?(mappings[:failure_url])

            addfields
          end

          def add_request_fingerprint(fpfields)
            addfields = {}
            fingerprint_order = %w(secret)
            fingerprint_values = @secret.to_s
            fpfields.each { |key, value|
              next if key == 'pluginVersion'
              fingerprint_order.append key
              fingerprint_values += value.to_s
            }

            fingerprint_order.append 'requestFingerprintOrder'
            fingerprint_values += fingerprint_order.join(',')

            addfields['requestFingerprintOrder'] = fingerprint_order.join(',')
            addfields['requestFingerprint'] = Digest::MD5.hexdigest(fingerprint_values)

            return addfields
          end

          def form_fields
            result = {}
            result.merge!(@fields)
            result.merge!(add_standard_fields)
            result.merge!(add_request_fingerprint(result))
            result
          end

          def secret
            @secret
          end

          def customer_id
            @customer_id
          end

          def shop_id
            @shop_id
          end

        end

      end
    end
  end
end