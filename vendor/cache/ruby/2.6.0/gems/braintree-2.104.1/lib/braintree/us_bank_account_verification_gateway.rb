module Braintree
  class UsBankAccountVerificationGateway
    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def confirm_micro_transfer_amounts(id, deposit_amounts)
      raise ArgumentError if id.nil? || id.to_s.strip == "" || !deposit_amounts.kind_of?(Array)
      response = @config.http.put(
        "#{@config.base_merchant_path}/us_bank_account_verifications/#{id}/confirm_micro_transfer_amounts",
        :us_bank_account_verification => {
          :deposit_amounts => deposit_amounts,
        },
      )
      if response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        SuccessfulResult.new(
          :us_bank_account_verification => UsBankAccountVerification._new(response[:us_bank_account_verification])
        )
      end
    rescue NotFoundError
      raise NotFoundError, "verification with id #{id.inspect} not found"
    end

    def find(id)
      raise ArgumentError if id.nil? || id.to_s.strip == ""
      response = @config.http.get("#{@config.base_merchant_path}/us_bank_account_verifications/#{id}")
      UsBankAccountVerification._new(response[:us_bank_account_verification])
    rescue NotFoundError
      raise NotFoundError, "verification with id #{id.inspect} not found"
    end

    def search(&block)
      search = UsBankAccountVerificationSearch.new
      block.call(search) if block

      response = @config.http.post("#{@config.base_merchant_path}/us_bank_account_verifications/advanced_search_ids", {:search => search.to_hash})
      ResourceCollection.new(response) { |ids| _fetch_verifications(search, ids) }
    end

    def _fetch_verifications(search, ids)
      search.ids.in ids
      response = @config.http.post("#{@config.base_merchant_path}/us_bank_account_verifications/advanced_search", {:search => search.to_hash})
      attributes = response[:us_bank_account_verifications]
      Util.extract_attribute_as_array(attributes, :us_bank_account_verification).map { |attrs| UsBankAccountVerification._new(attrs) }
    end
  end
end
