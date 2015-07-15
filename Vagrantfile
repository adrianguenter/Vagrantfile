#!/usr/bin/env ruby
# vi: set ft=ruby :
=begin
  The MIT License (MIT)

  Copyright (c) 2015 Adrian Günter <adrian@gntr.me>

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
=end
require 'ostruct'
require 'securerandom'
require 'yaml'
require 'optparse'
# — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — —
# Lib »»»
class Object
  # @return [Boolean]
  #
  # Returns self if self is boolean true or false,
  # otherwise the (optional) default is returned
  def filter_boolean_value(default = false)
    [true, false].include?(self) ? self : default
  end

  # https://gist.github.com/Integralist/9503099
  def deep_symbolize_keys
    return self.reduce({}) do |memo, (k, v)|
      memo.tap { |m| m[k.to_sym] = v.deep_symbolize_keys }
    end if self.is_a?(Hash)

    return self.reduce([]) do |memo, v|
      memo << v.deep_symbolize_keys; memo
    end if self.is_a?(Array)

    self
  end
end
# ««« Lib
# — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — —
# Vagrantfile »»»
VAGRANTFILE = Object.new
class << VAGRANTFILE
  API_VERSION      = '2'
  VAGRANT_VERSION  = '>= 1.7.0'
  PATH             = __FILE__
  DATA_PATH        = ENV['VFD_PATH'] ||= "#{__dir__}/Vagrantfile.d"
  REQUIRED_PLUGINS = %w(vagrant-triggers vagrant-guestip)

  @configHelper
  @config
  @instance_id
  attr_reader :configHelper, :config, :instance_id

  def do
    @instance_id = SecureRandom.hex(3)

    _load_config

    unless Object.const_defined?('Vagrant')
      # TODO command-line stuff here
      puts '—— CLI is not implemented (yet!), sorry! ——'
      #cli = CommandLineHelper.new
      exit
    end

    Vagrant.require_version(VAGRANT_VERSION)
    # TODO Merge in user definable (options.yaml?) plugins here?
    REQUIRED_PLUGINS.each do |plugin|
      abort("Missing plugin, please run: "\
          "vagrant plugin install #{plugin}") unless Vagrant.has_plugin?(plugin)
    end
    ENV['VAGRANT_DEFAULT_PROVIDER'] ||= 'docker'

    Vagrant.configure(API_VERSION) do |config|
      # Disable the default ´/current/directory  »  /vagrant´ synced folder
      config.vm.synced_folder(".", "/vagrant", id: "vagrant-root", disabled: true)

      # Box
      @config.ENV[:boxes].each do |bname, bcfg|
        config.vm.define(bname, primary: bcfg[:is_primary]) do |b|
          # TODO? Provisioners

          # Providers (first in config is default)
          bcfg[:providers].each do |pname, pcfg|
            b.vm.provider(pname) do |p|
              case pname
                when :docker
                  p.name            = pcfg[:name] ||= "#{bname}.#{@config.ENV[:name]}-#{@instance_id}"
                  p.image           = pcfg[:image]
                  p.build_dir       = pcfg[:build_dir]
                  p.build_args      = pcfg[:build_args] ||= []
                  p.create_args     = pcfg[:create_args] ||= []
                  p.remains_running = pcfg[:remains_running].filter_boolean_value(true)
                # TODO? passthrough remaining pairs, mapping p.[key] > value
                else
                  # TODO passthrough all pairs, mapping p.[key] > value, letting Vagrant manage error checking
                  raise "Unsupported provider #{pname} for box #{bname}"
              end

              # Overwrite the box_config hash with the
              # Vagrant provider's instance vars
              # TODO Create a separate hash for this
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

      # TODO Trigger after :halt, :destroy to automatically remove the DNS A records

      config.trigger.after [:up, :reload] do
        vfconfig  = VAGRANTFILE.config
        nsupdate  = vfconfig.LOCAL[:nsupdate]
        box       = vfconfig.ENV[:boxes][@machine.name]
        public_ip = @machine.provider.capability(:public_address)

        if nsupdate[:enabled] && public_ip
          cmds = "( echo 'server localhost';"; box[:nsupdate_domains].each do |domain|
            cmds << "echo 'update delete #{domain}. IN A'; "\
                "echo 'update add #{domain}. 3600 IN A #{public_ip}';"
          end; cmds << "echo 'send' ) | nsupdate -D -k '#{nsupdate[:keyfile_path]}' 2>&1"

          # TODO Error handling
          # https://github.com/emyl/vagrant-triggers/blob/master/lib/vagrant-triggers/dsl.rb
          # @logger...
          # error...
          puts `#{cmds}`.split(/\n+/).select { |l| l =~ /opcode: UPDATE|(IN|ANY)\s+(?!(SOA|NS))[A-Z]+|could not/ }
        end
      end
    end
  end

  def _load_config
    @configHelper = ConfigHelper.new(
        {
            :OPTIONS => "#{DATA_PATH}/config/options.yaml",
            :ENV     => "#{DATA_PATH}/config/env.yaml",
            :LOCAL   => "#{DATA_PATH}/config/local.yaml"
        }
    ).load

    @config = @configHelper.config

    @configHelper.expansion_map = {
        :pwd         => __dir__,
        :instance_id => @instance_id,
        :name        => @config.ENV[:name]
    }
    @configHelper.expand_vars
  end

  private :_load_config

  class ConfigHelper
    class Config < Object
      def has?(namespace)
        instance_variable_defined?('@'+_filter_ns(namespace))
      end

      def empty?
        instance_variables.empty?
      end

      def get(namespace = nil)
        if namespace
          return instance_variable_get('@'+_filter_ns(namespace))
        end
        instance_variables
      end

      def set(namespace, value)
        unless has?(namespace)
          self.class.class_eval { attr_reader namespace.to_sym }
        end
        instance_variable_set('@'+_filter_ns(namespace), value)
      end

      def _filter_ns(namespace)
        namespace.to_s.gsub(/[\W_]+/, '');
      end

      private :_filter_ns
    end

    def initialize(files, expansion_map: {})
      @files         = files
      @expansion_map = expansion_map
      @config        = Config.new
    end

    attr_accessor :files, :expansion_map
    attr_reader :config

    def get(namespace = nil, autoload: true)
      if namespace
        load(namespace) if autoload and !@config.has?(namespace)
        return @config.get(namespace)
      end
      load if autoload and @config.empty?
      @config
    end

    def load(namespace = nil, expand: true)
      if namespace
        # Parse file and expand variables
        @config.set(namespace, _load_file(@files[namespace]))
        expand_vars(namespace) if expand and not expansion_map.empty?
        return
      end
      @files.each_key { |key| load(key) }
      self
    end

    def expand_vars(namespace = nil)
      if namespace
        _expand(@config.get(namespace), expansion_map)
        return
      end
      @config.get.each { |var| expand_vars(var) }
    end

    def _expand(obj, expansions)
      case obj
        when String then
          obj.replace(obj % expansions)
        when OpenStruct then
          obj.instance_variables.each { |v| _expand(obj.instance_variable_get(v), expansions) }
        when Hash, Array then
          obj.each { |v| _expand(v, expansions) }
      end
      #puts "«#{obj.class}» #{obj.inspect}\n\n"
    end

    def _load_file(path)
      OpenStruct.new(YAML.load_file(path).deep_symbolize_keys)
    end

    private :_expand, :_load_file
  end

  class CommandLineHelper

  end
end
# ««« Vagrantfile
# — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — —
# Init »»»
VAGRANTFILE.do
# ««« Init
