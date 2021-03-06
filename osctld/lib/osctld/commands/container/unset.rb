require 'osctld/commands/logged'

module OsCtld
  class Commands::Container::Unset < Commands::Logged
    handle :ct_unset

    def find
      ct = DB::Containers.find(opts[:id], opts[:pool])
      ct || error!('container not found')
    end

    def execute(ct)
      ct.exclusively do
        changes = {}

        %i(autostart hostname dns_resolvers nesting seccomp_profile
           apparmor_profile).each do |attr|
          changes[attr] = opts[attr] if opts.has_key?(attr)
        end

        ct.unset(changes)
        ok
      end
    end
  end
end
