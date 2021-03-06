require 'osctld/commands/logged'
require 'fileutils'

module OsCtld
  class Commands::Container::Chown < Commands::Logged
    handle :ct_chown

    include OsCtl::Lib::Utils::Log
    include OsCtl::Lib::Utils::System

    def find
      ct = DB::Containers.find(opts[:id], opts[:pool])
      ct || error!('container not found')
    end

    def execute(ct)
      user = DB::Users.find(opts[:user], ct.pool)
      error!('user not found') unless user

      error!("already owned by #{user.name}") if ct.user == user

      error!('container has to be stopped first') if ct.state != :stopped
      Monitor::Master.demonitor(ct)

      old_user = ct.user

      user.inclusively do
        ct.exclusively do
          # Double check state while having exclusive lock
          error!('container has to be stopped first') if ct.state != :stopped

          progress('Moving LXC configuration')

          # Ensure LXC home
          unless ct.group.setup_for?(user)
            dir = ct.group.userdir(user)

            FileUtils.mkdir_p(dir, mode: 0751)
            File.chown(0, user.ugid, dir)
          end

          # Move CT dir
          syscmd("mv #{ct.lxc_dir} #{ct.lxc_dir(user: user)}")
          File.chown(0, user.ugid, ct.lxc_dir(user: user))

          # Chown assets
          File.chown(0, user.ugid, ct.log_path) if File.exist?(ct.log_path)

          if Dir.exist?(ct.devices_dir)
            File.chown(
              user.uid_map.ns_to_host(0),
              user.gid_map.ns_to_host(0),
              ct.devices_dir
            )
          end

          # Switch user, regenerate configs
          ct.chown(user)

          # Configure datasets
          datasets = ct.datasets

          datasets.reverse_each do |ds|
            progress("Unmounting dataset #{ds.relative_name}")
            zfs(:unmount, nil, ds)
          end

          datasets.each do |ds|
            progress("Setting UID/GID mapping of #{ds.relative_name}")
            zfs(
              :set,
              "uidmap=\"#{ct.uid_map.map(&:to_s).join(',')}\" "+
              "gidmap=\"#{ct.gid_map.map(&:to_s).join(',')}\"",
              ds
            )

            progress("Remounting dataset #{ds.relative_name}")
            zfs(:mount, nil, ds)
          end

          # Restart monitor
          Monitor::Master.monitor(ct)

          # Clear old LXC home if possible
          unless ct.group.has_containers?(old_user)
            progress('Cleaning up original LXC home')
            Dir.rmdir(ct.group.userdir(old_user))
          end
        end
      end

      call_cmd(Commands::User::LxcUsernet)
      ok
    end
  end
end
