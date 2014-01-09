require "nokogiri"
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module CheckoutFinland
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include PostsData
          self.country_format = :alpha3

          def initialize(order, account, options = {})
            md5secret options.delete(:credential2)
            super

            # Add default fields
            add_field("VERSION", "0001") # API version
            add_field("ALGORITHM", "3") # Return MAC version (3 is HMAC-SHA256)
            add_field("TYPE", "0")
            add_field("DEVICE", "1") # Offsite payment by default
          end

          def md5secret(value)
            @md5secret = value
          end

          # Add MAC to form fields
          def form_fields
            @fields.merge("MAC" => generate_md5string)
          end

          # Apply parameter length limitations recommended by Checkout.fi
          def add_field(name, value)
            return if name.blank? || value.blank?
            @fields[name.to_s] = check_param_length(name_to_s, value.to_s)
          end

          # API parameter length limitations specified by Checkout.fi
          # Parameters longer than this cause the HTTP POST to fail
          def check_param_length(name, value)
            # Soft limitations, fields that can be clipped
            max_length_substring = { "FIRSTNAME" => 40, "FAMILYNAME" => 40, "ADDRESS" => 40, "POSTCODE" => 14, "POSTOFFICE" => 18, "MESSAGE" => 1000, "EMAIL" => 200, "PHONE" => 30 }
            # Hard limitations, fields that cannot be clipped
            max_length_exception = { "RETURN" => 300, "CANCEL" => 300, "REJECT" => 300, "DELAYED" => 300, "STAMP" => 20, "AMOUNT" => 8, "REFERENCE" => 20, "CONTENT" => 2, "LANGUAGE" => 2, "MERCHANT" => 20, "COUNTRY" => 3, "CURRENCY" => 3, "DELIVERY_DATE" => 8 }
            if max_length_substring.include? name
              return value.to_s[0, max_length_substring[name]]
            end
            if max_length_exception.include? name
              if value.to_s.length > max_length_exception[name]
                raise ArgumentError, "Field #{name} length #{value.length} is longer than permitted by provider API. Maximum length #{max_length_exception[name]}."
              else
                return value
              end
            end
            value
          end

          # Calculate MAC
          def generate_md5string
            fields = [@fields["VERSION"], @fields["STAMP"], @fields["AMOUNT"], @fields["REFERENCE"],
                      @fields["MESSAGE"], @fields["LANGUAGE"], @fields["MERCHANT"], @fields["RETURN"],
                      @fields["CANCEL"], @fields["REJECT"], @fields["DELAYED"], @fields["COUNTRY"],
                      @fields["CURRENCY"], @fields["DEVICE"], @fields["CONTENT"], @fields["TYPE"],
                      @fields["ALGORITHM"], @fields["DELIVERY_DATE"], @fields["FIRSTNAME"], @fields["FAMILYNAME"],
                      @fields["ADDRESS"], @fields["POSTCODE"], @fields["POSTOFFICE"], @md5secret]
             fields = fields.join("+")
             Digest::MD5.hexdigest(fields).upcase 
          end

          # Method for getting individual buttons for each payment method supported by Checkout.fi
          # Return Array of Hashes from Checkout.fi XML API with each hash containing keys "url", "icon", "name" and "fields"
          # "fields" key contains key value pairs for HTTP POST form sent into end payment service 
          # Alternative to using payment_service_for from ActionViewHelper
          # Makes it possible to integrate different payment methods provided by Checkout directly into the site
          #
          # Normal payment flow with payment_service_for helper:
          # 1. Rails site renders form button "Pay with Checkout.fi" -> 2. Browser goes to Checkout.fi to choose payment method ->
          # 3. Browser goes to final payment service (usually a Finnish bank) -> 4. Redirect to Checkout.fi -> 5. Redirect to Rails site 
          #
          # Payment flow with get_onsite_buttons (one less step):
          # 1. Rails site renders form buttons for different methods -> 2. Browser goes to final payment service (usually a Finnish bank) ->
          # 3. Redirect to Checkout.fi -> 4. Redirect to Rails site
          #
          # Using this method requires initializing the Helper object with required fields and credentials in controller:
          # service = ActiveMerchant::Billing::Integrations::CheckoutFinland::Helper.new(order, account, options)
          #
          # Then fetch data for all the different providers using this method
          # @data = service.get_payment_buttons
          #
          # Finally render returned data in view:
          #
          # <% @data.each do |bank| %>
          #   <div class='bank'>
          #     <%= form_tag(bank["url"], method: "post") do %>
          #       <%  bank["fields"].each do |key, value| %>
          #         <%= hidden_field_tag(key, value) %>
          #       <%  end %>
          #       <span><%= image_submit_tag(bank["icon"]) %></span>
          #       <div><%= bank["name"] %></div>
          #     <% end %>
          #   </div>
          # <% end %>
          def get_onsite_buttons
            data = PostData.new
            # Get back payment provider data as XML
            @fields["DEVICE"] = "10"
            form_fields.each {|key, value| data[key] = value}
            service_url = ActiveMerchant::Billing::Integrations::CheckoutFinland.service_url
            request = ssl_post(service_url, data.to_post_data)
            parse_xml_response(request)
          end

          # Separate method for XML parsing response for get_onsite_buttons request
          # Unit tested with mock data
          def parse_xml_response(xmlraw)
            payment_array = []
            xml = Nokogiri::XML(xmlraw)
            banks = xml.xpath("//payment/banks/*")
            banks.each do |bank| 
              bankhash = { }
              fieldhash = { }
              bankhash["name"] = bank["name"]
              bankhash["url"] = bank["url"]
              bankhash["icon"] = bank["icon"]
              bank.element_children.each do |child|
                fieldhash[child.name] = child.text
              end
              bankhash["fields"] = fieldhash
              payment_array.push(bankhash)
            end
            payment_array
          end

          # Mappings
          mapping :order, 'STAMP' # Unique order number for each payment
          mapping :account, 'MERCHANT' # Checkout Merchant ID
          mapping :amount, 'AMOUNT' # Amount in cents
          mapping :reference, 'REFERENCE' # Reference for bank statement
          mapping :language, 'LANGUAGE' # "FI" / "SE" / "EN"
          mapping :currency, 'CURRENCY' # "EUR" currently only
          mapping :device, 'DEVICE' # "1" = HTML / "10" = XML
          mapping :content, 'CONTENT' # "1" = NORMAL "2" = ADULT CONTENT
          mapping :delivery_date, 'DELIVERY_DATE' # "YYYYMMDD"
          mapping :description, 'MESSAGE' # Description of the order

          # Optional customer data supported by API (not mandatory)
          mapping :customer, :first_name => 'FIRSTNAME',
                             :last_name  => 'FAMILYNAME',
                             :email      => 'EMAIL',
                             :phone      => 'PHONE'

          # Optional fields supported by API (not mandatory)
          mapping :billing_address, :city     => 'POSTOFFICE',
                                    :address1 => 'ADDRESS',
                                    :zip      => 'POSTCODE',
                                    :country  => 'COUNTRY'

          mapping :notify_url, 'DELAYED' # Delayed payment URL (mandatory)
          mapping :reject_url, 'REJECT' # Rejected payment URL (mandatory)
          mapping :return_url, 'RETURN' # Payment URL (optional)
          mapping :cancel_return_url, 'CANCEL' # Cancelled payment URL (optional)
        end
      end
    end
  end
end
