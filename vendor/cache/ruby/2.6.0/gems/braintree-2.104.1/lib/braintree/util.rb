module Braintree
  module Util # :nodoc:
    def self.extract_attribute_as_array(hash, attribute)
      raise UnexpectedError.new("Unprocessable entity due to an invalid request") if hash.nil?
      value = hash.has_key?(attribute) ? hash.delete(attribute) : []
      value.is_a?(Array) ? value : [value]
    end

    def self.hash_to_query_string(hash, namespace = nil)
      hash.collect do |key, value|
        full_key = namespace ? "#{namespace}[#{key}]" : key
        if value.is_a?(Hash)
          hash_to_query_string(value, full_key)
        else
          url_encode(full_key) + "=" + url_encode(value)
        end
      end.sort * '&'
    end

    def self.parse_query_string(qs)
      qs.split('&').inject({}) do |result, couplet|
        pair = couplet.split('=')
        result[CGI.unescape(pair[0]).to_sym] = CGI.unescape(pair[1] || '')
        result
      end
    end

    def self.url_decode(text)
      CGI.unescape text.to_s.to_str
    end

    def self.url_encode(text)
      CGI.escape text.to_s.to_str
    end

    def self.symbolize_keys(hash)
      hash.inject({}) do |new_hash, (key, value)|
        if value.is_a?(Hash)
          value = symbolize_keys(value)
        elsif value.is_a?(Array) && value.all? { |v| v.is_a?(Hash) }
          value = value.map { |v| symbolize_keys(v) }
        end

        new_hash.merge(key.to_sym => value)
      end
    end

    def self.raise_exception_for_status_code(status_code, message=nil)
      case status_code.to_i
      when 401
        raise AuthenticationError
      when 403
        raise AuthorizationError, message
      when 404
        raise NotFoundError
      when 426
        raise UpgradeRequiredError, "Please upgrade your client library."
      when 429
        raise TooManyRequestsError
      when 500
        raise ServerError
      when 503
        raise DownForMaintenanceError
      else
        raise UnexpectedError, "Unexpected HTTP_RESPONSE #{status_code.to_i}"
      end
    end

    def self.raise_exception_for_graphql_error(response)
      return if !response[:errors]

      for error in response[:errors]
        if error[:extensions] && error[:extensions][:errorClass]
          case error[:extensions][:errorClass]
          when "VALIDATION"
            next # skip raising an error if it is a validation error
          when "AUTHENTICATION"
            raise AuthenticationError
          when "AUTHORIZATION"
            raise AuthorizationError, error[:message]
          when "NOT_FOUND"
            raise NotFoundError
          when "UNSUPPORTED_CLIENT"
            raise UpgradeRequiredError, "Please upgrade your client library."
          when "RESOURCE_LIMIT"
            raise TooManyRequestsError
          when "INTERNAL"
            raise ServerError
          when "SERVICE_AVAILABILITY"
            raise DownForMaintenanceError
          else
            raise UnexpectedError, "Unexpected Response: #{error[:message]}"
          end
        else
         raise UnexpectedError, "Unexpected Response: #{error[:message]}"
        end
      end
    end

    def self.to_big_decimal(decimal)
      case decimal
      when BigDecimal, NilClass
        decimal
      when String
        BigDecimal(decimal)
      else
        raise ArgumentError, "Argument must be a String or BigDecimal"
      end
    end

    def self.inspect_amount(amount)
      amount ? "amount: #{amount.to_s("F").inspect}" : "amount: nil"
    end

    def self.verify_keys(valid_keys, hash)
      invalid_keys = _get_invalid_keys(valid_keys, hash)
      if invalid_keys.any?
        sorted = invalid_keys.sort_by { |k| k.to_s }.join(", ")
        raise ArgumentError, "invalid keys: #{sorted}"
      end
    end

    def self.keys_valid?(valid_keys, hash)
      invalid_keys = _get_invalid_keys(valid_keys, hash)

      !invalid_keys.any?
    end

    def self._flatten_valid_keys(valid_keys, namespace = nil)
      valid_keys.inject([]) do |result, key|
        if key.is_a?(Hash)
          full_key = key.keys[0]
          full_key = (namespace ? "#{namespace}[#{full_key}]" : full_key)
          nested_keys = key.values[0]
          if nested_keys.is_a?(Array)
            result += _flatten_valid_keys(nested_keys, full_key)
          else
            result << "#{full_key}[#{nested_keys}]"
          end
        else
          result << (namespace ? "#{namespace}[#{key}]" : key.to_s)
        end
        result
      end.sort
    end

    def self._flatten_hash_keys(element, namespace = nil)
      element = [element] if element.is_a?(String)

      element.inject([]) do |result, (key, value)|
        full_key = (namespace ? "#{namespace}[#{key}]" : key.to_s)
        if value.is_a?(Hash)
          result += _flatten_hash_keys(value, full_key)
        elsif value.is_a?(Array)
          value.each do |item|
            result += _flatten_hash_keys(item, full_key)
          end
        else
          result << full_key
        end
        result
      end.sort
    end

    def self._remove_wildcard_keys(valid_keys, invalid_keys)
      wildcard_keys = valid_keys.select { |k| k.include? "[_any_key_]" }
      return invalid_keys if wildcard_keys.empty?
      wildcard_keys.map! { |wk| wk.sub "[_any_key_]", "" }
      invalid_keys.select do |invalid_key|
        wildcard_keys.all? do |wildcard_key|
          invalid_key.index(wildcard_key) != 0
        end
      end
    end

    def self._get_invalid_keys(valid_keys, hash)
      flattened_valid_keys = _flatten_valid_keys(valid_keys)
      keys = _flatten_hash_keys(hash) - flattened_valid_keys
      keys = _remove_wildcard_keys(flattened_valid_keys, keys)
    end

    module IdEquality
      def ==(other) # :nodoc:
        return false unless other.is_a?(self.class)
        id == other.id
      end
    end

    module TokenEquality
      def ==(other) # :nodoc:
        return false unless other.is_a?(self.class)
        token == other.token
      end
    end
  end
end
