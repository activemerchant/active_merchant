module ActiveMerchant #:nodoc:
  module Generator
    class Base
      attr_reader :class_name, :name

      def initialize(name, class_name)
        @name = name
        @class_name = class_name
      end

      def root
        File.dirname(__FILE__) + '/../..'
      end

      def run
        # Create the required directories
        manifest.directories.each do |d|
          if File.exists?("#{root}/#{d}")
            puts "Ignoring existing directory #{d}"
          else 
            puts "Creating directory #{d}"
            Dir.mkdir("#{root}/#{d}")
          end
        end 
        
        manifest.templates.each do |t|
          template = ERB.new(File.read(File.dirname(__FILE__) + "/generators/#{name}/templates/#{t[:input]}"), nil, '-')
          File.open("#{root}/#{t[:output]}", 'w') do |f|
            puts "Writing file #{t[:output]}"
            f.puts template.result(binding)
          end
        end
      end

      def file_name
        @class_name.underscore
      end

      protected
      def record
        Manifest.new{ |m| yield m }
      end
    end
  end
end
