module OsCtl::Cli
  class Group < Command
    include CGroupParams
    include Assets

    FIELDS = %i(
      pool
      name
      path
      full_path
    ) + CGroupParams::CGPARAM_STATS

    FILTERS = %i(
      pool
    )

    DEFAULT_FIELDS = %i(
      pool
      name
      path
      memory
      cpu_time
    )

    def list
      if opts[:list]
        puts FIELDS.join("\n")
        return
      end

      cmd_opts = {}
      fmt_opts = {layout: :columns}

      cmd_opts[:names] = args if args.count > 0

      FILTERS.each do |v|
        [gopts, opts].each do |options|
          next unless options[v]
          cmd_opts[v] = options[v].split(',')
        end
      end

      fmt_opts[:header] = false if opts['hide-header']
      cols = opts[:output] ? opts[:output].split(',').map(&:to_sym) : DEFAULT_FIELDS

      c = osctld_open
      groups = cg_add_stats(
        c,
        c.cmd_data!(:group_list, cmd_opts),
        lambda { |g| g[:full_path] },
        cols,
        gopts[:parsable]
      )
      c.close

      OutputFormatter.print(groups, cols, fmt_opts)
    end

    def show
      if opts[:list]
        puts FIELDS.join("\n")
        return
      end

      require_args!('name')

      cols = opts[:output] ? opts[:output].split(',').map(&:to_sym) : FIELDS

      c = osctld_open
      group = c.cmd_data!(:group_show, name: args[0], pool: gopts[:pool])
      cg_add_stats(
        c,
        group,
        group[:full_path],
        cols,
        gopts[:parsable]
      )
      c.close

      OutputFormatter.print(group, cols)
    end

    def create
      require_args!('name')

      cmd_opts = {
        name: args[0],
        pool: opts[:pool] || gopts[:pool],
        path: opts[:path],
        cgparams: parse_cgparams,
      }

      osctld_fmt(:group_create, cmd_opts)
    end

    def delete
      require_args!('name')
      osctld_fmt(:group_delete, name: args[0], pool: gopts[:pool])
    end

    def assets
      require_args!('name')
      print_assets(:group_assets, name: args[0], pool: gopts[:pool])
    end

    def cgparam_list
      require_args!('name')
      do_cgparam_list(:group_cgparam_list, name: args[0], pool: gopts[:pool])
    end

    def cgparam_set
      require_args!('name', 'parameter', 'value')
      do_cgparam_set(:group_cgparam_set, name: args[0], pool: gopts[:pool])
    end

    def cgparam_unset
      require_args!('name', 'parameter')
      do_cgparam_unset(:group_cgparam_unset, name: args[0], pool: gopts[:pool])
    end

    def cgparam_apply
      require_args!('name')
      do_cgparam_apply(:group_cgparam_apply, name: args[0], pool: gopts[:pool])
    end
  end
end
