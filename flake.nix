{
  description = "GV-USB2 out-of-tree Linux kernel module development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;

      sourceFilter =
        path: type:
        let
          base = baseNameOf path;
        in
        (type == "directory" && base != ".git" && base != "result")
        || lib.hasSuffix ".c" base
        || lib.hasSuffix ".h" base
        || base == "Makefile"
        || base == "README.md"
        || lib.hasPrefix "LICENSE" base;

      mkModule =
        pkgs: kernelPackages:
        let
          kernel = kernelPackages.kernel;
          kbuildDir = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
        in
        pkgs.stdenv.mkDerivation {
          pname = "gvusb2-driver";
          version = "unstable-${self.shortRev or "dirty"}";

          src = lib.cleanSourceWith {
            src = ./.;
            filter = sourceFilter;
          };

          nativeBuildInputs = kernel.moduleBuildDependencies;
          hardeningDisable = [ "pic" ];

          buildPhase = ''
            runHook preBuild
            make -C ${kbuildDir} M=$PWD modules
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            install -D -m 0644 gvusb2.ko \
              $out/lib/modules/${kernel.modDirVersion}/extra/gvusb2.ko
            runHook postInstall
          '';

          passthru = {
            inherit kernel kernelPackages kbuildDir;
          };

          meta = {
            description = "IO-DATA GV-USB2 capture device Linux kernel module";
            license = with lib.licenses; [
              gpl2Only
              bsd3
            ];
            platforms = lib.platforms.linux;
          };
        };

      mkDevShell =
        pkgs: kernelPackages:
        let
          kernel = kernelPackages.kernel;
          kbuildDir = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
          buildHelper = pkgs.writeShellScriptBin "gvusb2-build" ''
            set -euo pipefail

            target=''${1:-modules}
            if [ "$#" -gt 0 ]; then
              shift
            fi

            exec make -C "$KDIR" M="$PWD" "$target" "$@"
          '';
        in
        pkgs.mkShell {
          packages = kernel.moduleBuildDependencies ++ [
            buildHelper
            pkgs.git
            pkgs.gnumake
          ];

          KDIR = kbuildDir;
          KERNEL_DIR = kbuildDir;
          KERNEL_MODDIR_VERSION = kernel.modDirVersion;

          shellHook = ''
            echo "GV-USB2 kernel module development shell"
            echo "kernel: ${kernel.version} (${kernel.modDirVersion})"
            echo "build:  gvusb2-build"
            echo "clean:  gvusb2-build clean"
          '';
        };
      perSystem =
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          kernelSets = {
            stable = pkgs.linuxPackages;
            latest = pkgs.linuxPackages_latest;
            testing = pkgs.linuxPackages_testing or pkgs.linuxPackages_latest;
          };
        in
        {
          inherit pkgs kernelSets;
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          inherit (perSystem system) pkgs kernelSets;
        in
        {
          default = self.packages.${system}.latest;
          stable = mkModule pkgs kernelSets.stable;
          latest = mkModule pkgs kernelSets.latest;
          testing = mkModule pkgs kernelSets.testing;
        }
      );

      devShells = forAllSystems (
        system:
        let
          inherit (perSystem system) pkgs kernelSets;
        in
        {
          default = self.devShells.${system}.latest;
          stable = mkDevShell pkgs kernelSets.stable;
          latest = mkDevShell pkgs kernelSets.latest;
          testing = mkDevShell pkgs kernelSets.testing;
        }
      );

      checks = forAllSystems (system: {
        stable = self.packages.${system}.stable;
        latest = self.packages.${system}.latest;
        testing = self.packages.${system}.testing;
      });

      formatter = forAllSystems (system: (perSystem system).pkgs.nixfmt);
    };
}
