module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paydollar
        class Return < ActiveMerchant::Billing::Integrations::Return

          def success?
            uri = URI.parse(ActiveMerchant::Billing::Integrations::Paydollar.api_url)
            form = {
              merchantId: @options[:credential1],
              loginId: @options[:credential3],
              password: @options[:credential4],
              actionType: 'Query',
              orderRef: @params['Ref']
            }
            response = Net::HTTP.post_form(uri, form)
            hash = Hash.from_xml(response.body)
            records = hash['records']['record']
            # Paydollar allows duplicate order references, so it's possible to receive
            # multiple records from the Query API, at least in development, but we'll
            # only care about the most recent one.
            # Suggestions are welcomed on the below, as records will be either a single
            # hash or a collection of hashes from which we want to pick the most recent
            @most_recent_record = if records.kind_of?(Array)
                                    records.sort_by! {|rec| rec['payRef']}
                                    records.last
                                  else
                                    records
                                  end
            @most_recent_record.nil? || @most_recent_record['orderStatus'] == 'Accepted'
          end

        end
      end
    end
  end
end
