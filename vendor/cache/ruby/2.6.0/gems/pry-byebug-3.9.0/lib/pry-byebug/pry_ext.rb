# frozen_string_literal: true

require "byebug/processors/pry_processor"

class << Pry
  alias start_without_pry_byebug start

  def start_with_pry_byebug(target = TOPLEVEL_BINDING, options = {})
    if target.is_a?(Binding) && PryByebug.file_context?(target)
      Byebug::PryProcessor.start unless ENV["DISABLE_PRY"]
    else
      # No need for the tracer unless we have a file context to step through
      start_without_pry_byebug(target, options)
    end
  end

  alias start start_with_pry_byebug
end
