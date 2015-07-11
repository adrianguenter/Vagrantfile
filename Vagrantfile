#!/usr/bin/env ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :
# »»»
require 'singleton'
require 'ostruct'
require 'securerandom'
require 'yaml'
require 'erb'
require 'optparse'
# «««
# ——— Lib ———
# »»»
class Object
  # @return [Boolean]
  #
  # Returns self if self is boolean true or false,
  # otherwise the (optional) default is returned
  def filter_boolean_value(default=false)
    [true, false].include?(self) ? self : default
  end
end
# «««
# ——— Vagrantfile ———
# »»»
Vagrantfile = Object.new
class << Vagrantfile
  API_VERSION     = '2'
  VAGRANT_VERSION = '>= 1.7.0'
  PATH            = __FILE__
  DATA_PATH       = ENV['VFD_PATH'] ||= "#{__dir__}/Vagrantfile.d"

  @config
  @instance_id
  attr_reader :config, :instance_id

  def do
    _load_config

    unless Object.const_defined?('Vagrant')
      # TODO command-line stuff here
      puts 'COMMAND LINE'
      exit
    end

    @instance_id = "#{@config.ENV[:name]}-#{SecureRandom.hex(3)}"

    Vagrant.require_version VAGRANT_VERSION
    # TODO Merge in user definable (options.conf.yaml?) plugins here?
    %w(vagrant-triggers).each do |plugin|
      abort("Missing plugin, please run: vagrant plugin install #{plugin}") unless Vagrant.has_plugin? plugin
    end
    ENV['VAGRANT_DEFAULT_PROVIDER'] ||= 'docker'

    Vagrant.configure(API_VERSION) do |config|
      # Turn off shared folders
      config.vm.synced_folder ".", "/vagrant", id: "vagrant-root", disabled: true

      # Box
      @config.ENV[:boxes].each do |bname, bcfg|
        config.vm.define bname, primary: bcfg[:is_primary] do |b|
          # TODO? Provisioners

          # Providers
          bcfg[:providers].each do |pname, pcfg|
            b.vm.provider pname do |p|
              case pname
                when :docker
                  p.name            = pcfg[:name] ||= "#{bname}.#{@instance_id}"
                  p.image           = pcfg[:'.image']
                  p.build_dir       = pcfg[:build_dir]
                  p.build_args      = pcfg[:build_args] ||= []
                  p.create_args     = pcfg[:create_args] ||= ["-h", "#{p.name}"]
                  p.remains_running = pcfg[:remains_running].filter_boolean_value(true)
                # TODO? passthrough remaining pairs, mapping p.[key] > value
                else
                  # TODO passthrough all pairs, mapping p.[key] > value, letting Vagrant manage error checking
                  raise "Unsupported provider #{pname} for box #{bname}"
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
          Array(bcfg[:synced_folders]).each do |args|
            b.vm.synced_folder(*args)
          end
        end
      end

      config.trigger.before [:up, :reload] do
        #
      end

      config.trigger.after [:up, :reload] do

        puts @machine.name.inspect
        puts @machine.provider.inspect
        puts @machine.provider_config.inspect
        puts @machine.provider_name.inspect
        puts @machine.provider_options.inspect
        puts @machine.ui.inspect
        puts @machine.vagrantfile.inspect

        exit
        vfconfig = Vagrantfile.config
        boxes = vfconfig.ENV[:boxes]
        ips   = {}

        # Grab IP address for all Docker container boxes
        boxes.select { |bname, bcfg| bcfg[:providers].key?(:docker) }.each do |bname, bcfg|
          # TODO Write this to box props not config
          ip = `docker inspect --format '{{ .NetworkSettings.IPAddress }}' #{bcfg[:providers][:docker][:name]}`.strip
          next if ip.empty?
          puts "#{bname}: #{ip}"
          ips[bname] = ip
        end

        # read from "docker logs" here to get DB credentials into wp-config.php?

        if vfconfig.LOCAL[:nsupdate][:enabled]
          boxes.keys.select { |bname| ips.include?(bname) }.each do |bname|
            cmds = "( echo 'server localhost';"
            boxes[bname][:nsupdate_domains].each do |domain|
              cmds << "echo 'update delete #{domain}. IN A'; echo 'update add #{domain}. 3600 IN A #{ips[bname]}';"
            end
            cmds << "echo 'send' ) | nsupdate -D -k '#{vfconfig.LOCAL[:nsupdate][:keyfile_path]}' 2>&1"
            puts cmds
            puts `#{cmds}`.split(/\n+/).select { |l| l =~ /opcode: UPDATE|(IN|ANY)\s+(?!(SOA|NS))[A-Z]+|could not/ }
          end
        end

        puts boxes
      end
    end
  end

  def _load_config
    @config = ConfigLoader.new(
        {
            :OPTIONS => "#{DATA_PATH}/config/options.conf.yaml",
            :ENV     => "#{DATA_PATH}/config/env.conf.yaml",
            :LOCAL   => "#{DATA_PATH}/config/local.conf.yaml"
        }
    ).load
  end

  private :_load_config

  class ConfigLoader
    class Config < Object
    end

    def initialize(files)
      @files  = files
      @config = Config.new
    end

    attr_accessor :files

    def get(namespace=false, autoload=true)
      if namespace
        load namespace unless defined? @config[namespace] or not autoload
        return @config[namespace]
      end
      load unless empty?(@files.keys - @config.instance_variables) or not autoload
      @config
    end

    def load(namespace=false)
      if namespace
        unless @config.instance_variable_defined?("@#{namespace}")
          @config.class.class_eval { attr_reader namespace.to_sym }
        end
        file_data = _load_file(@files[namespace])
        @config.instance_variable_set("@#{namespace}", file_data)
        return file_data
      end

      @files.each_key do |key|
        load(key)
      end
      @config
    end

    def _load_file(path)
      OpenStruct.new YAML.load_file(path)
    end

    private :_load_file
  end
end
# «««
# ——— Init ———
# »»»
Vagrantfile.do
