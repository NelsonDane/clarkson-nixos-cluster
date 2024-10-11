{ inputs, config, lib, pkgs, meta, ... }:

{
  imports =
    [
      inputs.sops-nix.nixosModules.sops
    ];

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    settings.trusted-users = [ "root" "@wheel" ];
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
  };
  nixpkgs.config.allowUnfree = true;

  # Stay up to date
  system.autoUpgrade.enable = false;
  systemd.timers."update-nixos" = {
    wantedBy = [ "timers.target" ];
    partOf = [ "update-nixos.service" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:30:00";
      Unit = "update-nixos.service";
    };
  };
  systemd.services."update-nixos" = {
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    path = with pkgs; [ nixos-rebuild ];
    script = ''
      nixos-rebuild switch --flake github:NelsonDane/clarkson-nixos-cluster#${meta.hostname}
    '';
  };

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    age.keyFile = "/var/lib/sops-nix/key.txt";
    age.generateKey = true;
    # Secrets
    secrets."rancher_token" = {};
    secrets."cluster_talk" = {};
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.initrd.systemd.enable = true;

  networking.hostName = meta.hostname;
  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # Fixes for longhorn
  systemd.tmpfiles.rules = [
    "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
  ];
  virtualisation.docker.logDriver = "json-file";

  services.k3s = {
    enable = true;
    role = "server";
    tokenFile = config.sops.secrets."rancher_token".path; 
    extraFlags = toString ([
	    "--write-kubeconfig-mode \"0644\""
	    "--cluster-init"
	    "--disable servicelb"
	    "--disable traefik"
	    "--disable local-storage"
      "--disable servicelb"
    ] ++ (if meta.hostname == "cluster-node-0" then [] else [
	      "--server https://cluster-node-0:6443"
    ]));
    clusterInit = (meta.hostname == "cluster-node-0");
  };
  services.openiscsi = {
    enable = true;
    name = "iqn.2016-04.com.open-iscsi:${meta.hostname}";
  };

  users.users.cluster = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    # Created using mkpasswd -m sha-512
    hashedPassword = "$6$zBd4jLFLxMSwywE/$zoEu2GfCM/z3qq4cdRGdHM84CpuGSSVMMqFwy2xv8r2jCmp6VtiDjry6ILaG5aObV.d/yD41zPWfwFBBaX2LB/";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINFAapmuD0l/rfYUK1fpfgDkrEPQQF2skVLRsmN6P/r6" # nixos_cluster
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFt/JQChYMGqIq1L7qLf/miHap0bMaEs/16b157Fq/Bv" # cluster_talk
    ];
  };
  security.sudo.extraRules = [{
      users = ["cluster"];
      commands = [{
        command = "ALL";
        options = ["NOPASSWD" "SETENV"];
      }];
  }];

  environment.systemPackages = with pkgs; [
    vim
    k3s
    openiscsi
    cifs-utils
    nfs-utils
    git
    helm
    helmfile
    (wrapHelm kubernetes-helm {
        plugins = with pkgs.kubernetes-helmPlugins; [
          helm-diff
        ];
      })
  ];
  environment = {
    variables = {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    };
    interactiveShellInit = ''
      alias c="clear"
      alias k="kubectl"
      alias h="helm"
      alias hf="helmfile"
    '';
  };
  # system.activationScripts.chmod = ''
  #   sudo chmod 644 /etc/rancher/k3s/k3s.yaml
  # '';

  # Enable ssh
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = "no";
  };
  security.pam = {
    sshAgentAuth.enable = true;
    services.sudo.sshAgentAuth = true;
  };
  programs.ssh.extraConfig = ''
    Host 192.168.100.1? 192.168.100.2? cluster-node-*
      user cluster
      IdentityFile /run/secrets/cluster_talk
  '';
  programs.nix-ld.enable = true;

  networking.firewall.enable = false;
  networking.hosts = builtins.listToAttrs (map (node: {
   name = node.ip;
   value = [ node.name ];
  }) meta.all_nodes);
  # # Set Static IP
  networking.interfaces.eno1.useDHCP = false;
  networking.defaultGateway = "192.168.100.1";
  networking.nameservers = [ "1.1.1.1" "9.9.9.9" ];
  networking.interfaces.eno1.ipv4.addresses = [{
    address = meta.ip_address;
    prefixLength = 24;
  }];

  system.stateVersion = "24.05";

}
