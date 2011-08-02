require File.dirname(__FILE__) + '/paypal/paypal_common_api'
require File.dirname(__FILE__) + '/paypal/paypal_express_response'
require File.dirname(__FILE__) + '/paypal_express_common'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalRecurringGateway < Gateway
      include PaypalCommonAPI
      include PaypalExpressCommon
      
      self.test_redirect_url = 'https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token='
      self.live_redirect_url = 'https://www.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token='
      # self.supported_countries = ['US']
      # self.homepage_url = 'https://www.paypal.com/cgi-bin/webscr?cmd=xpt/merchant/ExpressCheckoutIntro-outside'
      # self.display_name = 'PayPal Express Checkout Recurring'
      API_VERSION = '59.0'
      
      def setup_authorization(money, options = {})
        requires!(options, :description, :return_url, :cancel_return_url)
        
        commit 'SetExpressCheckout', build_setup_request('Authorization', money, options)
      end
      
      def setup_purchase(money, options = {})
        requires!(options, :return_url, :cancel_return_url)
        
        commit 'SetExpressCheckout', build_setup_request('Sale', money, options)
      end
      
      def details_for(token)
        commit 'GetExpressCheckoutDetails', build_get_details_request(token)
      end
      
      def authorize(money, options = {})
        requires!(options, :token, :payer_id)
      
        commit 'DoExpressCheckoutPayment', build_sale_or_authorization_request('Authorization', money, options)
      end
      
      def purchase(money, options = {})
        requires!(options, :token, :payer_id)
        
        commit 'DoExpressCheckoutPayment', build_sale_or_authorization_request('Sale', money, options)
      end
      
      def get_agreement(token)
        commit 'GetBillingAgreementCustomerDetails', build_get_agreement_request(token)
      end

      def create_profile(token, options = {})
        requires!(options, :description, :start_date, :frequency, :amount)

        commit 'CreateRecurringPaymentsProfile', build_create_profile_request(token, options)
      end

      def get_profile_details(profile_id)
        commit 'GetRecurringPaymentsProfileDetails', build_get_profile_details_request(profile_id)
      end

      def update_profile(profile_id, options = {})
        commit 'UpdateRecurringPaymentsProfile', build_change_profile_request(profile_id, options)
      end

      def cancel_profile(profile_id, options = {})
        commit 'ManageRecurringPaymentsProfileStatus', build_manage_profile_request(profile_id, 'Cancel', options)
      end

      def suspend_profile(profile_id, options = {})
        commit 'ManageRecurringPaymentsProfileStatus', build_manage_profile_request(profile_id, 'Suspend', options)
      end

      def reactivate_profile(profile_id, options = {})
        commit 'ManageRecurringPaymentsProfileStatus', build_manage_profile_request(profile_id, 'Reactivate', options)
      end

      def bill_outstanding_amount(profile_id, options = {})
        commit 'BillOutstandingAmount', build_bill_outstanding_amount(profile_id, options)
      end

      private

      def build_setup_request(action, money, options)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'SetExpressCheckoutReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'SetExpressCheckoutRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'n2:SetExpressCheckoutRequestDetails' do            
              xml.tag! 'n2:BillingAgreementDetails' do
                xml.tag! 'n2:BillingType', 'RecurringPayments'
                xml.tag! 'n2:BillingAgreementDescription', options[:description]
              end
              xml.tag! 'n2:PaymentAction', action
              xml.tag! 'n2:OrderTotal', amount(money).to_f.zero? ? amount(100) : amount(money), 'currencyID' => options[:currency] || currency(money)
              xml.tag! 'n2:AddressOverride', '0'
              xml.tag! 'n2:NoShipping', '1'
              xml.tag! 'n2:ReturnURL', options[:return_url]
              xml.tag! 'n2:CancelURL', options[:cancel_return_url]
              xml.tag! 'n2:IPAddress', options[:ip] unless options[:ip].blank?
              # IMPORTANT: If you want to use Invoice ID, it has to be unique!
              # xml.tag! 'n2:InvoiceID', 'InvoiceID' + Time.now.to_i.to_s
              
              xml.tag! 'n2:AllowNote', '0'
              xml.tag! 'n2:LocaleCode', options[:locale] unless options[:locale].blank?
            end
          end
        end
      
        xml.target!
      end
      
      def build_sale_or_authorization_request(action, money, options)
        currency_code = options[:currency] || currency(money)
        
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'DoExpressCheckoutPaymentReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'DoExpressCheckoutPaymentRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'n2:DoExpressCheckoutPaymentRequestDetails' do
              xml.tag! 'n2:PaymentAction', action
              xml.tag! 'n2:Token', options[:token]
              xml.tag! 'n2:PayerID', options[:payer_id]
              xml.tag! 'n2:PaymentDetails' do
                xml.tag! 'n2:OrderTotal', amount(money), 'currencyID' => currency_code
                
                # All of the values must be included together and add up to the order total
                if [:subtotal, :shipping, :handling, :tax].all?{ |o| options.has_key?(o) }
                  xml.tag! 'n2:ItemTotal', amount(options[:subtotal]), 'currencyID' => currency_code
                  xml.tag! 'n2:ShippingTotal', amount(options[:shipping]),'currencyID' => currency_code
                  xml.tag! 'n2:HandlingTotal', amount(options[:handling]),'currencyID' => currency_code
                  xml.tag! 'n2:TaxTotal', amount(options[:tax]), 'currencyID' => currency_code
                end
                
                xml.tag! 'n2:NotifyURL', options[:notify_url]
                xml.tag! 'n2:ButtonSource', application_id.to_s.slice(0,32) unless application_id.blank?
              end
            end
          end
        end

        xml.target!
      end

      def build_get_agreement_request(token)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'GetBillingAgreementCustomerDetailsReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'GetBillingAgreementCustomerDetailsRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'Token', token
          end
        end

        xml.target!
      end

      def build_get_details_request(token)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'GetExpressCheckoutDetailsReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'GetExpressCheckoutDetailsRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'Token', token
          end
        end

        xml.target!
      end

      def build_create_profile_request(token, options)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'CreateRecurringPaymentsProfileReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'CreateRecurringPaymentsProfileRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'n2:CreateRecurringPaymentsProfileRequestDetails' do
              xml.tag! 'Token', token unless token.blank?
              if options[:credit_card]
               add_credit_card(xml, options[:credit_card], (options[:billing_address] || options[:address]), options)
              end
              xml.tag! 'n2:RecurringPaymentsProfileDetails' do
                xml.tag! 'n2:BillingStartDate', (options[:start_date].is_a?(Date) ? options[:start_date].to_time : options[:start_date]).utc.iso8601
                xml.tag! 'n2:ProfileReference', '151821' # random reference number
                # xml.tag! 'n2:SubscriberName', options[:subscriber_name] unless options[:subscriber_name].blank?
                # add_address(xml, 'n2:SubscriberShippingAddress', (options[:shipping_address] || options[:address])) if options[:shipping_address] || options[:address]
              end
              xml.tag! 'n2:ScheduleDetails' do
                xml.tag! 'n2:Description', options[:description]
                xml.tag! 'n2:PaymentPeriod' do
                  xml.tag! 'n2:BillingPeriod', options[:period] || 'Month'
                  xml.tag! 'n2:BillingFrequency', options[:frequency]
                  xml.tag! 'n2:TotalBillingCycles', options[:cycles] unless options[:cycles].blank?
                  xml.tag! 'n2:Amount', amount(options[:amount]), 'currencyID' => options[:currency] || 'USD'
                  xml.tag! 'n2:TaxAmount', amount(options[:tax_amount] || 0), 'currencyID' => options[:currency] || 'USD'
                end
                if !options[:trialamount].blank?
                  xml.tag! 'n2:TrialPeriod' do
                    xml.tag! 'n2:BillingPeriod', options[:trialperiod] || 'Month'
                    xml.tag! 'n2:BillingFrequency', options[:trialfrequency]
                    xml.tag! 'n2:TotalBillingCycles', options[:trialcycles] || 1
                    xml.tag! 'n2:Amount', amount(options[:trialamount]), 'currencyID' => options[:currency] || 'USD'
                  end        
                end
                if !options[:initial_amount].blank?
                  xml.tag! 'n2:ActivationDetails' do
                    xml.tag! 'n2:InitialAmount', amount(options[:initial_amount]), 'currencyID' => options[:currency] || 'USD'
                    xml.tag! 'n2:FailedInitialAmountAction', options[:continue_on_failure] ? 'ContinueOnFailure' : 'CancelOnFailure'
                  end        
                end
                # xml.tag! 'n2:MaxFailedPayments', options[:max_failed_payments] unless options[:max_failed_payments].blank?
                xml.tag! 'n2:AutoBillOutstandingAmount', options[:auto_bill_outstanding] ? 'AddToNextBilling' : 'NoAutoBill'
              end
            end
          end
        end
        xml.target!
      end

      def build_get_profile_details_request(profile_id)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'GetRecurringPaymentsProfileDetailsReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'GetRecurringPaymentsProfileDetailsRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'ProfileID', profile_id
          end
        end

        xml.target!
      end

      def build_change_profile_request(profile_id, options)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'UpdateRecurringPaymentsProfileReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'UpdateRecurringPaymentsProfileRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'n2:UpdateRecurringPaymentsProfileRequestDetails' do
              xml.tag! 'ProfileID', profile_id
              if options[:credit_card]
               add_credit_card(xml, options[:credit_card], options[:address], options)
              end
              xml.tag! 'n2:Note', options[:note] unless options[:note].blank?
              xml.tag! 'n2:Description', options[:description] unless options[:description].blank?
              xml.tag! 'n2:ProfileReference', options[:reference] unless options[:reference].blank?
              xml.tag! 'n2:AdditionalBillingCycles', options[:additional_billing_cycles] unless options[:additional_billing_cycles].blank?
              xml.tag! 'n2:MaxFailedPayments', options[:max_failed_payments] unless options[:max_failed_payments].blank?
              xml.tag! 'n2:AutoBillOutstandingAmount', options[:auto_bill_outstanding] ? 'AddToNextBilling' : 'NoAutoBill'
              if options.has_key?(:amount)
                xml.tag! 'n2:Amount', amount(options[:amount]), 'currencyID' => options[:currency] || 'USD'
              end
              if options.has_key?(:tax_amount)
                xml.tag! 'n2:TaxAmount', amount(options[:tax_amount] || 0), 'currencyID' => options[:currency] || 'USD'
              end
              if options.has_key?(:start_date)
                xml.tag! 'n2:BillingStartDate', (options[:start_date].is_a?(Date) ? options[:start_date].to_time : options[:start_date]).utc.iso8601
              end
            end
          end
        end

        xml.target!
      end
      
      def build_manage_profile_request(profile_id, action, options)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'ManageRecurringPaymentsProfileStatusReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'ManageRecurringPaymentsProfileStatusRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'n2:ManageRecurringPaymentsProfileStatusRequestDetails' do
              xml.tag! 'ProfileID', profile_id
              xml.tag! 'n2:Action', action
              xml.tag! 'n2:Note', options[:note] unless options[:note].blank?
            end
          end
        end

        xml.target!
      end

      def build_bill_outstanding_amount(profile_id, options)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'BillOutstandingAmountReq', 'xmlns' => PAYPAL_NAMESPACE do
          xml.tag! 'BillOutstandingAmountRequest', 'xmlns:n2' => EBAY_NAMESPACE do
            xml.tag! 'n2:Version', API_VERSION
            xml.tag! 'ProfileID', profile_id
            if options.has_key?(:amount)
              xml.tag! 'n2:Amount', amount(options[:amount]), 'currencyID' => options[:currency] || 'USD'
            end
            xml.tag! 'n2:Note', options[:note] unless options[:note].blank?
          end
        end

        xml.target!
      end

      def add_credit_card(xml, credit_card, address, options)
        xml.tag! 'n2:CreditCard' do
          xml.tag! 'n2:CreditCardType', credit_card_type(card_brand(credit_card))
          xml.tag! 'n2:CreditCardNumber', credit_card.number
          xml.tag! 'n2:ExpMonth', format(credit_card.month, :two_digits)
          xml.tag! 'n2:ExpYear', format(credit_card.year, :four_digits)
          xml.tag! 'n2:CVV2', credit_card.verification_value
          
          if [ 'switch', 'solo' ].include?(card_brand(credit_card).to_s)
            xml.tag! 'n2:StartMonth', format(credit_card.start_month, :two_digits) unless credit_card.start_month.blank?
            xml.tag! 'n2:StartYear', format(credit_card.start_year, :four_digits) unless credit_card.start_year.blank?
            xml.tag! 'n2:IssueNumber', format(credit_card.issue_number, :two_digits) unless credit_card.issue_number.blank?
          end
          
          xml.tag! 'n2:CardOwner' do
            xml.tag! 'n2:PayerName' do
              xml.tag! 'n2:FirstName', credit_card.first_name
              xml.tag! 'n2:LastName', credit_card.last_name
            end
            
            xml.tag! 'n2:Payer', options[:email]
            add_address(xml, 'n2:Address', address) if address
          end
        end
      end

      def credit_card_type(type)
        case type
        when 'visa'             then 'Visa'
        when 'master'           then 'MasterCard'
        when 'discover'         then 'Discover'
        when 'american_express' then 'Amex'
        when 'switch'           then 'Switch'
        when 'solo'             then 'Solo'
        end
      end

      def build_response(success, message, response, options = {})
        PaypalExpressResponse.new(success, message, response, options)
      end
    end
  end
end