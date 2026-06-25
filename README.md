GV-USB2 Linux Driver
====================

A linux driver for the IO-DATA GV-USB2 SD capture device.

This repository is based on
[Isaac-Lozano/GV-USB2-Driver](https://github.com/Isaac-Lozano/GV-USB2-Driver).
The current tree carries local changes for the single-module `gvusb2.ko`
layout used by this fork.

NixOS
-----

This repository includes a Nix flake for building the out-of-tree kernel
module and for entering a development shell with the right kernel build
dependencies.

### Development builds

Enter the default development shell and build the module:

```sh
nix develop
gvusb2-build
```

The helper runs the kernel build system with `M=$PWD` and writes `gvusb2.ko`
into the working tree. To clean the tree:

```sh
gvusb2-build clean
```

The flake provides shells and packages for several nixpkgs kernel package sets:

```sh
nix develop .#stable
nix develop .#latest
nix develop .#testing

nix build .#stable
nix build .#latest
nix build .#testing
```

The default shell and package currently use `latest`.

For local manual testing, the module `vermagic` must match the running kernel:

```sh
modinfo -F vermagic ./gvusb2.ko
uname -r
```

If they match, the module can be inserted manually for a quick test:

```sh
sudo insmod ./gvusb2.ko
```

Remove it with:

```sh
sudo rmmod gvusb2
```

### Using the driver on NixOS

For regular use, add the module package to the NixOS system closure. The
package must be built against the same kernel package set used by the running
system. This driver now builds one kernel module, `gvusb2.ko`, which registers
one USB driver for both the video and audio interfaces.

The module declares `softdep: pre: usbtv`, so loading `gvusb2` through
`modprobe` should load the in-tree `usbtv` module first.

With a flake-based NixOS configuration:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.gvusb2.url = "github:YOUR_GITHUB_USER/GV-USB2-Driver";
  inputs.gvusb2.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, gvusb2, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          boot.kernelPackages = pkgs.linuxPackages_latest;

          boot.extraModulePackages = [
            gvusb2.packages.${pkgs.system}.latest
          ];

          boot.kernelModules = [
            "gvusb2"
          ];
        })
      ];
    };
  };
}
```

Use `gvusb2.packages.${pkgs.system}.stable` with `pkgs.linuxPackages`, or
`gvusb2.packages.${pkgs.system}.testing` with `pkgs.linuxPackages_testing`.
`boot.extraModulePackages` installs the out-of-tree module into the kernel
module tree. `boot.kernelModules = [ "gvusb2" ];` asks NixOS to load it with
`modprobe` during boot.

After rebuilding and booting the new system, plug in the GV-USB2 and check the
loaded modules:

```sh
sudo nixos-rebuild switch --flake .#host
lsmod | grep -E 'usbtv|gvusb2'
```

With a non-flake NixOS configuration, define the kernel module package in your
configuration and add it to `boot.extraModulePackages`. Use
`config.boot.kernelPackages` so the module is built against the same kernel
that the system boots:

```nix
{ config, pkgs, lib, ... }:

let
  gvusb2Driver = pkgs.stdenv.mkDerivation {
    pname = "gvusb2-driver";
    version = "unstable";

    src = pkgs.fetchFromGitHub {
      owner = "YOUR_GITHUB_USER";
      repo = "GV-USB2-Driver";
      rev = "COMMIT_OR_TAG";
      hash = lib.fakeHash;
    };

    nativeBuildInputs = config.boot.kernelPackages.kernel.moduleBuildDependencies;
    hardeningDisable = [ "pic" ];

    buildPhase =
      let
        kernel = config.boot.kernelPackages.kernel;
        kbuildDir = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
      in
      ''
        runHook preBuild
        make -C ${kbuildDir} M=$PWD modules
        runHook postBuild
      '';

    installPhase =
      let
        kernel = config.boot.kernelPackages.kernel;
      in
      ''
        runHook preInstall
        install -D -m 0644 gvusb2.ko \
          $out/lib/modules/${kernel.modDirVersion}/extra/gvusb2.ko
        runHook postInstall
      '';
  };
in
{
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.extraModulePackages = [
    gvusb2Driver
  ];

  boot.kernelModules = [
    "gvusb2"
  ];
}
```

Replace `COMMIT_OR_TAG` with the revision to pin. If you do not know the hash
yet, put `lib.fakeHash` in `hash`, run `sudo nixos-rebuild switch`, and replace
it with the hash reported by Nix.
