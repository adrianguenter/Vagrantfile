# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'yaml'
require 'securerandom'
require_relative 'lib/object'
require_relative 'lib/ag_vagrantfile'

Vagrant.require_version ">= 1.7.0"
%w(vagrant-triggers).each do |plugin|
  abort("Missing plugin, please run: vagrant plugin install #{plugin}") unless Vagrant.has_plugin? plugin
end
VAGRANTFILE_API_VERSION = '2'

ENV['VAGRANT_DEFAULT_PROVIDER'] ||= 'docker'


if AGVagrantfile.cfg[:local][:nsupdate][:enabled] ||= false
  AGVagrantfile.cfg[:local][:nsupdate].key?(:keyfile_path) or
      abort("nsupdate.enabled requires nsupdate.keyfile_path in #{AGVagrantfile::LOCAL_CONF_PATH}")
end

AGVagrantfile.cfg[:env][:name] || abort("Missing name in #{AGVagrantfile::ENV_CONF_PATH}")
AGVagrantfile::INSTANCE_ID = "#{AGVagrantfile.cfg[:env][:name]}-#{SecureRandom.hex(3)}"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # Turn off shared folders
  config.vm.synced_folder ".", "/vagrant", id: "vagrant-root", disabled: true

  AGVagrantfile.cfg[:env][:boxes].each do |name, cfg|
    config.vm.define name, primary: cfg[:is_primary] do |box|
      cfg[:providers].each do |pname, pcfg|
        box.vm.provider pname do |p|
          case pname
            when :docker
              p.name = pcfg[:name] ||= "#{name}.#{AGVagrantfile::INSTANCE_ID}"
              p.image = pcfg[:'.image']
              p.build_dir = pcfg[:build_dir]
              p.build_args = pcfg[:build_args] ||= []
              p.create_args = pcfg[:create_args] ||= ["-h", "#{p.name}"]
              p.remains_running = pcfg[:remains_running].filter_boolean_value(true)
            else
              raise "Unsupported provider #{pname} for box #{name}"
          end

          # Overwrite the box_config hash with the
          # Vagrant provider's instance vars
          p.instance_variables.each do |var|
            # Chop off @ from beginning of var
            pcfg[var[1..-1].to_sym] = p.instance_variable_get(var)
          end
        end
      end

      # Initialize synced folders
      Array(cfg[:synced_folders]).each do |args|
        box.vm.synced_folder(*args)
      end
    end
  end

  config.trigger.before [:up, :reload] do
    #puts AGVagrantfile.cfg[:env][:boxes]
  end

  config.trigger.after [:up, :reload] do
    boxes = AGVagrantfile.cfg[:env][:boxes]
    # Grab IP address for all Docker container boxes
    boxes.select { |_, cfg| cfg[:provider] == :docker }.each do |cfg|
      cfg[:ip_address] = `docker inspect --format '{{ .NetworkSettings.IPAddress }}' #{cfg[:name]}`.strip
    end

    # read from "docker logs" here to get DB credentials into wp-config.php?

    if AGVagrantfile.cfg[:local][:nsupdate][:enabled]
      boxes.each do |name, cfg|
        cmds = "( echo 'server localhost'; "
        cfg[:nsupdate_domains].each do |domain|
          cmds += "echo 'update delete #{domain}. IN A'; echo 'update add #{domain}. 3600 IN A #{cfg[:ip_address]}';"
        end
        cmds += "echo 'send' ) | nsupdate -D -k '#{AGVagrantfile.cfg[:local][:nsupdate][:keyfile_path]}' 2>&1"

        puts `#{cmds}`.split(/\n+/).select { |l| l =~ /opcode: UPDATE|(IN|ANY)\s+(?!(SOA|NS))[A-Z]+|could not/ }
      end
    end

    puts boxes
  end
end