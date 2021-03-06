require 'etc'
require 'yaml'
require 'osctld/lockable'
require 'osctld/assets/definition'

module OsCtld
  class Repository
    include Lockable
    include Assets::Definition

    USER = 'repository'
    UID = Etc.getpwnam(USER).uid

    attr_reader :pool, :name, :url

    def initialize(pool, name, load: true)
      init_lock
      @pool = pool
      @name = name
      @enabled = true
      load_config if load
    end

    def id
      name
    end

    def configure(url)
      @url = url
      save_config
    end

    def assets
      define_assets do |add|
        add.directory(
          cache_path,
          desc: 'Local cache',
          user: UID,
          group: 0,
          mode: 0700
        )
      end
    end

    def enabled?
      @enabled
    end

    def disabled?
      !enabled?
    end

    def enable
      @enabled = true
      save_config
    end

    def disable
      @enabled = false
      save_config
    end

    def templates
      # TODO
    end

    def config_path
      File.join(pool.conf_path, 'repository', "#{name}.yml")
    end

    def cache_path
      File.join(pool.repo_path, name)
    end

    protected
    attr_reader :state

    def load_config
      cfg = YAML.load_file(config_path)

      @url = cfg['url']
      @enabled = cfg['enabled']
    end

    def save_config
      File.open(config_path, 'w', 0400) do |f|
        f.write(YAML.dump({
          'url' => url,
          'enabled' => enabled?,
        }))
      end

      File.chown(0, 0, config_path)
    end
  end
end
