require 'sinatra'
require 'active_support/core_ext/enumerable'
require 'active_merchant'
require 'json'
require_relative 'config'
require_relative 'version'
require_relative 'error_utils'
require_relative 'gateway_compatibility'

configure do
  if ENV['RACK_ENV'].nil?
    set :environment, :test
  else
    set :environment, ENV['RACK_ENV'].to_s.downcase.to_sym
  end
  set :default_encoding, 'utf-8'
  disable :run, :reload, :static, :sessions

  set :default_open_timeout, 25
  set :default_read_timeout, 45
  set :supported_actions, %w[authorize capture purchase refund void reverse]
  set :creditcard_parameters, %w[first_name last_name number month year verification_value brand track_data track_1_data track_2_data source payment_cryptogram eci transaction_id]
  set :wallet_source_map, { 'apple_pay' => :apple_pay, 'google_pay' => :android_pay }
  set :check_parameters, %w[name routing_number account_number bank_name account_type account_holder_type number institution_number transit_number]
  set :sensitive_fields, %w[
    account_number drivers_license_number number password payment_cryptogram
    pem pem_password private_key ssl_cert ssl_key ssl_key_password
    track_data track_1_data track_2_data verification_value
  ]
end

module Utils
  class ValidationError < ArgumentError; end

  def silence_warnings
    old_verbose, $VERBOSE = $VERBOSE, nil
    yield
  ensure
    $VERBOSE = old_verbose
  end

  def stringify(myhash)
    myhash.each_key do |key|
      if myhash[key].is_a?(Hash)
        stringify(myhash[key])
      elsif myhash[key].is_a?(Numeric) && key != 'amount' && key != 'split_2_amount' && key != 'split_3_amount'
        myhash[key] = myhash[key].to_s
      end
    end
  end

  def flatten_params(params, obj)
    obj.each_key do |key|
      if obj[key].is_a?(Hash)
        flatten_hash(params, obj[key], "#{key}_")
      elsif obj[key].is_a?(Array)
        flatten_array(params, obj[key], "#{key}_")
      else
        params[key.to_s] = clean_string_encoding(obj[key])
      end
    end
  end

  def flatten_hash(params, obj_hash, prefix = '')
    obj_hash.each_key do |key|
      if obj_hash[key].is_a?(Hash)
        flatten_hash(params, obj_hash[key], "#{prefix}#{key}_")
      elsif obj_hash[key].is_a?(Array)
        flatten_array(params, obj_hash[key], "#{prefix}#{key}_")
      else
        params["#{prefix}#{key}"] = clean_string_encoding(obj_hash[key])
      end
    end
  end

  def flatten_array(params, obj_array, prefix = '')
    obj_array.each_with_index do |item, index|
      if item.is_a?(Hash)
        flatten_hash(params, item, "#{prefix}#{index}_")
      elsif item.is_a?(Array)
        flatten_array(params, item, "#{prefix}#{index}_")
      else
        params["#{prefix}#{index}"] = clean_string_encoding(item)
      end
    end
  end

  def log(request_info, logtype, message)
    log_entry = Time.now.to_s
    log_entry += " LogType:#{logtype}"
    unless request_info.nil?
      request_info.each_key do |key|
        log_entry += " #{key.to_s.camelize}:#{request_info[key]}" unless key == :start
      end
    end
    log_entry += " Message:#{message}" unless message.nil?
    File.open(TokenExGateway::LOG_FILE, 'a') { |f| f.puts log_entry } rescue nil
  end

  def boolean_parse(val)
    return val if val.is_a?(TrueClass) || val.is_a?(FalseClass)
    return false if val =~ /false|no/i

    true
  end

  def symbolize_keys(myhash)
    myhash.keys.each do |key|
      symbolize_keys(myhash[key]) if myhash[key].is_a?(Hash)
      myhash[(key.to_sym rescue key) || key] = myhash.delete(key)
    end
  end

  def clean_sensitive_fields(myhash)
    myhash.each_key do |key|
      clean_sensitive_fields(myhash[key]) if myhash[key].is_a?(Hash)
      myhash[key] = "**REMOVED[#{myhash[key].to_s.length}]**" if settings.sensitive_fields.include?(key.downcase)
    end
    myhash
  end

  def required_param(json_data, name, class_type, valid_values = [])
    if json_data[name].nil?
      raise Utils::ValidationError, build_error(:missing_param, "Missing required parameter: #{name}")
    end

    unless json_data[name].is_a?(class_type)
      raise Utils::ValidationError, build_error(:missing_param, "Invalid parameter value: #{name}")
    end

    unless valid_values.empty?
      unless valid_values.include?(json_data[name])
        raise Utils::ValidationError, build_error(:unsupported, "Unsupported option or value for #{name}: #{json_data[name]}")
      end
    end
    json_data[name]
  end

  def remove_and_symbolize(json_hash, reject_values)
    new_hash = json_hash.reject { |k, _v| reject_values.include?(k) }
    symbolize_keys(new_hash)
    new_hash
  end

  def finalize_response(am_response, _gateway = nil)
    res = {}
    res['success'] = am_response.success? || false
    res['test'] = am_response.test?
    res['authorization'] = am_response.authorization || ''
    res['message'] = clean_string_encoding(am_response.message)
    res['avs_result'] = am_response.avs_result
    res['cvv_result'] = am_response.cvv_result
    flat_params = {}
    flatten_params(flat_params, am_response.params)
    res['params'] = flat_params
    res.to_json
  end

  def log_final(request_info, response, _failover = false)
    unless request_info[:start].nil?
      request_info[:resp_time] = ((Time.now - request_info[:start]).to_f * 1000).round(0)
      request_info.delete(:start)
    end
    log(request_info, 'Response', response)
  end

  def clean_string_encoding(param)
    return param unless param.is_a?(String) && param.to_s.encoding.name == 'ASCII-8BIT'

    begin
      param.force_encoding('UTF-8')
    rescue Encoding::UndefinedConversionError
      param.encode!('UTF-8', undef: :replace, invalid: :replace, replace: '')
    end
    param.scrub
  end
