{ pkgs, config, lib, ... }:

with lib;

####################
#                  #
#    Interface     #
#                  #
####################

{
  options = {
    system.build = mkOption {
      internal = true;
      default = {};
      description = "Attribute set of derivations used to setup the system.";
    };
    system.qemuParams = mkOption {
      internal = true;
      type = types.listOf types.str;
      description = "QEMU parameters";
    };
    system.qemuRAM = mkOption {
      internal = true;
      default = 2048;
      type = types.addCheck types.int (n: n > 256);
      description = "QEMU RAM in megabytes";
    };
    system.qemuCpus = mkOption {
      internal = true;
      default = 1;
      type = types.addCheck types.int (n: n >= 1);
      description = "Number of available CPUs";
    };
    system.qemuCpuCores = mkOption {
      internal = true;
      default = 1;
      type = types.addCheck types.int (n: n >= 1);
      description = "Number of available CPU cores";
    };
    system.qemuCpuThreads = mkOption {
      internal = true;
      default = 1;
      type = types.addCheck types.int (n: n >= 1);
      description = "Number of available threads";
    };
    system.qemuCpuSockets = mkOption {
      internal = true;
      default = 1;
      type = types.addCheck types.int (n: n >= 1);
      description = "Number of available CPU sockets";
    };
    system.qemuDiskSize = mkOption {
      default = 1;
      type = types.addCheck types.int (n: n >= 1);
      description = ''
        Size of zpool vdev in GB. Two vdevs are created and put into mirror.
      '';
    };
    boot.isContainer = mkOption {
      type = types.bool;
      default = false;
    };
    boot.predefinedFailAction = mkOption {
      type = types.enum ["" "n" "i" "r" "*" ];
      default = "";
      description = ''
        Action to take automatically if stage-1 fails.

        n - create new pool (may also erase disks and run partitioning if configured)
        i - interactive shell
        r - reboot
        * - ignore

        Useful for unattended installations and testing.
      '';
    };
    boot.initrd.withHwSupport = mkOption {
      type = types.bool;
      default = true;
      description = "Include hardware support kernel modules in initrd (so e.g. zfs sees disks)";
    };
    boot.loader.timeout = mkOption {
      type = types.ints.positive;
      default = 10;
      description = "syslinux timeout in seconds (ISO only)";
    };
    hardware.firmware = mkOption {
      type = types.listOf types.package;
      default = [];
      apply = list: pkgs.buildEnv {
        name = "firmware";
        paths = list;
        pathsToLink = [ "/lib/firmware" ];
        ignoreCollisions = true;
      };
    };
    vpsadminos.nix = mkOption {
      type = types.bool;
      description = "enable nix-daemon and a writeable store";
    };
    networking.hostName = mkOption {
      type = types.string;
      description = "machine hostname";
      default = "default";
    };
    networking.preConfig = mkOption {
      type = types.lines;
      description = "Set of commands run prior to any other network configuration";
      default = "";
    };
    networking.custom = mkOption {
      type = types.lines;
      description = "Custom set of commands used to set-up networking";
      default = "";
      example = "
        ip addr add 10.0.0.1 dev ix0
        ip link set ix0 up
      ";
    };
    networking.static.enable = mkOption {
      type = types.bool;
      description = "use static networking configuration";
      default = false;
    };
    networking.static.interface = mkOption {
      type = types.string;
      description = "interface for static networking configuration";
      default = "eth0";
    };
    networking.static.ip = mkOption {
      type = types.string;
      description = "IP address for static networking configuration";
      default = "10.0.2.15";
    };
    networking.static.route = mkOption {
      type = types.string;
      description = "route";
      default = "10.0.2.0/24";
    };
    networking.static.gw = mkOption {
      type = types.string;
      description = "gateway IP address for static networking configuration";
      default = "10.0.2.2";
    };
    networking.chronyd = mkOption {
      type = types.bool;
      description = "use Chrony daemon for network time synchronization";
      default = true;
    };
    networking.timeServers = mkOption {
      default = [
        "0.nixos.pool.ntp.org"
        "1.nixos.pool.ntp.org"
        "2.nixos.pool.ntp.org"
        "3.nixos.pool.ntp.org"
      ];
      description = ''
        The set of NTP servers from which to synchronise.
      '';
    };
    networking.dhcp = mkOption {
      type = types.bool;
      description = "use DHCP to obtain IP";
      default = false;
    };
    networking.dhcpd = mkOption {
      type = types.bool;
      description = "enable dhcpd to provide DHCP for guests";
      default = false;
    };
    networking.openDNS = mkOption {
      type = types.bool;
      description = "use OpenDNS servers";
      default = true;
    };
    networking.lxcbr = mkOption {
      type = types.bool;
      description = "create lxc bridge interface";
      default = false;
    };
    networking.nat = mkOption {
      type = types.bool;
      description = "enable NAT for containers";
      default = true;
    };
    boot.kernelPackage = mkOption {
      type = types.package;
      description = "base linux kernel package";
      default = pkgs.linux_4_14;
      example = pkgs.linux_4_16;
    };
  };

####################
#                  #
#  Implementation  #
#                  #
####################

  config =
  let
    origKernel = config.boot.kernelPackage;
    myKernel = origKernel.override {
      extraConfig = ''
        EXPERT y
        CHECKPOINT_RESTORE y
        CFS_BANDWIDTH y
      '';
    };

    # we also need to override zfs/spl via linuxPackagesFor
    myLinuxPackages = (pkgs.linuxPackagesFor myKernel).extend (
      self: super: {
        zfs = super.zfsUnstable.overrideAttrs (oldAttrs: rec {
          name = pkgs.zfs.name;
          version = pkgs.zfs.version;
          src = pkgs.zfs.src;
          spl = self.spl;
        });

        spl = super.splUnstable;
      });

    hwSupportModules = [

      # SATA/PATA/NVME
      "ahci"
      "sata_nv"
      "sata_via"
      "sata_uli"
      "nvme"
      "isci"

      # Support USB keyboards, in case the boot fails and we only have
      # a USB keyboard, or for LUKS passphrase prompt.
      "uhci_hcd"
      "ehci_hcd"
      "ehci_pci"
      "ohci_hcd"
      "ohci_pci"
      "xhci_hcd"
      "xhci_pci"
      "usbhid"
      "hid_generic" "hid_lenovo" "hid_apple" "hid_roccat"
      "hid_logitech_hidpp" "hid_logitech_dj"

      # PS2
      "pcips2" "atkbd" "i8042"
    ];

    cfg = config.system;

  in

  (lib.mkMerge [{
    environment.shellAliases = {
      ll = "ls -l";
      vim = "vi";
    };
    environment.systemPackages = lib.optional config.vpsadminos.nix pkgs.nix;
    nixpkgs.config = {
      packageOverrides = self: rec {
      };
    };
    i18n = {
      defaultLocale = "en_US.UTF-8";
      supportedLocales = [ "en_US.UTF-8/UTF-8" ];
    };
    environment.etc = {
      "nix/nix.conf".source = pkgs.runCommand "nix.conf" {} ''
        extraPaths=$(for i in $(cat ${pkgs.writeReferencesToFile pkgs.stdenv.shell}); do if test -d $i; then echo $i; fi; done)
        cat > $out << EOF
        build-use-sandbox = true
        build-users-group = nixbld
        build-sandbox-paths = /bin/sh=${pkgs.stdenv.shell} $(echo $extraPaths)
        build-max-jobs = 1
        build-cores = 4
        EOF
      '';
      bashrc.text = "export PATH=/run/current-system/sw/bin";
      profile.text = "export PATH=/run/current-system/sw/bin";
      "resolv.conf".text = lib.mkDefault "nameserver 10.0.2.3";
      "nsswitch.conf".text = ''
        hosts:     files  dns   myhostname mymachines
        networks:  files dns
      '';
      # XXX: generate these on start
      "ssh/ssh_host_rsa_key.pub".source = ./ssh/ssh_host_rsa_key.pub;
      "ssh/ssh_host_rsa_key" = { mode = "0600"; source = ./ssh/ssh_host_rsa_key; };
      "ssh/ssh_host_ed25519_key.pub".source = ./ssh/ssh_host_ed25519_key.pub;
      "ssh/ssh_host_ed25519_key" = { mode = "0600"; source = ./ssh/ssh_host_ed25519_key; };
      "cgconfig.conf".text = ''
        mount {
          cpuset = /sys/fs/cgroup/cpuset;
          cpu = /sys/fs/cgroup/cpu,cpuacct;
          cpuacct = /sys/fs/cgroup/cpu,cpuacct;
          blkio = /sys/fs/cgroup/blkio;
          memory = /sys/fs/cgroup/memory;
          devices = /sys/fs/cgroup/devices;
          freezer = /sys/fs/cgroup/freezer;
          net_cls = /sys/fs/cgroup/net_cls,net_prio;
          net_prio = /sys/fs/cgroup/net_cls,net_prio;
          pids = /sys/fs/cgroup/pids;
          "name=systemd" = /sys/fs/cgroup/systemd;
        }
        group . {
          memory {
            memory.use_hierarchy = 1;
          }
        }
      '';
      "lxc/common.conf.d/00-lxcfs.conf".source = "${pkgs.lxcfs}/share/lxc/config/common.conf.d/00-lxcfs.conf";
      # needed for osctl to access distro specific configs
      "lxc/config".source = "${pkgs.lxc}/share/lxc/config";

       # /etc/services: TCP/UDP port assignments.
      "services".source = pkgs.iana-etc + "/etc/services";
      # /etc/protocols: IP protocol numbers.
      "protocols".source  = pkgs.iana-etc + "/etc/protocols";
      # /etc/rpc: RPC program numbers.
      "rpc".source = pkgs.glibc.out + "/etc/rpc";
    };

    boot.kernelParams = [
      "systemConfig=${config.system.build.toplevel}"
      "net.ifnames=0"
    ];

    boot.kernelPackages = myLinuxPackages;
    boot.kernelModules = hwSupportModules ++ [
      "fuse"
      "veth"
    ] ++ lib.optionals config.networking.nat [
      "ip_tables"
      "iptable_nat"
      "ip6_tables"
      "ip6table_nat"
    ];

    boot.initrd.kernelModules = lib.optionals config.boot.initrd.withHwSupport hwSupportModules;

    boot.kernel.sysctl."kernel.dmesg_restrict" = true;

    security.apparmor.enable = true;

    virtualisation = {
      lxc = {
        enable = true;
        usernetConfig = lib.optionalString config.networking.lxcbr ''
          root veth lxcbr0 10
        '';
        lxcfs.enable = true;
      };
    };

    system.build.earlyMountScript = pkgs.writeScript "dummy" ''
    '';

    system.qemuParams = lib.mkDefault [
      "-drive index=0,id=drive1,file=${config.system.build.squashfs},readonly,media=cdrom,format=raw,if=virtio"
      "-kernel ${config.system.build.kernel}/bzImage -initrd ${config.system.build.initialRamdisk}/initrd"
      ''-append "console=ttyS0 ${toString config.boot.kernelParams} quiet panic=-1"''
      "-nographic"
    ];

    system.build.runvm = pkgs.writeScript "runner" ''
      #!${pkgs.stdenv.shell}
      truncate -s${toString cfg.qemuDiskSize}G sda.img
      truncate -s${toString cfg.qemuDiskSize}G sdb.img
      exec ${pkgs.qemu_kvm}/bin/qemu-kvm -name vpsadminos -m ${toString cfg.qemuRAM} \
        -smp cpus=${toString cfg.qemuCpus},cores=${toString cfg.qemuCpuCores},threads=${toString cfg.qemuCpuThreads},sockets=${toString cfg.qemuCpuSockets} \
        -no-reboot \
        -device ahci,id=ahci \
        -drive id=diskA,file=sda.img,if=none \
        -drive id=diskB,file=sdb.img,if=none \
        -device ide-drive,drive=diskA,bus=ahci.0 \
        -device ide-drive,drive=diskB,bus=ahci.1 \
        -device virtio-net,netdev=net0 \
        -netdev user,id=net0,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,hostfwd=tcp::2222-:22 \
        ${lib.concatStringsSep " \\\n  " cfg.qemuParams}
    '';

    system.build.dist = pkgs.runCommand "vpsadminos-dist" {} ''
      mkdir $out
      cp ${config.system.build.squashfs} $out/root.squashfs
      cp ${config.system.build.kernel}/*zImage $out/kernel
      cp ${config.system.build.initialRamdisk}/initrd $out/initrd
      echo "${builtins.unsafeDiscardStringContext (toString config.boot.kernelParams)}" > $out/command-line
    '';

    system.build.toplevel = let
      name = let hn = config.networking.hostName;
                 nn = if (hn != "") then hn else "unnamed";
             in "vpsadminos-system-${nn}-${config.system.osLabel}";
      in
        pkgs.runCommand name {
          activationScript = config.system.activationScripts.script;
        } ''
          mkdir $out
          cp ${config.system.build.bootStage2} $out/init
          substituteInPlace $out/init --subst-var-by systemConfig $out
          ln -s ${config.system.path} $out/sw
          ln -s ${config.system.modulesTree} $out/kernel-modules
          echo "$activationScript" > $out/activate
          substituteInPlace $out/activate --subst-var out
          chmod u+x $out/activate
          unset activationScript
        '';

    system.build.squashfs = pkgs.callPackage <nixpkgs/nixos/lib/make-squashfs.nix> {
      storeContents = [ config.system.build.toplevel ];
    };

    system.build.kernelParams = config.boot.kernelParams;
  }

  (mkIf (config.networking.openDNS) {
    environment.etc."resolv.conf.tail".text = ''
    nameserver 208.67.222.222
    nameserver 208.67.220.220
    '';
  })

  (mkIf (config.networking.dhcpd) {
    environment.etc."dhcpd/dhcpd4.conf".text = ''
    authoritative;
    option routers 192.168.1.1;
    option domain-name-servers 208.67.222.222, 208.67.220.220;
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.168.1.255;
    subnet 192.168.1.0 netmask 255.255.255.0 {
      range 192.168.1.100 192.168.1.200;
    }
    '';
  })

  (mkIf (config.networking.chronyd) {
    environment.systemPackages = [ pkgs.chrony ];
    users.extraGroups = singleton
      { name = "chrony";
        gid = config.ids.gids.chrony;
      };

    users.extraUsers = singleton
      { name = "chrony";
        uid = config.ids.uids.chrony;
        group = "chrony";
        description = "chrony daemon user";
        home = "/var/lib/chrony";
      };
  })
  ]);
}
