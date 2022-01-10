require 'yaml'

def yaml_load_wrapper(yaml, permitted_classes = [], permitted_symbols = [], aliases = false, filename = nil)
  if Psych::VERSION < '4.0'
    YAML.safe_load(yaml, permitted_classes, permitted_symbols, aliases)
  else
    YAML.safe_load(yaml, permitted_classes: permitted_classes, permitted_symbols: permitted_symbols, aliases: aliases)
  end
end
