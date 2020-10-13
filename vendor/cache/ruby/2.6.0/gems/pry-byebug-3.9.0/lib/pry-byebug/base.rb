# frozen_string_literal: true

require "pry-byebug/helpers/location"

#
# Main container module for Pry-Byebug functionality
#
module PryByebug
  # Reference to currently running pry-remote server. Used by the processor.
  attr_accessor :current_remote_server

  module_function

  #
  # Checks that a target binding is in a local file context.
  #
  def file_context?(target)
    file = Helpers::Location.current_file(target)
    file == Pry.eval_path || !Pry::Helpers::BaseHelpers.not_a_real_file?(file)
  end

  #
  # Ensures that a command is executed in a local file context.
  #
  def check_file_context(target, msg = nil)
    msg ||= "Cannot find local context. Did you use `binding.pry`?"
    raise(Pry::CommandError, msg) unless file_context?(target)
  end
end
