# Clarkson ECE Lab Cluster

Built with NixOS and Kubernetes.


## Build NixOS ISO
When adding a new node, you need to create a bootable USB. To do that, you need to build an ISO file. If building with Apple Silicon Mac (or other non x86_64 architecture), see [this post](https://blog.nelsondane.me/posts/build-nixos-iso-on-silicon-mac/). Otherwise, follow the steps below.
```bash
cd iso
nix build .#nixosConfigurations.exampleIso.config.system.build.isoImage
```
Resulting ISO will be in the `result` directory. Then burn that ISO to a USB drive, then boot the new node from the USB drive.

## Secrets Management
Node secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix). 
On first boot, each node generates a key located at `/etc/ssh/ssh_host_ed25519_key.pub`. After the install, the key is converted to `age` and printed in the terminal. Copy this, and add it to the `.sops.yaml` file.

To create your own key for local development, generate an ssh key, and convert it to `age`:
```bash
nix-shell -p ssh-to-age --run 'cat /YOUR/KEY/PATH.pub | ssh-to-age'
```
Then add the output to the `.sops.yaml` file.

To create a `keys.txt` for local secrets management, run the following command:
```bash
nix run nixpkgs#ssh-to-age -- -private-key -i ~/YOUR/KEY/PATH > keys.txt
```
This is needed if you're updating the secrets locally.

To update the new keys across all nodes, run the following command:
```bash
nix-shell -p sops --run "SOPS_AGE_KEY_FILE=./keys.txt sops updatekeys secrets/secrets.yaml"
```
Then commit the changes to the `.sops.yaml` file and the nodes will be updated on their next rebuild.

## Adding a New Node
Make sure you have `nix` installed locally. Then:
1. Add the new node and its IP to the in `flake.nix`.
2. Boot the node from the ISO created in [Build NixOS ISO](#build-nixos-iso). Ensure that the node is reachable at `192.168.100.199`. If you get permission errors, you may have to add your key to the ISO config file.
3. Execute the following command on your local machine:
```bash
SSH_PRIVATE_KEY="$(cat ./nixos_cluster)"$'\n' nix run github:nix-community/nixos-anywhere --extra-experimental-features "nix-command flakes" -- --flake '.#cluster-node-NUMBER' root@192.168.100.199
```
4. Once the node boots, ssh into the node and run the following command:
```bash
nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
```
Copy the outputted `age` key to the `.sops.yaml` file and regenerate secrets (See [Secrets Management](#secrets-management)), then update the node.

## Updating the Cluster with New/Changed Configuration
If you have the repository cloned on a node (working on changes without committing), then run to update from local source:
```bash
sudo nixos-rebuild switch --flake '.#cluster-node-NUMBER'
```

Then to update each node in the cluster:
```bash
sudo nixos-rebuild switch --flake '.#cluster-node-NUMBER' --use-remote-sudo --target-host cluster@cluster-node-NUMBER
```
This will also update secrets on each node.

To pull new changes from the repository without cloning it onto the node, just run:
```bash
sudo nixos-rebuild switch --flake github:NelsonDane/clarkson-nixos-cluster#cluster-node-NUMBER
```

All nodes can ssh into each other using the included `ssh_config`. There is a key located in `.sops.yaml` that is available at `/run/secrets/cluster_talk`.

If you don't want to manually update each node, they pull and apply new changes from this repository every day at 3:30am.

## Updating NixOS, Packages, and Configuration
A [GitHub Action](https://github.com/NelsonDane/clarkson-nixos-cluster/actions) runs this everyday at 3am automatically.

## Aliases
For convenience, the following aliases are available when ssh'd into a node:
```bash
c -> clear
k -> kubectl
h -> helm
hf -> helmfile
```

## Kubernetes
For distributed storage, we use [Longhorn](https://longhorn.io/). To install Longhorn, run the following command:
```bash
cd helm
hf apply
```
To see the gui, go to `http://192.168.100.61` in your browser.

To get Metallb working (if it's not), run the following command:
```bash
cd helm/kustomize
kubectl apply -k .
```

To see IPs:
```bash
k get svc -A
```

## Slurm
Slurm is configured using the [Slurm Helm Chart](https://github.com/NelsonDane/slurm-k8s-cluster). To pull the submodules for Slurm, run the following command:
```bash
git submodule update --init --recursive
```

Then to install Slurm, run:
```bash
cd helm/slurm-k8s-cluster
h install slurm slurm-cluster-chart
```
And then to apply changes after initial install, run:
```bash
h upgrade slurm slurm-cluster-chart
```

The Slurm GUI is available at `https://192.168.100.82`

## Adding new Apps/Services
To add a new app or service, find a helm chart and add it to `helm/helmfile.yaml`. Then run:
```bash
cd helm
hf apply
```
And it will be installed on the cluster.
