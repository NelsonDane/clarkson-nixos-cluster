{
  description = "Cluster NixOS Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, ... }@inputs: let
    # Define cluster nodes/IPs
    nodes = [
      { name = "cluster-node-0"; ip = "192.168.100.10"; }
      { name = "cluster-node-1"; ip = "192.168.100.11"; }
      { name = "cluster-node-2"; ip = "192.168.100.12"; }
      { name = "cluster-node-3"; ip = "192.168.100.13"; }
      { name = "cluster-node-4"; ip = "192.168.100.14"; }
      { name = "cluster-node-5"; ip = "192.168.100.15"; }
      { name = "cluster-node-6"; ip = "192.168.100.16"; }
      { name = "cluster-node-7"; ip = "192.168.100.17"; }
      { name = "cluster-node-8"; ip = "192.168.100.18"; }
      { name = "cluster-node-9"; ip = "192.168.100.19"; }
      { name = "cluster-node-10"; ip = "192.168.100.20"; }
      { name = "cluster-node-11"; ip = "192.168.100.21"; }
    ];
  in {
    nixosConfigurations = builtins.listToAttrs (map (node: {
      name = node.name;
	    value = nixpkgs.lib.nixosSystem {
     	    specialArgs = {
            inherit inputs;
            meta = {
              hostname = node.name;
              ip_address = node.ip;
              all_nodes = nodes;
            };
          };
          system = "x86_64-linux";
          modules = [
              # Modules
	            disko.nixosModules.disko
	            ./hardware-configuration.nix
	            ./disko-config.nix
	            ./configuration.nix
	          ];
        };
    }) nodes);
  };
}
