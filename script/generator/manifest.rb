module ActiveMerchant #:nodoc:
  module Generator
    class Manifest
      attr_reader :templates, :directories

      def initialize
        @templates, @directories = [], []
        yield self if block_given?
      end

      def template(input, output)
        @templates << { :input => input, :output => output }
      end

      def directory(dir)
        @directories << dir
      end
    end
  end
end
