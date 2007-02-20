class Module
  def mock_methods(mock_methods)
    raise "mock methods needs a block" unless block_given?
    
    original    = self
    namespace   = original.name.split("::")
    class_name  = namespace.last
    
    mod = namespace[0..-2].inject(Object) { |mod, part| mod.const_get(part) }
    
    klass = (original.is_a?(Class) ? Class : Module).new(self) do

      instance_eval do       
        mock_methods.each do |method, proc| 
          define_method("mocked_#{method}", &proc)
          alias_method method, "mocked_#{method}"
        end            
      end
      
    end
    
    begin
      mod.send(:remove_const, class_name)
      mod.const_set(class_name, klass)
      
      yield      
    ensure
      mod.send(:remove_const, class_name)
      mod.const_set(class_name, original)
    end
    
  end
end