require 'openssl'

module ActiveMerchant
  module NetworkConnectionRetries
    DEFAULT_RETRIES = 3
    DEFAULT_CONNECTION_ERRORS = {
      EOFError               => 'The remote server dropped the connection',
      Errno::ECONNRESET      => 'The remote server reset the connection',
      Timeout::Error         => 'The connection to the remote server timed out',
      Errno::ETIMEDOUT       => 'The connection to the remote server timed out',
      SocketError            => 'The connection to the remote server could not be established',
      Errno::EHOSTUNREACH    => 'The connection to the remote server could not be established',
      OpenSSL::SSL::SSLError => 'The SSL connection to the remote server could not be established'
    }

    def self.included(base)
      base.send(:attr_accessor, :retry_safe)
    end

    def retry_exceptions(options={})
      connection_errors = DEFAULT_CONNECTION_ERRORS.merge(options[:connection_exceptions] || {})

      retry_network_exceptions(options) do
        yield
      rescue Errno::ECONNREFUSED => e
        raise ActiveMerchant::RetriableConnectionError.new('The remote server refused the connection', e)
      rescue OpenSSL::X509::CertificateError => e
        NetworkConnectionRetries.log(options[:logger], :error, e.message, options[:tag])
        raise ActiveMerchant::ClientCertificateError, 'The remote server did not accept the provided SSL certificate'
      rescue Zlib::BufError
        raise ActiveMerchant::InvalidResponseError, 'The remote server replied with an invalid response'
      rescue *connection_errors.keys => e
        raise ActiveMerchant::ConnectionError.new(derived_error_message(connection_errors, e.class), e)
      end
    end

    def self.log(logger, level, message, tag=nil)
      tag ||= self.class.to_s
      message = "[#{tag}] #{message}"
      logger&.send(level, message)
    end

    private

    def retry_network_exceptions(options = {})
      initial_retries = options[:max_retries] || DEFAULT_RETRIES
      retries = initial_retries
      request_start = nil

      begin
        request_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        log_with_retry_details(options[:logger], initial_retries - retries + 1, Process.clock_gettime(Process::CLOCK_MONOTONIC) - request_start, 'success', options[:tag])
        result
      rescue ActiveMerchant::RetriableConnectionError => e
        retries -= 1

        log_with_retry_details(options[:logger], initial_retries - retries, Process.clock_gettime(Process::CLOCK_MONOTONIC) - request_start, e.message, options[:tag])
        retry unless retries.zero?
        raise ActiveMerchant::ConnectionError.new(e.message, e)
      rescue ActiveMerchant::ConnectionError, ActiveMerchant::InvalidResponseError => e
        retries -= 1
        log_with_retry_details(options[:logger], initial_retries - retries, Process.clock_gettime(Process::CLOCK_MONOTONIC) - request_start, e.message, options[:tag])
        retry if (options[:retry_safe] || retry_safe) && !retries.zero?
        raise
      end
    end

    def log_with_retry_details(logger, attempts, time, message, tag)
      NetworkConnectionRetries.log(logger, :info, 'connection_attempt=%d connection_request_time=%.4fs connection_msg="%s"' % [attempts, time, message], tag)
    end

    def derived_error_message(errors, klass)
      key = (errors.keys & klass.ancestors).first
      key ? errors[key] : nil
    end
  end
end
