{
  description = "Minimal NixOS ISO";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      exampleIso = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({ pkgs, modulesPath, ... }: {
            imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];
            environment.systemPackages = with pkgs; [
              vim
              git
            ];
            systemd.services.openssh.enable = true;
            systemd.services.sshd.wantedBy = [ "multi-user.target" ];
            users.users.root.openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINFAapmuD0l/rfYUK1fpfgDkrEPQQF2skVLRsmN6P/r6"
            ];
            networking.interfaces.eno1.useDHCP = false;
            networking.defaultGateway = "192.168.100.1";
            networking.nameservers = [ "1.1.1.1" "9.9.9.9" ];
            networking.interfaces.eno1.ipv4.addresses = [ {
              address = "192.168.100.199";
              prefixLength = 24;
            } ];
          })
        ];
      };
    };
  };
}