require 'nokogiri'
require 'active_merchant/billing/gateways/payflow/payflow_common_api'
require 'active_merchant/billing/gateways/payflow/payflow_response'
require 'active_merchant/billing/gateways/payflow_express'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayflowGateway < Gateway
      include PayflowCommonAPI

      RECURRING_ACTIONS = Set.new(%i[add modify cancel inquiry reactivate payment])

      self.supported_cardtypes = %i[visa master american_express jcb discover diners_club]
      self.homepage_url = 'https://www.paypal.com/cgi-bin/webscr?cmd=_payflow-pro-overview-outside'
      self.display_name = 'PayPal Payflow Pro'

      def authorize(money, credit_card_or_reference, options = {})
        request = build_sale_or_authorization_request(:authorization, money, credit_card_or_reference, options)

        commit(request, options)
      end

      def purchase(money, funding_source, options = {})
        request = build_sale_or_authorization_request(:purchase, money, funding_source, options)

        commit(request, options)
      end

      def credit(money, funding_source, options = {})
        if funding_source.is_a?(String)
          ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
          # Perform referenced credit
          refund(money, funding_source, options)
        elsif card_brand(funding_source) == 'check'
          # Perform non-referenced credit
          request = build_check_request(:credit, money, funding_source, options)
          commit(request, options)
        else
          request = build_credit_card_request(:credit, money, funding_source, options)
          commit(request, options)
        end
      end

      def refund(money, reference, options = {})
        commit(build_reference_request(:credit, money, reference, options), options)
      end

      def verify(payment, options={})
        if credit_card_type(payment) == 'Amex'
          MultiResponse.run(:use_first_response) do |r|
            r.process { authorize(100, payment, options) }
            r.process(:ignore_result) { void(r.authorization, options) }
          end
        else
          authorize(0, payment, options)
        end
      end

      def verify_credentials
        response = void('0')
        response.params['result'] != '26'
      end

      # Adds or modifies a recurring Payflow profile.  See the Payflow Pro Recurring Billing Guide for more details:
      # https://www.paypal.com/en_US/pdf/PayflowPro_RecurringBilling_Guide.pdf
      #
      # Several options are available to customize the recurring profile:
      #
      # * <tt>profile_id</tt> - is only required for editing a recurring profile
      # * <tt>starting_at</tt> - takes a Date, Time, or string in mmddyyyy format. The date must be in the future.
      # * <tt>name</tt> - The name of the customer to be billed.  If not specified, the name from the credit card is used.
      # * <tt>periodicity</tt> - The frequency that the recurring payments will occur at.  Can be one of
      # :bimonthly, :monthly, :biweekly, :weekly, :yearly, :daily, :semimonthly, :quadweekly, :quarterly, :semiyearly
      # * <tt>payments</tt> - The term, or number of payments that will be made
      # * <tt>comment</tt> - A comment associated with the profile
      def recurring(money, credit_card, options = {})
        ActiveMerchant.deprecated RECURRING_DEPRECATION_MESSAGE

        options[:name] = credit_card.name if options[:name].blank? && credit_card
        request = build_recurring_request(options[:profile_id] ? :modify : :add, money, options) do |xml|
          add_credit_card(xml, credit_card, options) if credit_card
        end
        commit(request, options.merge(request_type: :recurring))
      end

      def cancel_recurring(profile_id)
        ActiveMerchant.deprecated RECURRING_DEPRECATION_MESSAGE

        request = build_recurring_request(:cancel, 0, profile_id: profile_id)
        commit(request, options.merge(request_type: :recurring))
      end

      def recurring_inquiry(profile_id, options = {})
        ActiveMerchant.deprecated RECURRING_DEPRECATION_MESSAGE

        request = build_recurring_request(:inquiry, nil, options.update(profile_id: profile_id))
        commit(request, options.merge(request_type: :recurring))
      end

      def express
        @express ||= PayflowExpressGateway.new(@options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<CardNum>)[^<]*(</CardNum>)), '\1[FILTERED]\2').
          gsub(%r((<CVNum>)[^<]*(</CVNum>)), '\1[FILTERED]\2').
          gsub(%r((<AcctNum>)[^<]*(</AcctNum>)), '\1[FILTERED]\2').
          gsub(%r((<Password>)[^<]*(</Password>)), '\1[FILTERED]\2')
      end

      private

      def build_sale_or_authorization_request(action, money, funding_source, options)
        if funding_source.is_a?(String)
          build_reference_sale_or_authorization_request(action, money, funding_source, options)
        elsif card_brand(funding_source) == 'check'
          build_check_request(action, money, funding_source, options)
        else
          build_credit_card_request(action, money, funding_source, options)
        end
      end

      def build_reference_sale_or_authorization_request(action, money, reference, options)
        xml = Builder::XmlMarkup.new
        xml.tag! TRANSACTIONS[action] do
          xml.tag! 'PayData' do
            xml.tag! 'Invoice' do
              # Fields accepted by PayFlow and recommended to be provided even for Reference Transaction, per Payflow docs.
              xml.tag! 'CustIP', options[:ip] unless options[:ip].blank?
              xml.tag! 'InvNum', options[:order_id].to_s.gsub(/[^\w.]/, '') unless options[:order_id].blank?
              xml.tag! 'Description', options[:description] unless options[:description].blank?
              xml.tag! 'OrderDesc', options[:order_desc] unless options[:order_desc].blank?
              xml.tag! 'Comment', options[:comment] unless options[:comment].blank?
              xml.tag!('ExtData', 'Name' => 'COMMENT2', 'Value' => options[:comment2]) unless options[:comment2].blank?
              xml.tag! 'TaxAmt', options[:taxamt] unless options[:taxamt].blank?
              xml.tag! 'FreightAmt', options[:freightamt] unless options[:freightamt].blank?
              xml.tag! 'DutyAmt', options[:dutyamt] unless options[:dutyamt].blank?
              xml.tag! 'DiscountAmt', options[:discountamt] unless options[:discountamt].blank?

              billing_address = options[:billing_address] || options[:address]
              add_address(xml, 'BillTo', billing_address, options) if billing_address
              add_address(xml, 'ShipTo', options[:shipping_address], options) if options[:shipping_address]

              xml.tag! 'TotalAmt', amount(money), 'Currency' => options[:currency] || currency(money)
            end
            xml.tag! 'Tender' do
              xml.tag! 'Card' do
                xml.tag! 'ExtData', 'Name' => 'ORIGID', 'Value' => reference
              end
            end
          end
          xml.tag! 'ExtData', 'Name' => 'BUTTONSOURCE', 'Value' => application_id unless application_id.blank?
        end
        xml.target!
      end

      def build_credit_card_request(action, money, credit_card, options)
        xml = Builder::XmlMarkup.new
        xml.tag! TRANSACTIONS[action] do
          xml.tag! 'PayData' do
            xml.tag! 'Invoice' do
              xml.tag! 'CustIP', options[:ip] unless options[:ip].blank?
              xml.tag! 'InvNum', options[:order_id].to_s.gsub(/[^\w.]/, '') unless options[:order_id].blank?
              xml.tag! 'Description', options[:description] unless options[:description].blank?
              xml.tag! 'OrderDesc', options[:order_desc] unless options[:order_desc].blank?
              # Comment and Comment2 will show up in manager.paypal.com as Comment1 and Comment2
              xml.tag! 'Comment', options[:comment] unless options[:comment].blank?
              xml.tag!('ExtData', 'Name' => 'COMMENT2', 'Value' => options[:comment2]) unless options[:comment2].blank?
              xml.tag! 'TaxAmt', options[:taxamt] unless options[:taxamt].blank?
              xml.tag! 'FreightAmt', options[:freightamt] unless options[:freightamt].blank?
              xml.tag! 'DutyAmt', options[:dutyamt] unless options[:dutyamt].blank?
              xml.tag! 'DiscountAmt', options[:discountamt] unless options[:discountamt].blank?
              xml.tag! 'EMail', options[:email] unless options[:email].nil?

              billing_address = options[:billing_address] || options[:address]
              add_address(xml, 'BillTo', billing_address, options) if billing_address
              add_address(xml, 'ShipTo', options[:shipping_address], options) if options[:shipping_address]

              xml.tag! 'TotalAmt', amount(money), 'Currency' => options[:currency] || currency(money)
            end

            xml.tag! 'Tender' do
              add_credit_card(xml, credit_card, options)
            end
          end
          xml.tag! 'ExtData', 'Name' => 'BUTTONSOURCE', 'Value' => application_id unless application_id.blank?
        end
        add_level_two_three_fields(xml.target!, options)
      end

      def add_level_two_three_fields(xml_string, options)
        if options[:level_two_fields] || options[:level_three_fields]
          xml_doc = Nokogiri::XML.parse(xml_string)
          %i[level_two_fields level_three_fields].each do |fields|
            xml_string = add_fields(xml_doc, options[fields]) if options[fields]
          end
        end
        xml_string
      end

      def check_fields(parent, fields, xml_doc)
        fields.each do |k, v|
          if v.is_a? String
            new_node = Nokogiri::XML::Node.new(k, xml_doc)
            new_node.add_child(v)
            xml_doc.at_css(parent).add_child(new_node)
          else
            check_subparent_before_continuing(parent, k, xml_doc)
            check_fields(k, v, xml_doc)
          end
        end
        xml_doc
      end

      def check_subparent_before_continuing(parent, subparent, xml_doc)
        unless xml_doc.at_css(subparent)
          subparent_node = Nokogiri::XML::Node.new(subparent, xml_doc)
          xml_doc.at_css(parent).add_child(subparent_node)
        end
      end

      def add_fields(xml_doc, options_fields)
        fields_to_add = JSON.parse(options_fields)
        check_fields('Invoice', fields_to_add, xml_doc)
        xml_doc.root.to_s
      end

      def build_check_request(action, money, check, options)
        xml = Builder::XmlMarkup.new
        xml.tag! TRANSACTIONS[action] do
          xml.tag! 'PayData' do
            xml.tag! 'Invoice' do
              xml.tag! 'CustIP', options[:ip] unless options[:ip].blank?
              xml.tag! 'InvNum', options[:order_id].to_s.gsub(/[^\w.]/, '') unless options[:order_id].blank?
              xml.tag! 'Description', options[:description] unless options[:description].blank?
              xml.tag! 'OrderDesc', options[:order_desc] unless options[:order_desc].blank?
              xml.tag! 'BillTo' do
                xml.tag! 'Name', check.name
              end
              xml.tag! 'TotalAmt', amount(money), 'Currency' => options[:currency] || currency(money)
            end
            xml.tag! 'Tender' do
              xml.tag! 'ACH' do
                xml.tag! 'AcctType', check.account_type == 'checking' ? 'C' : 'S'
                xml.tag! 'AcctNum', check.account_number
                xml.tag! 'ABA', check.routing_number
              end
            end
          end
          xml.tag! 'ExtData', 'Name' => 'BUTTONSOURCE', 'Value' => application_id unless application_id.blank?
        end
        add_level_two_three_fields(xml.target!, options)
      end

      def add_credit_card(xml, credit_card, options = {})
        xml.tag! 'Card' do
          xml.tag! 'CardType', credit_card_type(credit_card)
          xml.tag! 'CardNum', credit_card.number
          xml.tag! 'ExpDate', expdate(credit_card)
          xml.tag! 'NameOnCard', credit_card.first_name
          xml.tag! 'CVNum', credit_card.verification_value if credit_card.verification_value?

          add_three_d_secure(options, xml)

          xml.tag! 'ExtData', 'Name' => 'LASTNAME', 'Value' => credit_card.last_name
        end
      end

      def add_three_d_secure(options, xml)
        if options[:three_d_secure]
          three_d_secure = options[:three_d_secure]
          xml.tag! 'BuyerAuthResult' do
            authentication_status(three_d_secure, xml)
            xml.tag! 'AuthenticationId', three_d_secure[:authentication_id] unless three_d_secure[:authentication_id].blank?
            xml.tag! 'PAReq', three_d_secure[:pareq] unless three_d_secure[:pareq].blank?
            xml.tag! 'ACSUrl', three_d_secure[:acs_url] unless three_d_secure[:acs_url].blank?
            xml.tag! 'ECI', three_d_secure[:eci] unless three_d_secure[:eci].blank?
            xml.tag! 'CAVV', three_d_secure[:cavv] unless three_d_secure[:cavv].blank?
            xml.tag! 'XID', three_d_secure[:xid] unless three_d_secure[:xid].blank?
          end
        end
      end

      def authentication_status(three_d_secure, xml)
        if three_d_secure[:authentication_response_status].present?
          xml.tag! 'Status', three_d_secure[:authentication_response_status]
        elsif three_d_secure[:directory_response_status].present?
          xml.tag! 'Status', three_d_secure[:directory_response_status]
        end
      end

      def credit_card_type(credit_card)
        return '' if card_brand(credit_card).blank?

        CARD_MAPPING[card_brand(credit_card).to_sym]
      end

      def expdate(creditcard)
        year  = sprintf('%.4i', creditcard.year.to_s.sub(/^0+/, ''))
        month = sprintf('%.2i', creditcard.month.to_s.sub(/^0+/, ''))

        "#{year}#{month}"
      end

      def startdate(creditcard)
        year  = format(creditcard.start_year, :two_digits)
        month = format(creditcard.start_month, :two_digits)

        "#{month}#{year}"
      end

      def build_recurring_request(action, money, options)
        raise StandardError, "Invalid Recurring Profile Action: #{action}" unless RECURRING_ACTIONS.include?(action)

        xml = Builder::XmlMarkup.new
        xml.tag! 'RecurringProfiles' do
          xml.tag! 'RecurringProfile' do
            xml.tag! action.to_s.capitalize do
              unless %i[cancel inquiry].include?(action)
                xml.tag! 'RPData' do
                  xml.tag! 'Name', options[:name] unless options[:name].nil?
                  xml.tag! 'TotalAmt', amount(money), 'Currency' => options[:currency] || currency(money)
                  xml.tag! 'PayPeriod', get_pay_period(options)
                  xml.tag! 'Term', options[:payments] unless options[:payments].nil?
                  xml.tag! 'Comment', options[:comment] unless options[:comment].nil?
                  xml.tag! 'RetryNumDays', options[:retry_num_days] unless options[:retry_num_days].nil?
                  xml.tag! 'MaxFailPayments', options[:max_fail_payments] unless options[:max_fail_payments].nil?

                  if initial_tx = options[:initial_transaction]
                    requires!(initial_tx, %i[type authorization purchase])
                    requires!(initial_tx, :amount) if initial_tx[:type] == :purchase

                    xml.tag! 'OptionalTrans', TRANSACTIONS[initial_tx[:type]]
                    xml.tag! 'OptionalTransAmt', amount(initial_tx[:amount]) unless initial_tx[:amount].blank?
                  end

                  if action == :add
                    xml.tag! 'Start', format_rp_date(options[:starting_at] || Date.today + 1)
                  else
                    xml.tag! 'Start', format_rp_date(options[:starting_at]) unless options[:starting_at].nil?
                  end

                  xml.tag! 'EMail', options[:email] unless options[:email].nil?

                  billing_address = options[:billing_address] || options[:address]
                  add_address(xml, 'BillTo', billing_address, options) if billing_address
                  add_address(xml, 'ShipTo', options[:shipping_address], options) if options[:shipping_address]
                end
                xml.tag! 'Tender' do
                  yield xml
                end
              end
              xml.tag! 'ProfileID', options[:profile_id] if action != :add
              if action == :inquiry
                xml.tag! 'PaymentHistory', (options[:history] ? 'Y' : 'N')
              end
            end
          end
        end
      end

      def get_pay_period(options)
        requires!(options, %i[periodicity bimonthly monthly biweekly weekly yearly daily semimonthly quadweekly quarterly semiyearly])
        case options[:periodicity]
        when :weekly then 'Weekly'
        when :biweekly then 'Bi-weekly'
        when :semimonthly then 'Semi-monthly'
        when :quadweekly then 'Every four weeks'
        when :monthly then 'Monthly'
        when :quarterly then 'Quarterly'
        when :semiyearly then 'Semi-yearly'
        when :yearly then 'Yearly'
        end
      end

      def format_rp_date(time)
        case time
        when Time, Date then time.strftime('%m%d%Y')
        else
          time.to_s
        end
      end

      def build_response(success, message, response, options = {})
        PayflowResponse.new(success, message, response, options)
      end
    end
  end
end
