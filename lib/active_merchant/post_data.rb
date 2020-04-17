require 'cgi'

module ActiveMerchant
  class PostData < Hash
    class_attribute :required_fields, instance_writer: false
    self.required_fields = []

    def []=(key, value)
      return if value.blank? && !required?(key)

      super
    end

    def to_post_data
      collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join('&')
    end

    alias_method :to_s, :to_post_data

    private

    def required?(key)
      required_fields.include?(key)
    end
  end
end