end

helpers Utils, TokenExGateway::ErrorUtils

get '/' do
  'I am Alive'
end

get '/about', provides: :json do
  request_info = {}
  request_info[:mode] = settings.environment.to_s
  request_info[:log_file] = TokenExGateway::LOG_FILE
  request_info[:version] = TokenExGateway::VERSION
  request_info[:active_merchant_version] = ActiveMerchant::VERSION if defined? ActiveMerchant
  request_info[:sinatra_version] = Sinatra::VERSION if defined? Sinatra
  request_info[:ruby_version] = "#{RUBY_ENGINE}-#{RUBY_VERSION} (#{RUBY_PLATFORM})"

  log(request_info, 'System', nil)

  request_info.to_json
end

error do
  content_type :json
  build_error(:unknown, 'Server Error')
end

get '/error_codes', provides: :json do
  TokenExGateway::ErrorUtils::ERROR_CODES.to_json
end

post '/process', provides: :json do
  am_gateway = nil
  request_info = { start: Time.now, token_ex_id: 'No_ID', reference: 'No_Ref' }

  begin
    begin
      # Validate & parse JSON
      request.body.rewind
      raw = request.body.read
      body = clean_string_encoding(raw)
      json_post = JSON.parse(body)

      request_info[:token_ex_id] = json_post['tokenex_id'] unless json_post['tokenex_id'].nil?
      request_info[:reference] = json_post['ref'].nil? ? "I#{SecureRandom.hex(16)}" : json_post['ref']

      log_request = JSON.parse(JSON.generate(json_post))

      stringify(json_post)

      # Validate gateway
      gateway_options = required_param(json_post, 'gateway', Hash)
      required_param(gateway_options, 'name', String)

      # Validate Action
      transaction_options = required_param(json_post, 'transaction', Hash)
      required_param(transaction_options, 'action', String, settings.supported_actions)

      request_info[:gateway] = gateway_options['name']
      request_info[:action] = transaction_options['action']
      log(request_info, 'Request', clean_sensitive_fields(log_request).to_json)

      # Block gateway if configured
      if TokenExGateway::BLOCK_GATEWAYS.include?(gateway_options['name'])
        raise Utils::ValidationError, build_error(:gw_blocked_error, "Payment Gateway is Down: #{gateway_options['name']}")
      end

      # Set test mode
      gateway_options['test'] = settings.environment != :production

      # Validate gateway is valid
      begin
        raise NameError unless gateway_options['name'].end_with?('Gateway')

        am_gateway_name = "ActiveMerchant::Billing::#{gateway_options['name']}".constantize
        raise NameError unless am_gateway_name.respond_to?('new')
      rescue NameError
        raise Utils::ValidationError, build_error(:unsupported, "Unsupported gateway: #{gateway_options['name']}")
      end

      # Fixup and validate client-SSL params
      if gateway_options['ssl_cert']
        ssl_key = required_param(gateway_options, 'ssl_key', String)

        begin
          gateway_options['pem'] = "#{gateway_options['ssl_cert']}\r\n\r\n#{ssl_key}"
          ossl_key = if gateway_options['ssl_key_password'].blank?
                       OpenSSL::PKey.read(gateway_options['pem'])
                     else
                       gateway_options['pem_password'] = gateway_options['ssl_key_password'].to_s
                       OpenSSL::PKey.read(gateway_options['pem'], gateway_options['pem_password'])
                     end
          raise StandardError unless ossl_key.private?
        rescue StandardError
          raise OpenSSL::PKey::RSAError
        end
        begin
          ossl_cert = OpenSSL::X509::Certificate.new(gateway_options['pem'])
        rescue StandardError
          raise ActiveMerchant::ClientCertificateError, 'The provided SSL client certificate is invalid.'
        end
        silence_warnings do
          unless ossl_cert.check_private_key(ossl_key)
            raise ActiveMerchant::ClientCertificateError, 'The provided SSL private key does not match the provided SSL client certificate.'
          end
        end
      else
        gateway_options.delete_if { |k, _v| %w[pem pem_password].include?(k) }
      end

      # Create gateway object
      login_options = remove_and_symbolize(gateway_options, %w[name ssl_cert ssl_key ssl_key_password])
      GatewayCompatibility.apply_credential_shim(gateway_options['name'], login_options)
      am_gateway = am_gateway_name.new(login_options)

      # Validate gateway can respond to method
      unless am_gateway.respond_to?(transaction_options['action'].downcase)
        raise Utils::ValidationError, build_error(:unsupported, "Unsupported gateway action: #{gateway_options['name']} - #{transaction_options['action']}")
      end

      # Build payment objects
      am_payment = nil
      if !json_post['credit_card'].nil?
        cc_options = required_param(json_post, 'credit_card', Hash)
        cc_options.select! { |k, _v| settings.creditcard_parameters.include?(k) }

        cc_options['month'] = cc_options['month'][1..] if !cc_options['month'].nil? && cc_options['month'].start_with?('0')
        cc_options['brand'] = ActiveMerchant::Billing::CreditCard.brand?(cc_options['number']) if !cc_options['number'].nil? && cc_options['brand'].nil?

        # IXOONE-3 wallet branch: if a wallet `source` is present, build a
        # NetworkTokenizationCreditCard so the cryptogram/ECI flow through to
        # the downstream acquirer. Map the public product name to the gem's
        # internal symbol; reject unknown sources loudly (the gem otherwise
        # silently falls back to :apple_pay on any unrecognised value).
        if cc_options['source']
          mapped = settings.wallet_source_map[cc_options['source'].to_s.downcase]
          if mapped.nil?
            raise Utils::ValidationError, build_error(:unsupported, "Unsupported wallet source: #{cc_options['source']}")
          end
          cc_options['source'] = mapped
          am_payment = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new(cc_options)
        else
          am_payment = ActiveMerchant::Billing::CreditCard.new(cc_options)
        end

        if !cc_options['month'].nil? && !am_payment.valid_month?(am_payment.month)
          raise Utils::ValidationError, build_error(:unsupported, "Invalid value for creditcard expiration month: #{am_payment.month}")
        end
        if !cc_options['year'].nil? && !am_payment.valid_start_year?(am_payment.year)
          raise Utils::ValidationError, build_error(:unsupported, "Invalid value for creditcard expiration year: #{am_payment.year}")
        end
      elsif !json_post['check'].nil?
        if am_gateway.respond_to?(:supports_check?) && !am_gateway.supports_check?
          raise Utils::ValidationError, build_error(:unsupported, 'Payment gateway does not support check as a payment source')
        end

        ck_options = required_param(json_post, 'check', Hash)
        ck_options.select! { |k, _v| settings.check_parameters.include?(k) }
        am_payment = ActiveMerchant::Billing::Check.new(ck_options)
      end

      # Special case rules
      # Stripe metadata fields must be a hash value
      if gateway_options['name'] == 'StripeGateway' && !transaction_options['metadata'].nil?
        hash = {}
        transaction_options['metadata'].split('|').each do |pair|
          key, value = pair.split('=')
          hash[key.to_s] = value.to_s
        end
        transaction_options['metadata'] = hash
      end

      gw_name = gateway_options['name']

      # Execute gateway action
      am_response = case transaction_options['action'].downcase
                    when 'authorize', 'purchase'
                      if am_payment.nil?
                        raise Utils::ValidationError, build_error(:missing_param, 'No payment source provided (credit_card or check)')
                      end

                      amount = required_param(transaction_options, 'amount', Integer)
                      additional_options = remove_and_symbolize(transaction_options, %w[action amount])
                      GatewayCompatibility.apply_options_shim(gw_name, additional_options)

                      if transaction_options['action'].downcase == 'authorize'
                        am_gateway.authorize(amount, am_payment, additional_options)
                      else
                        am_gateway.purchase(amount, am_payment, additional_options)
                      end
                    when 'capture', 'refund'
                      amount = required_param(transaction_options, 'amount', Integer)
                      auth_ident = transaction_options['authorization']

                      additional_options = remove_and_symbolize(transaction_options, %w[action amount authorization])
                      GatewayCompatibility.apply_options_shim(gw_name, additional_options)

                      # Pass credit card directly instead of legacy serialization
                      unless am_payment.nil?
                        additional_options[:credit_card] = am_payment
                        additional_options[:payment_method] = am_payment if am_gateway.is_a?(ActiveMerchant::Billing::OrbitalGateway)
                      end

                      if transaction_options['action'].downcase == 'capture'
                        am_gateway.capture(amount, auth_ident, additional_options)
                      else
                        GatewayCompatibility.apply_refund_defaults(gw_name, additional_options)
                        # Litle accepts payment object as 2nd argument for standalone refunds
                        if am_payment && am_gateway.is_a?(ActiveMerchant::Billing::LitleGateway)
                          am_gateway.refund(amount, am_payment, additional_options)
                        else
                          am_gateway.refund(amount, auth_ident, additional_options)
                        end
                      end
                    when 'void'
                      auth_ident = required_param(transaction_options, 'authorization', String)

                      additional_options = remove_and_symbolize(transaction_options, %w[action authorization])
                      GatewayCompatibility.apply_options_shim(gw_name, additional_options)
                      additional_options[:credit_card] = am_payment unless am_payment.nil?

                      # Check for action override (e.g., PaymentExpress void → refund)
                      override = GatewayCompatibility.action_override(gw_name, 'void')
                      if override
                        override.call(am_gateway, auth_ident, additional_options)
                      else
                        am_gateway.void(auth_ident, additional_options)
                      end
                    when 'reverse'
                      amount = required_param(transaction_options, 'amount', Integer)
                      authorization = transaction_options['authorization']
                      additional_options = remove_and_symbolize(transaction_options, %w[action amount authorization])
                      GatewayCompatibility.apply_options_shim(gw_name, additional_options)

                      am_gateway.reverse(amount, authorization, am_payment, additional_options)
                    end

      # Apply response compatibility shims (normalize to legacy format)
      GatewayCompatibility.apply_response_shim(gw_name, am_response)

      final = finalize_response(am_response)
      log_final(request_info, final)

      # Debug logging
      if TokenExGateway::DEBUG_TOKENEXIDS.include?(request_info[:token_ex_id])
        log(request_info, 'Raw Request', am_gateway.last_request) unless am_gateway.last_request.nil?
        log(request_info, 'Raw Response', am_gateway.last_response.body) unless am_gateway.last_response.nil?
      end

      final

    rescue JSON::ParserError => e
      error = build_error(:invalid_json, e.to_s)
      log(request_info, 'Error', error.to_s)
      error
    rescue Utils::ValidationError => e
      log(request_info, 'Error', e.to_s)
      e.to_s
    rescue ArgumentError => e
      error = build_error(:missing_param, e.to_s)
      log(request_info, 'AM Error', error.to_s)
      error
    rescue ActiveMerchant::ClientCertificateError => e
      error = build_error(:gw_connect_error, e.to_s)
      log(request_info, 'AM Error', error.to_s)
      error
    rescue ActiveMerchant::ConnectionError, ActiveMerchant::InvalidResponseError => e
      error_msg = e.to_s
      if !e.triggering_exception.nil? && e.triggering_exception.instance_of?(OpenSSL::SSL::SSLError)
        error_msg += " (#{e.triggering_exception})"
      end
      error = build_error(:gw_connect_error, error_msg)
      log(request_info, 'AM Error', error.to_s)
      error
    rescue OpenSSL::PKey::RSAError => _e
      error = build_error(:gw_connect_error, 'The provided SSL private key or SSL key password is invalid.')
      log(request_info, 'AM Error', error.to_s)
      error
    rescue ActiveMerchant::ResponseError => e
      am_response = ActiveMerchant::Billing::Response.new(false, "Error: Payment Gateway returned HTTP error code: #{e.response.code}",
                                                          { error_code: e.response.code, error_body: clean_string_encoding(e.response.body) },
                                                          { test: (TokenExGateway::MODE == :test) })
      final = finalize_response(am_response)
      log_final(request_info, final)
      final
    rescue StandardError => e
      log_msg = "#{e} #{e.backtrace.join("\n   ")}"
      puts "TOKENEX_GATEWAY_EXCEPTION: #{log_msg}"
      STDOUT.flush

      log(request_info, 'Exception', log_msg)

      if !am_gateway.nil? && !am_gateway.last_response.nil?
        msg = 'Error: TokenEx was unable to interpret results from the Payment Gateway. Reference the error_body field for the Payment Gateway response.'
        am_response = ActiveMerchant::Billing::Response.new(false, msg,
                                                            { error_code: am_gateway.last_response.code, error_body: clean_string_encoding(am_gateway.last_response.body) },
                                                            { test: am_gateway.test? })
        final = finalize_response(am_response)
        log_final(request_info, final)
        final
      else
        error = build_error(:unknown)
        log(request_info, 'Error', error)
        error
      end
    end
    rescue StandardError => e
      # Last ditch catch
      log_msg = "#{e} #{e.backtrace.join("\n   ")}"
      puts "TOKENEX_GATEWAY_FINAL_EXCEPTION: #{log_msg}"
      STDOUT.flush

      log(request_info, 'Final Exception', log_msg)
      error = build_error(:unknown)
      log(request_info, 'Error', error)
      error
    end
end
