require File.dirname(__FILE__) + '/manifest'
require File.dirname(__FILE__) + '/base'

module ActiveMerchant #:nodoc:
  module Generator
    class Generator
      def self.run(args = [])
        unless args.size == 2
          puts <<-BANNER
Usage: script/generate <generator> <ClassName>
Where <generator> is one of:
  gateway     - Generate a new payment gateway
  integration - Generate a new payment integration
          BANNER
          exit
        end
  
        generator, class_name = ARGV  
        require File.dirname(__FILE__) + "/generators/#{generator}/#{generator}_generator"
        "#{generator.classify}Generator".constantize.new(generator, class_name).run
      end
    end
  end
end
