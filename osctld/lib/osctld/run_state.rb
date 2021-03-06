module OsCtld
  module RunState
    RUNDIR = '/run/osctl'
    POOL_DIR = File.join(RUNDIR, 'pools')
    USER_CONTROL_DIR = File.join(RUNDIR, 'user-control')
    MIGRATION_DIR = File.join(RUNDIR, 'migration')
    REPOSITORY_DIR = File.join(RUNDIR, 'repository')
    CONFIG_DIR = File.join(RUNDIR, 'configs')
    LXC_CONFIG_DIR = File.join(CONFIG_DIR, 'lxc')

    def self.create
      Dir.mkdir(RUNDIR, 0711) unless Dir.exists?(RUNDIR)
      Dir.mkdir(POOL_DIR, 0711) unless Dir.exists?(POOL_DIR)
      Dir.mkdir(USER_CONTROL_DIR, 0711) unless Dir.exists?(USER_CONTROL_DIR)

      unless Dir.exists?(MIGRATION_DIR)
        Dir.mkdir(MIGRATION_DIR, 0100)
        File.chown(Migration::UID, 0, MIGRATION_DIR)
      end

      # Bundler needs to have some place to store its temp files
      unless Dir.exists?(REPOSITORY_DIR)
        Dir.mkdir(REPOSITORY_DIR, 0700)
        File.chown(Repository::UID, 0, REPOSITORY_DIR)
      end

      # LXC configs
      Dir.mkdir(CONFIG_DIR, 0755) unless Dir.exists?(CONFIG_DIR)
      Dir.mkdir(LXC_CONFIG_DIR, 0755) unless Dir.exists?(LXC_CONFIG_DIR)

      Lxc.install_lxc_configs(LXC_CONFIG_DIR)
    end

    def self.assets(add)
      add.directory(
        RunState::RUNDIR,
        desc: 'Runtime configuration',
        user: 0,
        group: 0,
        mode: 0711
      )
      add.directory(
        RunState::POOL_DIR,
        desc: 'Runtime pool configuration',
        user: 0,
        group: 0,
        mode: 0711
      )
      add.directory(
        RunState::USER_CONTROL_DIR,
        desc: 'Runtime user configuration',
        user: 0,
        group: 0,
        mode: 0711
      )
      add.directory(
        RunState::MIGRATION_DIR,
        desc: 'Migration configuration',
        user: Migration::UID,
        group: 0,
        mode: 0100,
        optional: true
      )
      add.directory(
        RunState::REPOSITORY_DIR,
        desc: 'Home directory for the repository user',
        user: Repository::UID,
        group: 0,
        mode: 0700
      )
      add.directory(
        RunState::CONFIG_DIR,
        desc: 'Global LXC configuration files',
        user: 0,
        group: 0,
        mode: 0755
      )

      Migration.assets(add)
    end
  end
end
