# frozen_string_literal: true

Puppet::Type.newtype(:hocon_setting) do
  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:setting, namevar: true) do
    desc <<~DESC
      The name of the HOCON file setting to be defined.

      This can be a top-level setting or a setting nested within another
      setting.

      To define a nested setting, give the full path to that setting
      with each level separated by a `.` So, to define a setting `foosetting`
      nested within a setting called `foo` contained on the top level, the
      `setting` parameter would be set to `foo.foosetting`.

      This parameter, along with `path`, is one of two namevars for the
      `hocon_setting` type, meaning that Puppet will give an error if two
      `hocon_setting` resources have the same `setting` and `path` parameters.

      If no `setting` value is explicitly set, the title of the resource will
      be used as the value of `setting`.
    DESC
  end

  newparam(:path, namevar: true) do
    desc <<~DESC
      The HOCON file in which Puppet will ensure the specified setting.

      This parameter, along with `setting`, is one of two namevars for the
      `hocon_setting` type, meaning that Puppet will give an error if two
      `hocon_setting` resources have the same `setting` and `path` parameters.
    DESC

    validate do |value|
      raise(Puppet::Error, "File paths must be fully qualified, not '#{value}'") unless (Puppet.features.posix? && value =~ %r{^/}) || (Puppet.features.microsoft_windows? && (value =~ %r{^.:/} || value =~ %r{^//[^/]+/[^/]+}))
    end
  end

  newproperty(:type) do
    desc <<~DESC
      The type of the value passed into the `value` parameter.

      This value should be a string, with valid values being `'number'`,
      `'boolean'`, `'string'`, `'hash'`, `'array'`, `'array_element'`, and
      `'text'`.

      This parameter will not be need to be set most of the time, as the module
      is generally smart enough to figure this out on its own. There are only
      three cases in which this parameter is required.

      The first is the case in which the `value` type is a single-element
      array. In that case, the `type` parameter will need to be set to
      `'array'`. So, for example, to add a single-element array, you would add
      the following to your manifest:

      ```
      hocon_setting { 'single array setting':
        ensure => present,
        path => '/tmp/foo.conf',
        setting => 'foo',
        value => [1],
        type => 'array',
      }
      ```

      If you are trying to manage single entries in an array (for example,
      adding to an array from a define) you will need to set the `'type'`
      parameter to `'array_element'`. For example, to add to an existing array
      in the 'foo' setting, you can add the following to your manifest:

      ```
      hocon_setting { 'add to array':
        ensure  => present,
        path    => '/tmp/foo.conf',
        setting => 'foo',
        value   => 2,
        type    => 'array_element',
      }
      ```

      Note: When adding an item via 'array_element', the array must already exist in the HOCON file.

      Since this type represents a setting in a configuration file, you can
      pass a string containing the exact text of the value as you want it to
      appear in the file (this is useful, for example, if you want to set a
      parameter to a map or an array but want comments or specific indentation
      on elements in the map/array). In this case, `value` must be a string
      with no leading or trailing whitespace, newlines, or comments that
      contains a valid HOCON value, and the `type` parameter must be set to
      `'text'`. This is an advanced use case, and will not be necessary for
      most users.

      So, for example, say you want to add a map with particular
      indentation/comments into your configuration file at path `foo.bar`. You
      could create a variable like so:

      ```
      $map =
      "{
          # This is setting a
          a : b
          # This is setting c
              c : d
        }"
      ```

      And your configuration file looks like so

      ```
      baz : qux
      foo : {
        a : b
      }
      ```

      You could then write the following in your manifest

      ```
      hocon_setting { 'exact text setting':
        ensure => present,
        path => '/tmp/foo.conf',
        setting => 'foo.bar',
        value => $map,
        type => 'text',
      }
      ```

      And the resulting configuration file would look like so

      ```
      baz : qux
      foo : {
        a : b
        bar : {
            # This is setting a
            a : b
            # This is setting c
                c : d
        }
      }
      ```

      Aside from these three cases, the `type` parameter does not need to be set.
    DESC
    # This property has no default. If it is not supplied, the validation of the "value"
    # property will set one automatically.
  end

  newproperty(:value, array_matching: :all) do
    desc <<~DESC
      The value of the HOCON file setting to be defined
    DESC

    validate do |_val|
      # Grab the value we are going to validate
      value = @shouldorig.is_a?(Array) && (@shouldorig.size > 1 || @resource[:type] == 'array') ? @shouldorig : @shouldorig[0]
      case @resource[:type]
      when 'boolean'
        raise "Type specified as 'boolean' but was #{value.class}" if value != true && value != false
      when 'string', 'text'
        raise "Type specified as #{@resource[:type]} but was #{value.class}" unless value.is_a?(String)
      when 'number'
        # Puppet stringifies numerics in versions of Puppet < 4.0.0
        # Account for this by first attempting to cast to an Integer.
        # Failing that, attempt to cast to a Float or return false
        numeric_as_string = begin
          Integer(value)
        rescue StandardError
          false
        end
        numeric_as_string = begin
          numeric_as_string || Float(value)
        rescue StandardError
          false
        end

        raise "Type specified as 'number' but was #{value.class}" unless value.is_a?(Numeric) || numeric_as_string
      when 'array'
        raise "Type specified as 'array' but was #{value.class}" unless value.is_a?(Array)
      when 'hash'
        raise "Type specified as 'hash' but was #{value.class}" unless value.is_a?(Hash)
      when 'array_element', nil
      # Do nothing, we'll figure it out on our own
      else
        raise "Type was specified as #{@resource[:type]}, but should have been one of 'boolean', 'string', 'text', 'number', 'array', or 'hash'"
      end
    end

    munge do |value|
      if value.is_a?(String) && @resource[:type] == 'number'
        munged_value = begin
          Integer(value)
        rescue StandardError
          false
        end
        value = munged_value || Float(value)
      end
      value
    end

    def insync?(is)
      case @resource[:type]
      when 'array_element'
        # make sure all passed values are in the file
        Array(@resource[:value]).each do |v|
          return false unless provider.value.flatten.include?(v)
        end
        true
      when 'array'
        # Works around a bug in Puppet
        # See: https://tickets.puppetlabs.com/browse/HC-99
        is == @should
      else
        super
      end
    end

    def change_to_s(current, new)
      if @resource[:type] == 'array_element'
        real_new = []
        real_new << current
        real_new << new
        real_new.flatten!
        real_new.uniq!
        "value changed [#{Array(current).flatten.join(', ')}] to [#{real_new.join(', ')}]"
      else
        super
      end
    end
  end

  def self.title_patterns
    # This is the default title pattern for all types, except hard-wired to
    # set the title to :setting instead of :name. This is also hard-wired to
    # ONLY set :setting and nothing else, and this will be overridden if
    # the :setting parameter is set manually.
    [[%r{(.*)}m, [[:setting]]]]
  end

  validate do
    message = ''
    message += 'path is a required parameter. ' if original_parameters[:path].nil?
    message += 'setting is a required parameter. ' if original_parameters[:setting].nil?
    message += 'value is a required parameter unless ensuring a setting is absent.' if original_parameters[:value].nil? && self[:ensure] != :absent
    raise(Puppet::Error, message) if message != ''
  end
end
