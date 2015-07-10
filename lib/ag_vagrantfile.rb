class AGVagrantfile
  @@cfg = {
      :env => YAML.load_file(ENV_CONF_PATH = ".vagrant.conf.d/env.conf.yaml"),
      :local => YAML.load_file(LOCAL_CONF_PATH = ".vagrant.conf.d/local.conf.yaml")
  }

  def AGVagrantfile.cfg
    return @@cfg
  end
end