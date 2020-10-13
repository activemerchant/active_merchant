require 'mechanize/element_matcher'

# This class encapsulates a form parsed out of an HTML page.  Each type of
# input field available in a form can be accessed through this object.
#
# == Examples
#
# Find a form and print out its fields
#
#   form = page.forms.first # => Mechanize::Form
#   form.fields.each { |f| puts f.name }
#
# Set the input field 'name' to "Aaron"
#
#   form['name'] = 'Aaron'
#   puts form['name']

class Mechanize::Form
  extend Forwardable
  extend Mechanize::ElementMatcher

  attr_accessor :method, :action, :name

  attr_reader :fields, :buttons, :file_uploads, :radiobuttons, :checkboxes

  # Content-Type for form data (i.e. application/x-www-form-urlencoded)
  attr_accessor :enctype

  # Character encoding of form data (i.e. UTF-8)
  attr_accessor :encoding

  # When true, character encoding errors will never be never raised on form
  # submission.  Default is false
  attr_accessor :ignore_encoding_error

  alias :elements :fields

  attr_reader :node
  alias form_node node  # for backward compatibility
  attr_reader :page

  def initialize(node, mech = nil, page = nil)
    @enctype = node['enctype'] || 'application/x-www-form-urlencoded'
    @node             = node
    @action           = Mechanize::Util.html_unescape(node['action'])
    @method           = (node['method'] || 'GET').upcase
    @name             = node['name']
    @clicked_buttons  = []
    @page             = page
    @mech             = mech

    @encoding = node['accept-charset'] || (page && page.encoding) || nil
    @ignore_encoding_error = false
    parse
  end

  # Returns whether or not the form contains a field with +field_name+
  def has_field?(field_name)
    fields.any? { |f| f.name == field_name }
  end

  alias :has_key? :has_field?

  # Returns whether or not the form contains a field with +value+
  def has_value?(value)
    fields.any? { |f| f.value == value }
  end

  # Returns all field names (keys) for this form
  def keys
    fields.map(&:name)
  end

  # Returns all field values for this form
  def values
    fields.map(&:value)
  end

  # Returns all buttons of type Submit
  def submits
    @submits ||= buttons.select { |f| f.class == Submit }
  end

  # Returns all buttons of type Reset
  def resets
    @resets ||= buttons.select { |f| f.class == Reset }
  end

  # Returns all fields of type Text
  def texts
    @texts ||= fields.select { |f| f.class == Text }
  end

  # Returns all fields of type Hidden
  def hiddens
    @hiddens ||= fields.select { |f| f.class == Hidden }
  end

  # Returns all fields of type Textarea
  def textareas
    @textareas ||= fields.select { |f| f.class == Textarea }
  end

  # Returns all fields of type Keygen
  def keygens
    @keygens ||= fields.select { |f| f.class == Keygen }
  end

  # Returns whether or not the form contains a Submit button named +button_name+
  def submit_button?(button_name)
    submits.find { |f| f.name == button_name }
  end

  # Returns whether or not the form contains a Reset button named +button_name+
  def reset_button?(button_name)
    resets.find { |f| f.name == button_name }
  end

  # Returns whether or not the form contains a Text field named +field_name+
  def text_field?(field_name)
    texts.find { |f| f.name == field_name }
  end

  # Returns whether or not the form contains a Hidden field named +field_name+
  def hidden_field?(field_name)
    hiddens.find { |f| f.name == field_name }
  end

  # Returns whether or not the form contains a Textarea named +field_name+
  def textarea_field?(field_name)
    textareas.find { |f| f.name == field_name }
  end

  # This method is a shortcut to get form's DOM id.
  # Common usage:
  #   page.form_with(:dom_id => "foorm")
  # Note that you can also use +:id+ to get to this method:
  #   page.form_with(:id => "foorm")
  def dom_id
    @node['id']
  end

  # This method is a shortcut to get form's DOM class.
  # Common usage:
  #   page.form_with(:dom_class => "foorm")
  # Note that you can also use +:class+ to get to this method:
  #   page.form_with(:class => "foorm")
  # However, attribute values are compared literally as string, so
  # form_with(class: "a") does not match a form with class="a b".
  # Use form_with(css: "form.a") instead.
  def dom_class
    @node['class']
  end

  ##
  # :method: search
  #
  # Shorthand for +node.search+.
  #
  # See Nokogiri::XML::Node#search for details.

  ##
  # :method: css
  #
  # Shorthand for +node.css+.
  #
  # See also Nokogiri::XML::Node#css for details.

  ##
  # :method: xpath
  #
  # Shorthand for +node.xpath+.
  #
  # See also Nokogiri::XML::Node#xpath for details.

  ##
  # :method: at
  #
  # Shorthand for +node.at+.
  #
  # See also Nokogiri::XML::Node#at for details.

  ##
  # :method: at_css
  #
  # Shorthand for +node.at_css+.
  #
  # See also Nokogiri::XML::Node#at_css for details.

  ##
  # :method: at_xpath
  #
  # Shorthand for +node.at_xpath+.
  #
  # See also Nokogiri::XML::Node#at_xpath for details.

  def_delegators :node, :search, :css, :xpath, :at, :at_css, :at_xpath

  # Add a field with +field_name+ and +value+
  def add_field!(field_name, value = nil)
    fields << Field.new({'name' => field_name}, value)
  end

  ##
  # This method sets multiple fields on the form.  It takes a list of +fields+
  # which are name, value pairs.
  #
  # If there is more than one field found with the same name, this method will
  # set the first one found.  If you want to set the value of a duplicate
  # field, use a value which is a Hash with the key as the index in to the
  # form.  The index is zero based.
  #
  # For example, to set the second field named 'foo', you could do the
  # following:
  #
  #   form.set_fields :foo => { 1 => 'bar' }
  def set_fields fields = {}
    fields.each do |name, v|
      case v
      when Hash
        v.each do |index, value|
          self.fields_with(:name => name.to_s)[index].value = value
        end
      else
        value = nil
        index = 0

        [v].flatten.each do |val|
          index = val.to_i if value
          value = val unless value
        end

        self.fields_with(:name => name.to_s)[index].value = value
      end
    end
  end

  # Fetch the value of the first input field with the name passed in. Example:
  #  puts form['name']
  def [](field_name)
    f = field(field_name)
    f && f.value
  end

  # Set the value of the first input field with the name passed in. Example:
  #  form['name'] = 'Aaron'
  def []=(field_name, value)
    f = field(field_name)
    if f
      f.value = value
    else
      add_field!(field_name, value)
    end
  end

  # Treat form fields like accessors.
  def method_missing(meth, *args)
    (method = meth.to_s).chomp!('=')

    if field(method)
      return field(method).value if args.empty?
      return field(method).value = args[0]
    end

    super
  end

  # Submit the form. Does not include the +button+ as a form parameter.
  # Use +click_button+ or provide button as a parameter.
  def submit button = nil, headers = {}
    @mech.submit(self, button, headers)
  end

  # Submit form using +button+. Defaults
  # to the first button.
  def click_button(button = buttons.first)
    submit(button)
  end

  # This method is sub-method of build_query.
  # It converts charset of query value of fields into expected one.
  def proc_query(field)
    return unless field.query_value
    field.query_value.map{|(name, val)|
      [from_native_charset(name), from_native_charset(val.to_s)]
    }
  end
  private :proc_query

  def from_native_charset str
    Mechanize::Util.from_native_charset(str, encoding, @ignore_encoding_error,
                                        @mech && @mech.log)
  end
  private :from_native_charset

  # This method builds an array of arrays that represent the query
  # parameters to be used with this form.  The return value can then
  # be used to create a query string for this form.
  def build_query(buttons = [])
    query = []
    @mech.log.info("form encoding: #{encoding}") if @mech && @mech.log

    save_hash_field_order

    successful_controls = []

    (fields + checkboxes).reject do |f|
      f.node["disabled"]
    end.sort.each do |f|
      case f
      when Mechanize::Form::CheckBox
        if f.checked
          successful_controls << f
        end
      when Mechanize::Form::Field
        successful_controls << f
      end
    end

    radio_groups = {}
    radiobuttons.each do |f|
      fname = from_native_charset(f.name)
      radio_groups[fname] ||= []
      radio_groups[fname] << f
    end

    # take one radio button from each group
    radio_groups.each_value do |g|
      checked = g.select(&:checked)

      if checked.uniq.size > 1 then
        values = checked.map(&:value).join(', ').inspect
        name = checked.first.name.inspect
        raise Mechanize::Error,
              "radiobuttons #{values} are checked in the #{name} group, " \
              "only one is allowed"
      else
        successful_controls << checked.first unless checked.empty?
      end
    end

    @clicked_buttons.each { |b|
      successful_controls << b
    }

    successful_controls.sort.each do |ctrl| # DOM order
      qval = proc_query(ctrl)
      query.push(*qval)
    end

    query
  end

  # This method adds an index to all fields that have Hash nodes. This
  # enables field sorting to maintain order.
  def save_hash_field_order
    index = 0

    fields.each do |field|
      if Hash === field.node
        field.index = index
        index += 1
      end
    end
  end

  # This method adds a button to the query.  If the form needs to be
  # submitted with multiple buttons, pass each button to this method.
  def add_button_to_query(button)
    unless button.node.document == @node.document then
      message =
        "#{button.inspect} does not belong to the same page as " \
        "the form #{@name.inspect} in #{@page.uri}"

      raise ArgumentError, message
    end

    @clicked_buttons << button
  end

  # This method allows the same form to be submitted second time
  # with the different submit button being clicked.
  def reset
    # In the future, should add more functionality here to reset the form values to their defaults.
    @clicked_buttons = []
  end

  CRLF = "\r\n".freeze

  # This method calculates the request data to be sent back to the server
  # for this form, depending on if this is a regular post, get, or a
  # multi-part post,
  def request_data
    query_params = build_query()

    case @enctype.downcase
    when /^multipart\/form-data/
      boundary = rand_string(20)
      @enctype = "multipart/form-data; boundary=#{boundary}"

      delimiter = "--#{boundary}\r\n"

      data = ::String.new

      query_params.each do |k,v|
        if k
          data << delimiter
          param_to_multipart(k, v, data)
        end
      end

      @file_uploads.each do |f|
        data << delimiter
        file_to_multipart(f, data)
      end

      data << "--#{boundary}--\r\n"
    else
      Mechanize::Util.build_query_string(query_params)
    end
  end

  # Removes all fields with name +field_name+.
  def delete_field!(field_name)
    @fields.delete_if{ |f| f.name == field_name}
  end

  ##
  # :method: field_with(criteria)
  #
  # Find one field that matches +criteria+
  # Example:
  #   form.field_with(:id => "exact_field_id").value = 'hello'

  ##
  # :method: field_with!(criteria)
  #
  # Same as +field_with+ but raises an ElementNotFoundError if no field matches
  # +criteria+

  ##
  # :method: fields_with(criteria)
  #
  # Find all fields that match +criteria+
  # Example:
  #   form.fields_with(:value => /foo/).each do |field|
  #     field.value = 'hello!'
  #   end

  elements_with :field

  ##
  # :method: button_with(criteria)
  #
  # Find one button that matches +criteria+
  # Example:
  #   form.button_with(:value => /submit/).value = 'hello'

  ##
  # :method: button_with!(criteria)
  #
  # Same as +button_with+ but raises an ElementNotFoundError if no button
  # matches +criteria+

  ##
  # :method: buttons_with(criteria)
  #
  # Find all buttons that match +criteria+
  # Example:
  #   form.buttons_with(:value => /submit/).each do |button|
  #     button.value = 'hello!'
  #   end

  elements_with :button

  ##
  # :method: file_upload_with(criteria)
  #
  # Find one file upload field that matches +criteria+
  # Example:
  #   form.file_upload_with(:file_name => /picture/).value = 'foo'

  ##
  # :mehtod: file_upload_with!(criteria)
  #
  # Same as +file_upload_with+ but raises an ElementNotFoundError if no button
  # matches +criteria+

  ##
  # :method: file_uploads_with(criteria)
  #
  # Find all file upload fields that match +criteria+
  # Example:
  #   form.file_uploads_with(:file_name => /picutre/).each do |field|
  #     field.value = 'foo!'
  #   end

  elements_with :file_upload

  ##
  # :method: radiobutton_with(criteria)
  #
  # Find one radio button that matches +criteria+
  # Example:
  #   form.radiobutton_with(:name => /woo/).check

  ##
  # :mehtod: radiobutton_with!(criteria)
  #
  # Same as +radiobutton_with+ but raises an ElementNotFoundError if no button
  # matches +criteria+

  ##
  # :method: radiobuttons_with(criteria)
  #
  # Find all radio buttons that match +criteria+
  # Example:
  #   form.radiobuttons_with(:name => /woo/).each do |field|
  #     field.check
  #   end

  elements_with :radiobutton

  ##
  # :method: checkbox_with(criteria)
  #
  # Find one checkbox that matches +criteria+
  # Example:
  #   form.checkbox_with(:name => /woo/).check

  ##
  # :mehtod: checkbox_with!(criteria)
  #
  # Same as +checkbox_with+ but raises an ElementNotFoundError if no button
  # matches +criteria+

  ##
  # :method: checkboxes_with(criteria)
  #
  # Find all checkboxes that match +criteria+
  # Example:
  #   form.checkboxes_with(:name => /woo/).each do |field|
  #     field.check
  #   end

  elements_with :checkbox,   :checkboxes

  def pretty_print(q) # :nodoc:
    q.object_group(self) {
      q.breakable; q.group(1, '{name', '}') { q.breakable; q.pp name }
      q.breakable; q.group(1, '{method', '}') { q.breakable; q.pp method }
      q.breakable; q.group(1, '{action', '}') { q.breakable; q.pp action }
      q.breakable; q.group(1, '{fields', '}') {
        fields.each do |field|
          q.breakable
          q.pp field
        end
      }
      q.breakable; q.group(1, '{radiobuttons', '}') {
        radiobuttons.each { |b| q.breakable; q.pp b }
      }
      q.breakable; q.group(1, '{checkboxes', '}') {
        checkboxes.each { |b| q.breakable; q.pp b }
      }
      q.breakable; q.group(1, '{file_uploads', '}') {
        file_uploads.each { |b| q.breakable; q.pp b }
      }
      q.breakable; q.group(1, '{buttons', '}') {
        buttons.each { |b| q.breakable; q.pp b }
      }
    }
  end

  alias inspect pretty_inspect # :nodoc:

  private

  def parse
    @fields       = []
    @buttons      = []
    @file_uploads = []
    @radiobuttons = []
    @checkboxes   = []

    # Find all input tags
    @node.search('input').each do |node|
      type = (node['type'] || 'text').downcase
      name = node['name']
      next if name.nil? && !%w[submit button image].include?(type)
      case type
      when 'radio'
        @radiobuttons << RadioButton.new(node, self)
      when 'checkbox'
        @checkboxes << CheckBox.new(node, self)
      when 'file'
        @file_uploads << FileUpload.new(node, nil)
      when 'submit'
        @buttons << Submit.new(node)
      when 'button'
        @buttons << Button.new(node)
      when 'reset'
        @buttons << Reset.new(node)
      when 'image'
        @buttons << ImageButton.new(node)
      when 'hidden'
        @fields << Hidden.new(node, node['value'] || '')
      when 'text'
        @fields << Text.new(node, node['value'] || '')
      when 'textarea'
        @fields << Textarea.new(node, node['value'] || '')
      else
        @fields << Field.new(node, node['value'] || '')
      end
    end

    # Find all textarea tags
    @node.search('textarea').each do |node|
      next unless node['name']
      @fields << Textarea.new(node, node.inner_text)
    end

    # Find all select tags
    @node.search('select').each do |node|
      next unless node['name']
      if node.has_attribute? 'multiple'
        @fields << MultiSelectList.new(node)
      else
        @fields << SelectList.new(node)
      end
    end

    # Find all submit button tags
    # FIXME: what can I do with the reset buttons?
    @node.search('button').each do |node|
      type = (node['type'] || 'submit').downcase
      next if type == 'reset'
      @buttons << Button.new(node)
    end

    # Find all keygen tags
    @node.search('keygen').each do |node|
      @fields << Keygen.new(node, node['value'] || '')
    end
  end

  unless ::String.method_defined?(:b)
    # Define String#b for Ruby < 2.0
    class ::String
      def b
        dup.force_encoding(Encoding::ASCII_8BIT)
      end
    end
  end

  def rand_string(len = 10)
    chars = ("a".."z").to_a + ("A".."Z").to_a
    string = ::String.new
    1.upto(len) { |i| string << chars[rand(chars.size-1)] }
    string
  end

  def mime_value_quote(str)
    str.b.gsub(/(["\r\\])/, '\\\\\1')
  end

  def param_to_multipart(name, value, buf = ::String.new)
    buf <<
      "Content-Disposition: form-data; name=\"".freeze <<
      mime_value_quote(name) <<
      "\"\r\n\r\n".freeze <<
      value.b <<
      CRLF
  end

  def file_to_multipart(file, buf = ::String.new)
    file_name = file.file_name ? ::File.basename(file.file_name) : ''

    body = buf <<
           "Content-Disposition: form-data; name=\"".freeze <<
           mime_value_quote(file.name) <<
           "\"; filename=\"".freeze <<
           mime_value_quote(file_name) <<
           "\"\r\nContent-Transfer-Encoding: binary\r\n".freeze

    if file.file_data.nil? and file.file_name
      file.file_data = File.binread(file.file_name)
      file.mime_type =
        WEBrick::HTTPUtils.mime_type(file.file_name,
                                     WEBrick::HTTPUtils::DefaultMimeTypes)
    end

    if file.mime_type
      body << "Content-Type: ".freeze << file.mime_type << CRLF
    end

    body << CRLF

    if file_data = file.file_data
      if file_data.respond_to? :read
        body << file_data.read.force_encoding(Encoding::ASCII_8BIT)
      else
        body << file_data.b
      end
    end

    body << CRLF
  end
end

require 'mechanize/form/field'
require 'mechanize/form/button'
require 'mechanize/form/hidden'
require 'mechanize/form/text'
require 'mechanize/form/textarea'
require 'mechanize/form/submit'
require 'mechanize/form/reset'
require 'mechanize/form/file_upload'
require 'mechanize/form/keygen'
require 'mechanize/form/image_button'
require 'mechanize/form/multi_select_list'
require 'mechanize/form/option'
require 'mechanize/form/radio_button'
require 'mechanize/form/check_box'
require 'mechanize/form/select_list'
