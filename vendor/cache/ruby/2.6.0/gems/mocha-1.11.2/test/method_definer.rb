require 'mocha/singleton_class'

module MethodDefiner
  def define_instance_method(object, method_symbol, &block)
    object.singleton_class.send(:define_method, method_symbol, block)
  end

  def replace_instance_method(object, method_symbol, &block)
    raise "Cannot replace #{method_symbol} as #{self} does not respond to it." unless object.respond_to?(method_symbol)
    define_instance_method(object, method_symbol, &block)
  end

  def define_instance_accessor(object, *symbols)
    symbols.each { |symbol| object.singleton_class.send(:attr_accessor, symbol) }
  end
end
