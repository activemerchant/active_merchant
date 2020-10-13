# frozen_string_literal: true

module PryByebug
  module Helpers
    #
    # Compatibility helper to handle source location
    #
    module Location
      module_function

      #
      # Current file in the target binding. Used as the default breakpoint
      # location.
      #
      def current_file(source = target)
        # Guard clause for Ruby >= 2.6 providing now Binding#source_location ...
        return source.source_location[0] if source.respond_to?(:source_location)

        # ... to avoid warning: 'eval may not return location in binding'
        source.eval("__FILE__")
      end
    end
  end
end
