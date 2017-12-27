module OsCtld
  class Commands::Group::Create < Commands::Base
    handle :group_create

    include Utils::Log
    include Utils::System

    def execute
      grp = Group.new(opts[:name], load: false)
      return error('group already exists') if GroupList.contains?(grp.name)

      grp.exclusively do
        grp.configure(opts[:path])
        GroupList.add(grp)
      end

      ok
    end
  end
end
