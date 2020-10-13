module Braintree
  class TransactionGateway # :nodoc:
    include BaseModule

    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def create(attributes)
      Util.verify_keys(TransactionGateway._create_signature, attributes)
      _do_create "/transactions", :transaction => attributes
    end

    def cancel_release(transaction_id)
      raise ArgumentError, "transaction_id is invalid" unless transaction_id =~ /\A[0-9a-z]+\z/
      response = @config.http.put("#{@config.base_merchant_path}/transactions/#{transaction_id}/cancel_release")
      _handle_transaction_response(response)
    end

    def cancel_release!(*args)
      return_object_or_raise(:transaction) { cancel_release(*args) }
    end

    def hold_in_escrow(transaction_id)
      raise ArgumentError, "transaction_id is invalid" unless transaction_id =~ /\A[0-9a-z]+\z/
      response = @config.http.put("#{@config.base_merchant_path}/transactions/#{transaction_id}/hold_in_escrow")
      _handle_transaction_response(response)
    end

    def hold_in_escrow!(*args)
      return_object_or_raise(:transaction) { hold_in_escrow(*args) }
    end

    def _handle_transaction_response(response)
      if response[:transaction]
        SuccessfulResult.new(:transaction => Transaction._new(@gateway, response[:transaction]))
      elsif response[:api_error_response]
        ErrorResult.new(@gateway, response[:api_error_response])
      else
        raise UnexpectedError, "expected :transaction or :response"
      end
    end

    def clone_transaction(transaction_id, attributes)
      Util.verify_keys(TransactionGateway._clone_signature, attributes)
      _do_create "/transactions/#{transaction_id}/clone", :transaction_clone => attributes
    end

    def clone_transaction!(*args)
      return_object_or_raise(:transaction) { clone_transaction(*args) }
    end

    # Deprecated
    def create_from_transparent_redirect(query_string)
      params = @gateway.transparent_redirect.parse_and_validate_query_string query_string
      _do_create("/transactions/all/confirm_transparent_redirect_request", :id => params[:id])
    end

    def create_transaction_url
      warn "[DEPRECATED] Transaction.create_transaction_url is deprecated. Please use TransparentRedirect.url"
      "#{@config.base_merchant_url}/transactions/all/create_via_transparent_redirect_request"
    end

    def credit(attributes)
      create(attributes.merge(:type => 'credit'))
    end

    def credit!(*args)
      return_object_or_raise(:transaction) { credit(*args) }
    end

    def find(id)
      raise ArgumentError if id.nil? || id.strip.to_s == ""
      response = @config.http.get("#{@config.base_merchant_path}/transactions/#{id}")
      Transaction._new(@gateway, response[:transaction])
    rescue NotFoundError
      raise NotFoundError, "transaction with id #{id.inspect} not found"
    end

    def refund(transaction_id, amount_or_options = nil)
      options = if amount_or_options.is_a?(Hash)
                  amount_or_options
                else
                  { :amount => amount_or_options }
                end

      Util.verify_keys(TransactionGateway._refund_signature, options)
      response = @config.http.post("#{@config.base_merchant_path}/transactions/#{transaction_id}/refund", :transaction => options)
      _handle_transaction_response(response)
    end

    def refund!(*args)
      return_object_or_raise(:transaction) { refund(*args) }
    end

    def retry_subscription_charge(subscription_id, amount=nil, submit_for_settlement=false)
      attributes = {
        :amount => amount,
        :subscription_id => subscription_id,
        :type => Transaction::Type::Sale,
        :options => {
          :submit_for_settlement => submit_for_settlement
        }
      }
      _do_create "/transactions", :transaction => attributes
    end

    def sale(attributes)
      create(attributes.merge(:type => 'sale'))
    end

    def sale!(*args)
      return_object_or_raise(:transaction) { sale(*args) }
    end

    def search(&block)
      search = TransactionSearch.new
      block.call(search) if block

      response = @config.http.post("#{@config.base_merchant_path}/transactions/advanced_search_ids", {:search => search.to_hash})

      if response.has_key?(:search_results)
        ResourceCollection.new(response) { |ids| _fetch_transactions(search, ids) }
      else
        raise DownForMaintenanceError
      end
    end

    def release_from_escrow(transaction_id)
      raise ArgumentError, "transaction_id is invalid" unless transaction_id =~ /\A[0-9a-z]+\z/
      response = @config.http.put("#{@config.base_merchant_path}/transactions/#{transaction_id}/release_from_escrow")
      _handle_transaction_response(response)
    end

    def release_from_escrow!(*args)
      return_object_or_raise(:transaction) { release_from_escrow(*args) }
    end

    def submit_for_settlement(transaction_id, amount = nil, options = {})
      raise ArgumentError, "transaction_id is invalid" unless transaction_id =~ /\A[0-9a-z]+\z/
      Util.verify_keys(TransactionGateway._submit_for_settlement_signature, options)
      transaction_params = {:amount => amount}.merge(options)
      response = @config.http.put("#{@config.base_merchant_path}/transactions/#{transaction_id}/submit_for_settlement", :transaction => transaction_params)
      _handle_transaction_response(response)
    end

    def submit_for_settlement!(*args)
      return_object_or_raise(:transaction) { submit_for_settlement(*args) }
    end

    def update_details(transaction_id, options = {})
      raise ArgumentError, "transaction_id is invalid" unless transaction_id =~ /\A[0-9a-z]+\z/
      Util.verify_keys(TransactionGateway._update_details_signature, options)
      response = @config.http.put("#{@config.base_merchant_path}/transactions/#{transaction_id}/update_details", :transaction => options)
      _handle_transaction_response(response)
    end

    def submit_for_partial_settlement(authorized_transaction_id, amount = nil, options = {})
      raise ArgumentError, "authorized_transaction_id is invalid" unless authorized_transaction_id =~ /\A[0-9a-z]+\z/
      Util.verify_keys(TransactionGateway._submit_for_settlement_signature, options)
      transaction_params = {:amount => amount}.merge(options)
      response = @config.http.post("#{@config.base_merchant_path}/transactions/#{authorized_transaction_id}/submit_for_partial_settlement", :transaction => transaction_params)
      _handle_transaction_response(response)
    end

    def submit_for_partial_settlement!(*args)
      return_object_or_raise(:transaction) { submit_for_partial_settlement(*args) }
    end

    def void(transaction_id)
      response = @config.http.put("#{@config.base_merchant_path}/transactions/#{transaction_id}/void")
      _handle_transaction_response(response)
    end

    def void!(*args)
      return_object_or_raise(:transaction) { void(*args) }
    end

    def self._clone_signature # :nodoc:
      [:amount, :channel, {:options => [:submit_for_settlement]}]
    end

    def self._create_signature # :nodoc:
      [
        :amount, :customer_id, :merchant_account_id, :order_id, :channel, :payment_method_token,
        :purchase_order_number, :recurring, :transaction_source, :shipping_address_id, :type, :tax_amount, :tax_exempt,
        :venmo_sdk_payment_method_code, :device_session_id, :service_fee_amount, :device_data, :fraud_merchant_id,
        :shipping_amount, :discount_amount, :ships_from_postal_code,
        :billing_address_id, :payment_method_nonce, :three_d_secure_token, :three_d_secure_authentication_id,
        :shared_payment_method_token, :shared_billing_address_id, :shared_customer_id, :shared_shipping_address_id, :shared_payment_method_nonce,
        :product_sku,
        {:line_items => [:quantity, :name, :description, :kind, :unit_amount, :unit_tax_amount, :total_amount, :discount_amount, :tax_amount, :unit_of_measure, :product_code, :commodity_code, :url]},
        {:risk_data => [:customer_browser, :customer_device_id, :customer_ip, :customer_location_zip, :customer_tenure]},
        {:credit_card => [:token, :cardholder_name, :cvv, :expiration_date, :expiration_month, :expiration_year, :number]},
        {:customer => [:id, :company, :email, :fax, :first_name, :last_name, :phone, :website]},
        {
          :billing => AddressGateway._shared_signature
        },
        {
          :shipping => AddressGateway._shared_signature + [:shipping_method],
        },
        {
          :three_d_secure_pass_thru => [
            :eci_flag,
            :cavv,
            :xid,
            :three_d_secure_version,
            :authentication_response,
            :directory_response,
            :cavv_algorithm,
            :ds_transaction_id,
          ]
        },
        {:options => [
          :hold_in_escrow,
          :store_in_vault,
          :store_in_vault_on_success,
          :submit_for_settlement,
          :add_billing_address_to_payment_method,
          :store_shipping_address_in_vault,
          :venmo_sdk_session,
          :payee_id,
          :payee_email,
          :skip_advanced_fraud_checking,
          :skip_avs,
          :skip_cvv,
          {:paypal => [:custom_field, :payee_id, :payee_email, :description, {:supplementary_data => :_any_key_}]},
          {:three_d_secure => [:required]},
          {:amex_rewards => [:request_id, :points, :currency_amount, :currency_iso_code]},
          {:venmo => [:profile_id]},
          {:credit_card => [:account_type]},
        ]
        },
        {:external_vault => [
          :status,
          :previous_network_transaction_id,
        ]},
        {:custom_fields => :_any_key_},
        {:descriptor => [:name, :phone, :url]},
        {:paypal_account => [:email, :token, :paypal_data, :payee_id, :payee_email, :payer_id, :payment_id]},
        {:industry => [
          :industry_type,
          {:data => [
            :folio_number, :check_in_date, :check_out_date, :travel_package, :lodging_check_in_date, :lodging_check_out_date, :departure_date, :lodging_name, :room_rate, :room_tax,
            :passenger_first_name, :passenger_last_name, :passenger_middle_initial, :passenger_title, :issued_date, :travel_agency_name, :travel_agency_code, :ticket_number,
            :issuing_carrier_code, :customer_code, :fare_amount, :fee_amount, :tax_amount, :restricted_ticket, :no_show, :advanced_deposit, :fire_safe, :property_phone,
            {:legs => [
              :conjunction_ticket, :exchange_ticket, :coupon_number, :service_class, :carrier_code, :fare_basis_code, :flight_number, :departure_date, :departure_airport_code, :departure_time,
              :arrival_airport_code, :arrival_time, :stopover_permitted, :fare_amount, :fee_amount, :tax_amount, :endorsement_or_restrictions,
            ]},
            {:additional_charges => [
              :kind, :amount,
            ]},
          ]},
        ]},
        {:apple_pay_card => [:number, :cardholder_name, :cryptogram, :expiration_month, :expiration_year, :eci_indicator]},
        # NEXT_MAJOR_VERSION rename Android Pay to Google Pay
        {:android_pay_card => [:number, :cryptogram, :google_transaction_id, :expiration_month, :expiration_year, :source_card_type, :source_card_last_four, :eci_indicator]}
      ]
    end

    def self._submit_for_settlement_signature # :nodoc:
      [
        :order_id,
        {:descriptor => [:name, :phone, :url]},
        :purchase_order_number,
        :tax_amount,
        :tax_exempt,
        :discount_amount,
        :shipping_amount,
        :ships_from_postal_code,
        :line_items => [:commodity_code, :description, :discount_amount, :kind, :name, :product_code, :quantity, :tax_amount, :total_amount, :unit_amount, :unit_of_measure, :unit_tax_amount, :url, :tax_amount],
      ]
    end

    def self._update_details_signature # :nodoc:
      [
        :amount,
        :order_id,
        {:descriptor => [:name, :phone, :url]},
      ]
    end

    def self._refund_signature
      [
        :amount,
        :order_id
      ]
    end

    def _do_create(path, params=nil) # :nodoc:
      response = @config.http.post("#{@config.base_merchant_path}#{path}", params)
      _handle_transaction_response(response)
    end

    def _fetch_transactions(search, ids) # :nodoc:
      search.ids.in ids
      response = @config.http.post("#{@config.base_merchant_path}/transactions/advanced_search", {:search => search.to_hash})
      attributes = response[:credit_card_transactions]
      Util.extract_attribute_as_array(attributes, :transaction).map { |attrs| Transaction._new(@gateway, attrs) }
    end
  end
end
