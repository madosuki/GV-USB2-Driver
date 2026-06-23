GV-USB2 Linux Driver
====================

A linux driver for the IO-DATA GV-USB2 SD capture device.

NixOS
-----

This repository includes a Nix flake for building the out-of-tree kernel
modules and for entering a development shell with the right kernel build
dependencies.

### Development builds

Enter the default development shell and build the modules:

```sh
nix develop
gvusb2-build
```

The helper runs the kernel build system with `M=$PWD` and writes
`gvusb2-sound.ko` and `gvusb2-video.ko` into the working tree. To clean the
tree:

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
modinfo -F vermagic ./gvusb2-video.ko
uname -r
```

If they match, the modules can be inserted manually for a quick test:

```sh
sudo insmod ./gvusb2-sound.ko
sudo insmod ./gvusb2-video.ko
```

Remove them with:

```sh
sudo rmmod gvusb2_video
sudo rmmod gvusb2_sound
```

### Using the driver on NixOS

For regular use, build the modules as part of the NixOS system closure instead
of manually inserting `.ko` files. The important detail is that the selected
flake package must be built for the same kernel package set used by the system.

With a flake-based NixOS configuration:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.gvusb2.url = "github:your-name/GV-USB2-Driver";
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
            "gvusb2-sound"
            "gvusb2-video"
          ];
        })
      ];
    };
  };
}
```

Use `gvusb2.packages.${pkgs.system}.stable` with `pkgs.linuxPackages`, or
`gvusb2.packages.${pkgs.system}.testing` with `pkgs.linuxPackages_testing`.
After rebuilding and booting the new system, plug in the GV-USB2 and check that
the modules loaded:

```sh
sudo nixos-rebuild switch --flake .#host
lsmod | grep gvusb2
```
