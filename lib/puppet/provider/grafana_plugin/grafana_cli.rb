Puppet::Type.type(:grafana_plugin).provide(:grafana_cli) do
  has_command(:grafana_cli, 'grafana-cli') do
    is_optional
  end

  defaultfor feature: :posix

  mk_resource_methods

  def self.all_plugins
    plugins = []
    grafana_cli('plugins', 'ls').split(%r{\n}).each do |line|
      next unless line =~ %r{^(\S+)\s+@\s+((?:\d\.).+)\s*$}
      name = Regexp.last_match(1)
      version = Regexp.last_match(2)
      Puppet.debug("Found grafana plugin #{name} #{version}")
      plugins.push(name)
    end
    plugins.sort
  end

  def self.instances
    resources = []
    all_plugins.each do |name|
      plugin = {
        ensure: :present,
        name: name
      }
      resources << new(plugin) if plugin[:name]
    end
    resources
  end

  def self.prefetch(resources)
    plugins = instances
    resources.keys.each do |name|
      if (provider = plugins.find { |plugin| plugin.name == name })
        resources[name].provider = provider
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    if resource[:repo]
      plugin_url = "#{resource[:repo]}/#{resource[:name]}-#{resource[:version]}.#{resource[:extension]}"
      args = ["/usr/sbin/grafana-cli", 'plugins', 'install', resource[:name]]
      options = {
        custom_environment: {
          :GF_PLUGIN_URL => plugin_url
        }
      }
      grafana_cli_with_opts(args, options)
    else
      val = grafana_cli('plugins', 'install', resource[:name])
      notice(val)
    end
    @property_hash[:ensure] = :present
  end

  def destroy
    grafana_cli('plugins', 'uninstall', resource[:name])
    @property_hash[:ensure] = :absent
  end

  private

  def grafana_cli_with_opts(args, options)
    Puppet::Util::Execution.execute(args, options)
  end
end
