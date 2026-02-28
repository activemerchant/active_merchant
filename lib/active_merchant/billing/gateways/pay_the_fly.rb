module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayTheFlyGateway < Gateway
      self.display_name = 'PayTheFly'
      self.homepage_url = 'https://pro.paythefly.com'

      self.supported_countries = %w[US GB SG AE HK JP KR CN]
      self.default_currency = 'USDT'
      self.money_format = :cents

      PAYMENT_URL = 'https://pro.paythefly.com/pay'
      WITHDRAWAL_URL = 'https://pro.paythefly.com/withdraw'

      EIP712_DOMAIN_NAME = 'PayTheFlyPro'
      EIP712_DOMAIN_VERSION = '1'

      CHAINS = {
        'BSC' => { chain_id: 56, decimals: 18 },
        'TRON' => { chain_id: 728126428, decimals: 6 }
      }.freeze

      PAYMENT_TX_TYPE = 1
      WITHDRAWAL_TX_TYPE = 2

      def initialize(options = {})
        requires!(options, :project_id, :project_key, :private_key)
        @project_id = options[:project_id]
        @project_key = options[:project_key]
        @private_key = options[:private_key]
        @chain = options[:chain] || 'BSC'
        @token_address = options[:token_address]
        @contract_address = options[:contract_address]
        super
      end

      def purchase(money, _payment, options = {})
        chain = options[:chain] || @chain
        chain_config = CHAINS[chain]

        return invalid_chain_response(chain) unless chain_config

        serial_no = options[:order_id] || generate_serial_no
        token = options[:token_address] || @token_address
        deadline = options[:deadline] || (Time.now.to_i + 3600)
        human_amount = human_readable_amount(money, chain_config[:decimals])
        raw_amount = raw_unit_amount(money, chain_config[:decimals])

        signature = sign_payment_request(
          project_id: @project_id,
          token: token,
          amount: raw_amount,
          serial_no: serial_no,
          deadline: deadline,
          chain_id: chain_config[:chain_id]
        )

        payment_url = build_payment_url(
          chain_id: chain_config[:chain_id],
          project_id: @project_id,
          amount: human_amount,
          serial_no: serial_no,
          deadline: deadline,
          signature: signature,
          token: token
        )

        Response.new(
          true,
          'Payment URL generated successfully',
          {
            payment_url: payment_url,
            serial_no: serial_no,
            amount: human_amount,
            raw_amount: raw_amount,
            chain: chain,
            chain_id: chain_config[:chain_id],
            token: token,
            deadline: deadline,
            signature: signature
          },
          authorization: serial_no,
          test: test?
        )
      rescue StandardError => e
        Response.new(false, e.message, {}, test: test?, error_code: STANDARD_ERROR_CODE[:processing_error])
      end

      def withdraw(money, user_address, options = {})
        chain = options[:chain] || @chain
        chain_config = CHAINS[chain]

        return invalid_chain_response(chain) unless chain_config

        serial_no = options[:order_id] || generate_serial_no
        token = options[:token_address] || @token_address
        deadline = options[:deadline] || (Time.now.to_i + 3600)
        human_amount = human_readable_amount(money, chain_config[:decimals])
        raw_amount = raw_unit_amount(money, chain_config[:decimals])

        signature = sign_withdrawal_request(
          user: user_address,
          project_id: @project_id,
          token: token,
          amount: raw_amount,
          serial_no: serial_no,
          deadline: deadline,
          chain_id: chain_config[:chain_id]
        )

        withdrawal_url = build_withdrawal_url(
          chain_id: chain_config[:chain_id],
          project_id: @project_id,
          amount: human_amount,
          serial_no: serial_no,
          deadline: deadline,
          signature: signature,
          token: token,
          user: user_address
        )

        Response.new(
          true,
          'Withdrawal URL generated successfully',
          {
            withdrawal_url: withdrawal_url,
            serial_no: serial_no,
            amount: human_amount,
            raw_amount: raw_amount,
            chain: chain,
            chain_id: chain_config[:chain_id],
            token: token,
            user: user_address,
            deadline: deadline,
            signature: signature
          },
          authorization: serial_no,
          test: test?
        )
      rescue StandardError => e
        Response.new(false, e.message, {}, test: test?, error_code: STANDARD_ERROR_CODE[:processing_error])
      end

      # Verify webhook notification from PayTheFly
      #
      # @param body [Hash] The parsed webhook body with keys: data, sign, timestamp
      # @return [Hash, nil] Parsed notification data if valid, nil if verification fails
      def self.verify_webhook(project_key, body)
        data = body['data'] || body[:data]
        sign = body['sign'] || body[:sign]
        timestamp = body['timestamp'] || body[:timestamp]

        return nil unless data && sign && timestamp

        expected_sign = compute_webhook_signature(data, timestamp.to_s, project_key)
        return nil unless secure_compare(expected_sign, sign.to_s.downcase)

        JSON.parse(data)
      rescue JSON::ParserError
        nil
      end

      # Instance method wrapper for webhook verification
      def verify_webhook(body)
        self.class.verify_webhook(@project_key, body)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(project_key=)[^&\s]*/, '\1[FILTERED]').
          gsub(/(private_key=)[^&\s]*/, '\1[FILTERED]').
          gsub(/(signature=)[^&\s]*/, '\1[FILTERED]')
      end

      private

      def human_readable_amount(money_cents, decimals)
        # active_merchant passes money in cents; convert to human-readable
        # For crypto: cents → token units
        # e.g., 100 cents = 1.00 USDT
        amount = money_cents.to_f / 100.0
        if decimals >= 8
          format('%.8f', amount).sub(/0+$/, '').sub(/\.$/, '.0')
        else
          format("%.#{[decimals, 6].min}f", amount).sub(/0+$/, '').sub(/\.$/, '.0')
        end
      end

      def raw_unit_amount(money_cents, decimals)
        # Convert cents to raw blockchain units (wei for BSC, sun for TRON)
        # 100 cents = 1.00 USDT = 1 * 10^decimals raw units
        amount_float = money_cents.to_f / 100.0
        (amount_float * (10**decimals)).to_i.to_s
      end

      def sign_payment_request(params)
        # EIP-712 typed data signing for PaymentRequest
        domain_data = eip712_domain(params[:chain_id])
        message = {
          'projectId' => params[:project_id],
          'token' => params[:token],
          'amount' => params[:amount],
          'serialNo' => params[:serial_no],
          'deadline' => params[:deadline].to_s
        }

        sign_typed_data(domain_data, 'PaymentRequest', payment_request_types, message)
      end

      def sign_withdrawal_request(params)
        # EIP-712 typed data signing for WithdrawalRequest
        domain_data = eip712_domain(params[:chain_id])
        message = {
          'user' => params[:user],
          'projectId' => params[:project_id],
          'token' => params[:token],
          'amount' => params[:amount],
          'serialNo' => params[:serial_no],
          'deadline' => params[:deadline].to_s
        }

        sign_typed_data(domain_data, 'WithdrawalRequest', withdrawal_request_types, message)
      end

      def eip712_domain(chain_id)
        {
          'name' => EIP712_DOMAIN_NAME,
          'version' => EIP712_DOMAIN_VERSION,
          'chainId' => chain_id,
          'verifyingContract' => @contract_address
        }
      end

      def payment_request_types
        {
          'PaymentRequest' => [
            { 'name' => 'projectId', 'type' => 'string' },
            { 'name' => 'token', 'type' => 'address' },
            { 'name' => 'amount', 'type' => 'uint256' },
            { 'name' => 'serialNo', 'type' => 'string' },
            { 'name' => 'deadline', 'type' => 'uint256' }
          ]
        }
      end

      def withdrawal_request_types
        {
          'WithdrawalRequest' => [
            { 'name' => 'user', 'type' => 'address' },
            { 'name' => 'projectId', 'type' => 'string' },
            { 'name' => 'token', 'type' => 'address' },
            { 'name' => 'amount', 'type' => 'uint256' },
            { 'name' => 'serialNo', 'type' => 'string' },
            { 'name' => 'deadline', 'type' => 'uint256' }
          ]
        }
      end

      def sign_typed_data(domain, primary_type, types, message)
        domain_separator = hash_struct('EIP712Domain', eip712_domain_types, domain)
        message_hash = hash_struct(primary_type, types[primary_type], message)

        # EIP-712: encode as \x19\x01 ‖ domainSeparator ‖ hashStruct(message)
        data = ['1901'].pack('H*') + domain_separator + message_hash
        msg_hash = keccak256(data)

        # Sign with private key (secp256k1 ECDSA)
        sign_hash(msg_hash)
      end

      def eip712_domain_types
        [
          { 'name' => 'name', 'type' => 'string' },
          { 'name' => 'version', 'type' => 'string' },
          { 'name' => 'chainId', 'type' => 'uint256' },
          { 'name' => 'verifyingContract', 'type' => 'address' }
        ]
      end

      def hash_struct(type_name, fields, data)
        type_hash = keccak256(encode_type(type_name, fields))
        encoded_values = fields.map { |f| encode_field(f['type'], data[f['name']]) }
        keccak256(type_hash + encoded_values.join)
      end

      def encode_type(name, fields)
        "#{name}(#{fields.map { |f| "#{f['type']} #{f['name']}" }.join(',')})"
      end

      def encode_field(type, value)
        case type
        when 'string'
          keccak256(value.to_s)
        when 'address'
          [value.to_s.sub(/\A0x/, '').rjust(64, '0')].pack('H*')
        when 'uint256'
          [value.to_s.to_i.to_s(16).rjust(64, '0')].pack('H*')
        when 'bytes32'
          [value.to_s.sub(/\A0x/, '').ljust(64, '0')].pack('H*')
        when 'bool'
          [value ? '1' : '0'].pack('H*').rjust(32, "\x00")
        else
          keccak256(value.to_s)
        end
      end

      def keccak256(data)
        OpenSSL::Digest.new('SHA3-256').digest(data.b)
      end

      def sign_hash(msg_hash)
        key = OpenSSL::PKey::EC.new('secp256k1')
        private_key_bn = OpenSSL::BN.new(@private_key.sub(/\A0x/, ''), 16)
        key.private_key = private_key_bn

        # Compute public key from private key
        group = OpenSSL::PKey::EC::Group.new('secp256k1')
        public_key_point = group.generator.mul(private_key_bn)
        key.public_key = public_key_point

        signature = key.dsa_sign_asn1(msg_hash)

        # Convert DER-encoded signature to r, s values
        asn1 = OpenSSL::ASN1.decode(signature)
        r = asn1.value[0].value.to_i
        s = asn1.value[1].value.to_i

        # Ensure low-s (EIP-2)
        order = group.order.to_i
        s = order - s if s > order / 2

        # Recovery id (v = 27 or 28)
        v = recover_v(msg_hash, r, s, public_key_point)

        '0x' + r.to_s(16).rjust(64, '0') + s.to_s(16).rjust(64, '0') + v.to_s(16).rjust(2, '0')
      end

      def recover_v(msg_hash, r, s, public_key_point)
        group = OpenSSL::PKey::EC::Group.new('secp256k1')
        [27, 28].each do |v|
          begin
            recovered = recover_public_key(msg_hash, r, s, v - 27, group)
            return v if recovered && recovered == public_key_point
          rescue StandardError
            next
          end
        end
        27 # fallback
      end

      def recover_public_key(msg_hash, r, s, recovery_id, group)
        # ECDSA public key recovery
        n = group.order.to_i
        r_bn = OpenSSL::BN.new(r.to_s)

        # Calculate R point
        x = r + (recovery_id >= 2 ? n : 0)
        prefix = (recovery_id & 1).zero? ? '02' : '03'
        r_point = OpenSSL::PKey::EC::Point.new(
          group,
          OpenSSL::BN.new([prefix + x.to_s(16).rjust(64, '0')].pack('H*'), 2)
        )

        e = OpenSSL::BN.new(msg_hash.unpack1('H*'), 16).to_i
        r_inv = OpenSSL::BN.new(r.to_s).mod_inverse(OpenSSL::BN.new(n.to_s))

        # Q = r^-1 * (s * R - e * G)
        s_r = r_point.mul(OpenSSL::BN.new(s.to_s))
        e_neg = n - e
        e_g = group.generator.mul(OpenSSL::BN.new(e_neg.to_s))

        point_sum = s_r
        point_sum = point_sum.mul(OpenSSL::BN.new('1'), e_g) rescue nil
        return nil unless point_sum

        point_sum.mul(r_inv)
      rescue StandardError
        nil
      end

      def build_payment_url(params)
        query = URI.encode_www_form(
          chainId: params[:chain_id],
          projectId: params[:project_id],
          amount: params[:amount],
          serialNo: params[:serial_no],
          deadline: params[:deadline],
          signature: params[:signature],
          token: params[:token]
        )
        "#{PAYMENT_URL}?#{query}"
      end

      def build_withdrawal_url(params)
        query = URI.encode_www_form(
          chainId: params[:chain_id],
          projectId: params[:project_id],
          amount: params[:amount],
          serialNo: params[:serial_no],
          deadline: params[:deadline],
          signature: params[:signature],
          token: params[:token],
          user: params[:user]
        )
        "#{WITHDRAWAL_URL}?#{query}"
      end

      def generate_serial_no
        "PTF-#{Time.now.to_i}-#{SecureRandom.hex(4)}"
      end

      def invalid_chain_response(chain)
        Response.new(
          false,
          "Unsupported chain: #{chain}. Supported chains: #{CHAINS.keys.join(', ')}",
          {},
          test: test?,
          error_code: STANDARD_ERROR_CODE[:config_error]
        )
      end

      def self.compute_webhook_signature(data, timestamp, project_key)
        OpenSSL::HMAC.hexdigest('SHA256', project_key, "#{data}.#{timestamp}")
      end

      def self.secure_compare(a, b)
        return false unless a.bytesize == b.bytesize

        l = a.unpack("C#{a.bytesize}")
        res = 0
        b.each_byte { |byte| res |= byte ^ l.shift }
        res.zero?
      end
    end
  end
end
