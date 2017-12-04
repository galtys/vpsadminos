require 'yaml'

module OsCtld
  class Container
    include Lockable
    include Utils::Log
    include Utils::System
    include Utils::Zfs
    include Utils::SwitchUser

    attr_reader :id, :user, :distribution, :version
    attr_accessor :veth

    def initialize(id, user_name, load: true)
      init_lock

      @id = id
      @user = UserList.find(user_name) || (raise "user not found")

      load_config if load
    end

    def configure(distribution, version)
      @distribution = distribution
      @version = version
      @ips = {4 => [], 6 => []}

      File.open(config_path, 'w', 0400) do |f|
        f.write(YAML.dump({
          'distribution' => distribution,
          'version' => version,
        }))
      end

      File.chown(0, 0, config_path)
    end

    def state
      inclusively do
        ret = ct_control(user, :ct_status, ids: [id])

        if ret[:status]
          ret[:output][id.to_sym][:state].to_sym

        else
          :unknown
        end
      end
    end

    def dataset
      ct_ds(@user.name, @id)
    end

    def ctdir
      ct_dir(@user.name, @id)
    end

    def rootfs
      File.join(ctdir, 'private')
    end

    def config_path
      File.join(ctdir, 'ct.yml')
    end

    def lxc_config_path(cfg = 'config')
      File.join(ctdir, cfg.to_s)
    end

    def uid_offset
      @user.offset
    end

    def gid_offset
      @user.offset
    end

    def uid_size
      @user.size
    end

    def gid_size
      @user.size
    end

    def hostname
      "ct-#{@id}"
    end

    def ip_addresses(v)
      @ips[v].clone
    end

    protected
    def load_config
      cfg = YAML.load_file(config_path)

      @distribution = cfg['distribution']
      @version = cfg['version']
      @ips = cfg['ip_addresses'] || {4 => [], 6 => []}
    end
  end
end