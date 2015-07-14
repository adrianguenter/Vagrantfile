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
  def filter_boolean_value(default=false)
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

  @config
  @instance_id
  attr_reader :config, :instance_id

  def do
    _load_config

    unless Object.const_defined?('Vagrant')
      # TODO command-line stuff here
      puts '—— CLI is not implemented (yet!), sorry! ——'
      #cli = CommandLineHelper.new
      exit
    end

    @instance_id = "#{@config.ENV[:name]}-#{SecureRandom.hex(3)}"

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
    @config = ConfigHelper.new(
        {
            :OPTIONS => "#{DATA_PATH}/config/options.yaml",
            :ENV     => "#{DATA_PATH}/config/env.yaml",
            :LOCAL   => "#{DATA_PATH}/config/local.yaml"
        }
    ).load
  end

  private :_load_config

  class ConfigHelper
    class Config < Object
    end

    def initialize(files)
      @files  = files
      @config = Config.new
    end

    attr_accessor :files

    def get(namespace = nil, autoload: true)
      if namespace
        load(namespace) if autoload and !defined? @config[namespace]
        return @config[namespace]
      end
      load if autoload and @config.instance_variables.empty?
      @config
    end

    def load(namespace = nil)
      if namespace
        unless @config.instance_variable_defined?("@#{namespace}")
          @config.class.class_eval { attr_reader namespace.to_sym }
        end
        file_data = _load_file(@files[namespace])
        @config.instance_variable_set("@#{namespace}", file_data)
        return file_data
      end

      @files.each_key { |key| load(key) }
      @config
    end

    def _load_file(path)
      OpenStruct.new(YAML.load_file(path).deep_symbolize_keys)
    end

    private :_load_file
  end

  class CommandLineHelper

  end
end
# ««« Vagrantfile
# — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — — —
# Init »»»
VAGRANTFILE.do
# ««« Init
