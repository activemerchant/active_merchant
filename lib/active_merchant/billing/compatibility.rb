module ActiveMerchant
  module Billing
    module Compatibility
      module Model
        def valid?
          Compatibility.deprecated
          super
        end

        def errors
          Compatibility.deprecated
          internal_errors
        end
      end

      @rails_required = false
      def self.rails_required!
        @rails_required = true
      end

      def self.deprecated
        ActiveMerchant.deprecated(
          %(Implicit inclusion of Rails-specific functionality is deprecated.) +
          %( Explicitly require "active_merchant/billing/rails" if you need it.)
        ) unless @rails_required
      end

      def self.humanize(lower_case_and_underscored_word)
        result = lower_case_and_underscored_word.to_s.dup
        result.gsub!(/_id$/, '')
        result.gsub!(/_/, ' ')
        result.gsub(/([a-z\d]*)/i, &:downcase).gsub(/^\w/) { $&.upcase }
      end
    end
  end
end

# This lives in compatibility until we remove the deprecation for implicitly
# requiring Rails
module ActiveMerchant
  module Billing
    module Rails
      module Model
        def valid?
          internal_errors.clear

          validate.each do |attribute, errors|
            errors.each do |error|
              internal_errors.add(attribute, error)
            end
          end

          internal_errors.empty?
        end

        private

        def internal_errors
          @errors ||= Errors.new
        end

        class Errors < Hash
          def initialize
            super() { |h, k| h[k] = [] }
          end

          alias count size

          def [](key)
            super(key.to_s)
          end

          def []=(key, value)
            super(key.to_s, value)
          end

          def empty?
            all? { |k, v| v&.empty? }
          end

          def on(field)
            self[field].to_a.first
          end

          def add(field, error)
            self[field] << error
          end

          def add_to_base(error)
            add(:base, error)
          end

          def each_full
            full_messages.each { |msg| yield msg }
          end

          def full_messages
            result = []

            self.each do |key, messages|
              next unless messages && !messages.empty?

              if key == 'base'
                result << messages.first.to_s
              else
                result << "#{Compatibility.humanize(key)} #{messages.first}"
              end
            end

            result
          end
        end
      end
    end

    Compatibility::Model.send(:include, Rails::Model)
  end
end
