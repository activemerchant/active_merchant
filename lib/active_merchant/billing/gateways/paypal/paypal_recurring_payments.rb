# Full Credit goes to http://blog.matthodan.com/how-to-add-support-for-paypal-website-payment
# Matt's patch work well, so I'm rolling it into a personal git as I've used it on a few projects now 

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalGateway < Gateway
      
      RECURRING_ACTIONS = Set.new([:add, :modify, :inquiry, :suspend, :reactivate, :cancel])
      
      # Creates a recurring profile
      def create_recurring_profile(*args) #:nodoc:
        request = build_recurring_request(:add, *args)
        commit('CreateRecurringPaymentsProfile', request)
      end
      
      # Updates a recurring profile
      def update_recurring_profile(*args) #:nodoc:
        request = build_recurring_request(:modify, *args)
        commit('UpdateRecurringPaymentsProfile', request)
      end
      
      # Retrieves information about a recurring profile
      def get_recurring_profile(*args) #:nodoc:
        request = build_recurring_request(:inquiry, *args)
        commit('GetRecurringPaymentsProfileDetails', request)
      end
      
      # Suspends a recurring profile
      def suspend_recurring_profile(*args) #:nodoc:
        request = build_recurring_request(:suspend, *args)
        commit('ManageRecurringPaymentsProfileStatus', request)
      end
      
      # Reactivates a previously suspended recurring profile
      def reactivate_recurring_profile(*args) #:nodoc:
        request = build_recurring_request(:reactivate, *args)
        commit('ManageRecurringPaymentsProfileStatus', request)
      end
      
      # Cancels an existing recurring profile
      def cancel_recurring_profile(*args) #:nodoc:
        request = build_recurring_request(:cancel, *args)
        commit('ManageRecurringPaymentsProfileStatus', request)
      end
      
    private
    
      def build_recurring_request(action, *args) #:nodoc:
        unless RECURRING_ACTIONS.include?(action)
          raise ArgumentError, "Invalid Recurring Profile Action: #{action}"
        end
        
        xml = Builder::XmlMarkup.new :indent => 2
        ns2 = 'n2:'
        
        profile_id = args.first[:profile_id] unless args.first[:profile_id].blank?
        note = args.first[:note] unless args.first[:note].blank?
        credit_card = args.first[:credit_card] unless args.first[:credit_card].blank?
        recurring = args.first[:recurring] unless args.first[:recurring].blank?
        initial = args.first[:initial] unless args.first[:initial].blank?
        trial = args.first[:trial] unless args.first[:trial].blank?
        currency = args.first[:currency] unless args.first[:currency].blank?
        
        if [:add].include?(action)
          xml.tag!('CreateRecurringPaymentsProfileReq', 'xmlns' => PAYPAL_NAMESPACE) do
            xml.tag!('CreateRecurringPaymentsProfileRequest', 'xmlns:n2' => EBAY_NAMESPACE) do
              xml.tag!(ns2 + 'Version', API_VERSION)
              xml.tag!(ns2 + 'CreateRecurringPaymentsProfileRequestDetails') do
                
                xml.tag!(ns2 + 'CreditCard') do
                  xml.tag!(ns2 + 'CreditCardType', credit_card[:type].capitalize) # Required
                  xml.tag!(ns2 + 'CreditCardNumber', credit_card[:number]) # Required
                  xml.tag!(ns2 + 'ExpMonth', format(credit_card[:month], :two_digits)) # Required
                  xml.tag!(ns2 + 'ExpYear', format(credit_card[:year], :four_digits)) # Required
                  xml.tag!(ns2 + 'CVV2', credit_card[:verification_value]) # Required
                  if ['switch', 'solo'].include?(credit_card[:type].downcase) # Needed for Maestro/Switch and Solo cards only
                    xml.tag!(ns2 + 'StartMonth', format(credit_card[:start_month], :two_digits)) unless credit_card[:start_month].blank? # Required if Switch or Solo, unless Issue Number provided
                    xml.tag!(ns2 + 'StartYear', format(credit_card[:start_year], :four_digits)) unless credit_card[:start_year].blank? # Required if Switch or Solo, unless Issue Number provided
                    xml.tag!(ns2 + 'IssueNumber', format(credit_card[:issue_number], :two_digits)) unless credit_card[:issue_number].blank? # Required if Switch or Solo, unless Issue Number provided
                  end
                  
                  xml.tag!(ns2 + 'CardOwner') do
                    xml.tag!(ns2 + 'PayerName') do
                      xml.tag!(ns2 + 'FirstName', credit_card[:first_name]) # Required
                      xml.tag!(ns2 + 'LastName', credit_card[:last_name]) # Required
                    end
                    
                    xml.tag!(ns2 + 'Payer', credit_card[:email]) # Required
                    
                    xml.tag!(ns2 + 'Address') do
                      xml.tag!(ns2 + 'Street1', credit_card[:street_1]) # Required
                      xml.tag!(ns2 + 'Street2', credit_card[:street_2]) unless credit_card[:street_2].blank? # Optional
                      xml.tag!(ns2 + 'CityName', credit_card[:city]) # Required
                      xml.tag!(ns2 + 'StateOrProvince', credit_card[:state]) # Required
                      xml.tag!(ns2 + 'PostalCode', credit_card[:zip]) # Required
                      xml.tag!(ns2 + 'Country', credit_card[:country]) # Required
                    end
                  end
                end
                
                xml.tag!(ns2 + 'RecurringPaymentsProfileDetails') do
                  xml.tag!(ns2 + 'BillingStartDate', recurring[:billing_start_date]) # Required
                end
                
                xml.tag!(ns2 + 'ScheduleDetails') do
                  xml.tag!(ns2 + 'Description', recurring[:description]) # Required
                  
                  frequency, period = get_pay_period(recurring[:periodicity])
                  xml.tag!(ns2 + 'PaymentPeriod') do
                    xml.tag!(ns2 + 'BillingPeriod', period) # Required
                    xml.tag!(ns2 + 'BillingFrequency', frequency.to_s) # Required
                    xml.tag!(ns2 + 'Amount', amount(recurring[:amount]), 'currencyID' => currency) # Required
                    xml.tag!(ns2 + 'TotalBillingCycles', recurring[:total_billing_cycles]) unless recurring[:total_billing_cycles].blank? # Optional
                  end
                  
                  xml.tag!(ns2 + 'MaxFailedPayments', recurring[:max_failed_payments]) unless recurring[:max_failed_payments].blank? # Optional
                  xml.tag!(ns2 + 'AutoBillOutstandingAmount', recurring[:auto_bill_outstanding_amount] ? 'AddToNextBilling' : 'NoAutoBill') # Required
                  
                  unless trial.blank? # Optional
                    frequency, period = get_pay_period(trial[:periodicity])
                    xml.tag!(ns2 + 'TrialPeriod') do
                      xml.tag!(ns2 + 'BillingPeriod', period) # Required
                      xml.tag!(ns2 + 'BillingFrequency', frequency.to_s) # Required
                      xml.tag!(ns2 + 'Amount', amount(trial[:amount]), 'currencyID' => currency) # Required
                      xml.tag!(ns2 + 'TotalBillingCycles', trial[:total_billing_cycles]) # Required
                    end
                  end
                  
                  unless initial.blank? # Optional
                    xml.tag!(ns2 + 'ActivationDetails') do
                      xml.tag!(ns2 + 'InitialAmount', amount(initial[:amount]), 'currencyID' => currency) # Required
                      xml.tag!(ns2 + 'FailedInitialAmountAction', initial[:failure_action]) unless initial[:failure_action].blank? # Optional
                    end
                  end
                  
                end
              end
            end
          end
        elsif [:modify].include?(action)
          xml.tag!('UpdateRecurringPaymentsProfileReq', 'xmlns' => PAYPAL_NAMESPACE) do
            xml.tag!('UpdateRecurringPaymentsProfileRequest', 'xmlns:n2' => EBAY_NAMESPACE) do
              xml.tag!(ns2 + 'Version', API_VERSION)
              xml.tag!(ns2 + 'UpdateRecurringPaymentsProfileRequestDetails') do
                
                xml.tag!(ns2 + 'ProfileID', profile_id) # Required
                xml.tag!(ns2 + 'Note', note) unless note.blank? # Optional
                
                unless credit_card.blank? # Optional
                  xml.tag!(ns2 + 'CreditCard') do
                    xml.tag!(ns2 + 'CreditCardType', credit_card[:type].capitalize) # Required
                    xml.tag!(ns2 + 'CreditCardNumber', credit_card[:number]) # Required
                    xml.tag!(ns2 + 'ExpMonth', format(credit_card[:month], :two_digits)) # Required
                    xml.tag!(ns2 + 'ExpYear', format(credit_card[:year], :four_digits)) # Required
                    xml.tag!(ns2 + 'CVV2', credit_card[:verification_value]) # Required
                    if ['switch', 'solo'].include?(credit_card[:type].downcase) # Needed for Maestro/Switch and Solo cards only
                      xml.tag!(ns2 + 'StartMonth', format(credit_card[:start_month], :two_digits)) unless credit_card[:start_month].blank? # Required if Switch or Solo, unless Issue Number provided
                      xml.tag!(ns2 + 'StartYear', format(credit_card[:start_year], :four_digits)) unless credit_card[:start_year].blank? # Required if Switch or Solo, unless Issue Number provided
                      xml.tag!(ns2 + 'IssueNumber', format(credit_card[:issue_number], :two_digits)) unless credit_card[:issue_number].blank? # Required if Switch or Solo, unless Issue Number provided
                    end
                    
                    xml.tag!(ns2 + 'CardOwner') do
                      xml.tag!(ns2 + 'PayerName') do
                        xml.tag!(ns2 + 'FirstName', credit_card[:first_name]) # Required
                        xml.tag!(ns2 + 'LastName', credit_card[:last_name]) # Required
                      end
                      
                      xml.tag!(ns2 + 'Payer', credit_card[:email]) unless credit_card[:email].blank? # Optional
                      
                      xml.tag!(ns2 + 'Address') do # Required
                        xml.tag!(ns2 + 'Street1', credit_card[:street_1]) # Required
                        xml.tag!(ns2 + 'Street2', credit_card[:street_2]) unless credit_card[:street_2].blank? # Optional
                        xml.tag!(ns2 + 'CityName', credit_card[:city]) # Required
                        xml.tag!(ns2 + 'StateOrProvince', credit_card[:state]) # Required
                        xml.tag!(ns2 + 'PostalCode', credit_card[:zip]) # Required
                        xml.tag!(ns2 + 'Country', credit_card[:country]) # Required
                      end
                    end
                  end
                end
                
                unless recurring.blank? # Optional
                  xml.tag!(ns2 + 'PaymentPeriod') do
                    xml.tag!(ns2 + 'Amount', amount(recurring[:amount]), 'currencyID' => currency) unless recurring[:amount].blank? # Optional
                    xml.tag!(ns2 + 'TotalBillingCycles', recurring[:total_billing_cycles]) unless recurring[:total_billing_cycles].blank? # Optional
                  end
                end
                
                unless trial.blank? # Optional
                  xml.tag!(ns2 + 'TrialPeriod') do
                    xml.tag!(ns2 + 'Amount', amount(trial[:amount]), 'currencyID' => currency) unless trial[:amount].blank? # Optional
                    xml.tag!(ns2 + 'TotalBillingCycles', trial[:total_billing_cycles]) unless trial[:total_billing_cycles].blank? # Optional
                  end
                end
                
              end
            end
          end
        elsif [:suspend, :reactivate, :cancel].include?(action)
          xml.tag!('ManageRecurringPaymentsProfileStatusReq', 'xmlns' => PAYPAL_NAMESPACE) do
            xml.tag!('ManageRecurringPaymentsProfileStatusRequest', 'xmlns:n2' => EBAY_NAMESPACE) do
              xml.tag!(ns2 + 'Version', API_VERSION)
              xml.tag!(ns2 + 'ManageRecurringPaymentsProfileStatusRequestDetails') do
                raise ArgumentError, 'Invalid Request: Missing Profile ID' if profile_id.blank?
                xml.tag!(ns2 + 'ProfileID', profile_id) # Required
                xml.tag!(ns2 + 'Note', note) unless note.blank? # Optional
                raise ArgumentError, 'Invalid Request: Unrecognized Action' unless ['suspend', 'reactivate', 'cancel'].include?(action.to_s)
                xml.tag!(ns2 + 'Action', action.to_s.capitalize) # Required
              end
            end
          end
        elsif [:inquiry].include?(action)
          xml.tag!('GetRecurringPaymentsProfileDetailsReq', 'xmlns' => PAYPAL_NAMESPACE) do
            xml.tag!('GetRecurringPaymentsProfileDetailsRequest', 'xmlns:n2' => EBAY_NAMESPACE) do
              xml.tag!(ns2 + 'Version', API_VERSION)
              raise ArgumentError, 'Invalid Request: Missing Profile ID' if profile_id.blank?
              xml.tag!('ProfileID', profile_id) # Required
            end
          end
        end
      end
      
      def get_pay_period(period) #:nodoc:
        case period
          when :daily then [1, 'Day']
          when :weekly then [1, 'Week']
          when :biweekly then [2, 'Week']
          when :semimonthly then [1, 'SemiMonth']
          when :quadweekly then [4, 'Week']
          when :monthly then [1, 'Month']
          when :quarterly then [3, 'Month']
          when :semiyearly then [6, 'Month']
          when :yearly then [1, 'Year']
        end
      end
      
    end
  end
end