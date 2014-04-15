module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      class Helper #:nodoc:
        attr_reader :fields
        class_attribute :service_url
        class_attribute :mappings
        class_attribute :country_format
        self.country_format = :alpha2

        # The application making the calls to the gateway
        # Useful for things like the PayPal build notation (BN) id fields
        class_attribute :application_id
        self.application_id = 'ActiveMerchant'

        def self.inherited(subclass)
          subclass.mappings ||= {}
        end

        # @param order [String] unique id of this order
        # @param account [String] merchant account id from gateway provider
        # @param options [Hash] convenience param to set common attributes including:
        #   * amount
        #   * currency
        #   * credential2
        #   * credential3
        #   * credential4
        #   * notify_url
        #   * return_url
        #   * redirect_param
        def initialize(order, account, options = {})
          options.assert_valid_keys([:amount, :currency, :test, :credential2, :credential3, :credential4, :country, :account_name, :transaction_type, :authcode, :notify_url, :return_url, :redirect_param, :forward_url])
          @fields             = {}
          @raw_html_fields    = []
          @test               = options[:test]
          self.order          = order
          self.account        = account
          self.amount         = options[:amount]
          self.currency       = options[:currency]
          self.credential2    = options[:credential2]
          self.credential3    = options[:credential3]
          self.credential4    = options[:credential4]
          self.notify_url     = options[:notify_url]
          self.return_url     = options[:return_url]
          self.redirect_param = options[:redirect_param]
        end

        # Add a mapping between attribute name and gateway specific field name.
        # This mapping can then be used in form helper to assign values to each
        # attributes. For example, a `mapping :height, "HEIGHT"` means user can
        # write `f.height 182` in 'payment_service_for' form helper, and an
        # input tag with the name "HEIGHT" and value of 182 will be generated.
        # This is an abstraction over the `add_field` method.
        #
        # @param attribute [Symbol] attribute name
        # @param options [String, Array, Hash] input name from gateway's side.
        #
        #   String:
        #   Name of generated input
        #
        #   Array:
        #   Names of generated inputs, for creating synonym inputs.
        #   Each generated input will have the same value.
        #
        #   Hash:
        #   Keys as attribute name and values as generated input names.
        #   Used to group related fields together, such as different segments 
        #   of an address, for example:
        #
        #     mapping :address, :region => 'REGION',
        #                       :city => 'CITY',
        #                       :address => 'ADD'
        def self.mapping(attribute, options = {})
          self.mappings[attribute] = options
        end

        # Add an input in the form. Useful when gateway requires some uncommon
        # fields not provided by the gem.
        #
        #   # inside `payment_service_for do |service|` block
        #   service.add_field('c_id','_xclick')
        #
        # Gateway implementor can also use this to add default fields in the form:
        #
        #   # in a subclass of ActiveMerchant::Billing::Integrations::Helper
        #   def initialize(order, account, options = {})
        #     super
        #     # mandatory fields
        #     add_field('Rvg2c', 1)
        #   end
        #
        # @param name [String] input name
        # @param value [String] input value
        def add_field(name, value)
          return if name.blank? || value.blank?
          @fields[name.to_s] = value.to_s
        end

        def add_fields(subkey, params = {})
          params.each do |k, v|
            field = mappings[subkey][k]
            add_field(field, v) unless field.blank?
          end
        end

        # Add a field that has characters that CGI::escape would mangle. Allows
        # for multiple fields with the same name (e.g., to support line items).
        def add_raw_html_field(name, value)
          return if name.blank? || value.blank?
          @raw_html_fields << [name, value]
        end

        def raw_html_fields
          @raw_html_fields
        end

        def billing_address(params = {})
          add_address(:billing_address, params)
        end

        def shipping_address(params = {})
          add_address(:shipping_address, params)
        end

        def form_fields
          @fields
        end

        # @return [Boolean] whether in test mode
        def test?
          @test_mode ||= ActiveMerchant::Billing::Base.integration_mode == :test || @test
        end

        # Specifies the HTTP method used in form submmition.
        # Set to POST which gateway implementor can override if other http method is desired (e.g. PUT).
        #
        # @return [String] form submit action, default is "POST".
        def form_method
          "POST"
        end

        private

        def add_address(key, params)
          return if mappings[key].nil?

          code = lookup_country_code(params.delete(:country))
          add_field(mappings[key][:country], code)
          add_fields(key, params)
        end

        def lookup_country_code(name_or_code, format = country_format)
          country = Country.find(name_or_code)
          country.code(format).to_s
        rescue InvalidCountryCodeError
          name_or_code
        end

        def method_missing(method_id, *args)
          method_id = method_id.to_s.gsub(/=$/, '').to_sym
          # Return and do nothing if the mapping was not found. This allows
          # For easy substitution of the different integrations
          return if mappings[method_id].nil?

          mapping = mappings[method_id]

          case mapping
          when Array
            mapping.each{ |field| add_field(field, args.last) }
          when Hash
            options = args.last.is_a?(Hash) ? args.pop : {}

            mapping.each{ |key, field| add_field(field, options[key]) }
          else
            add_field(mapping, args.last)
          end
        end
      end
    end
  end
end
