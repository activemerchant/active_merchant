##
# This class represents a check box found in a Form.  To activate the CheckBox
# in the Form, set the checked method to true.

class Mechanize::Form::CheckBox < Mechanize::Form::RadioButton

  def query_value
    [[@name, @value || "on"]]
  end
  
  def inspect # :nodoc:
    "[%s:0x%x type: %s name: %s value: %s]" % [
      self.class.name.sub(/Mechanize::Form::/, '').downcase,
      object_id, type, name, checked
    ]
  end

end

