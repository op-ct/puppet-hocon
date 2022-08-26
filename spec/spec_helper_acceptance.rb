# frozen_string_literal: true

require 'voxpupuli/acceptance/spec_helper_acceptance'

configure_beaker

require 'beaker-rspec/spec_helper'
require 'beaker-rspec/helpers/serverspec'
require 'beaker/puppet_install_helper'

run_puppet_install_helper unless ENV['RS_PROVISION'] == 'no'

RSpec.configure do |c|
  # Project root
  proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    # Install module and dependencies
    hosts.each do |host|
      if host['platform'] =~ %r{windows}i
        on host, puppet('plugin download')
      else
        copy_root_module_to(host, source: proj_root, module_name: 'hocon')
      end
    end
  end

  c.treat_symbols_as_metadata_keys_with_true_values = true
end
