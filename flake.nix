{
  description = "Home automation with BeagleBone Black";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      # Cross-compilation target for BeagleBone Black (ARMv7)
      armPkgs = import nixpkgs {
        system = "x86_64-linux";
        crossSystem = {
          config = "armv7l-unknown-linux-gnueabihf";
          gcc = { arch = "armv7-a"; fpu = "vfpv3"; };
        };
      };

      # Native x86 pkgs for dev shell
      x86Pkgs = import nixpkgs { system = "x86_64-linux"; };

      # Source for the controller
      controllerSrc = ./app/controller;

      # Build the Haskell controller for ARM
      growatt-controller-arm = armPkgs.haskellPackages.callCabal2nix
        "growatt-controller"
        controllerSrc
        {};

      # Build for x86 (for testing)
      growatt-controller-x86 = x86Pkgs.haskellPackages.callCabal2nix
        "growatt-controller"
        controllerSrc
        {};

    in {
      # Packages
      packages.x86_64-linux = {
        growatt-controller = growatt-controller-x86;
        growatt-controller-arm = growatt-controller-arm;
        default = growatt-controller-x86;
      };

      # NixOS configuration for BeagleBone Black
      nixosConfigurations.bbb = nixpkgs.lib.nixosSystem {
        system = "armv7l-linux";
        specialArgs = { inherit growatt-controller-arm; };
        modules = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-armv7l-multiplatform.nix"
          ({ pkgs, lib, growatt-controller-arm, ... }: {
            # Hostname
            networking.hostName = "bbb";

            # Enable SSH
            services.openssh.enable = true;

            # Growatt controller service
            systemd.services.growatt-controller = {
              description = "Growatt Inverter Controller";
              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];
              serviceConfig = {
                ExecStart = "${growatt-controller-arm}/bin/controller";
                Restart = "always";
                RestartSec = 10;
              };
            };

            # Basic packages
            environment.systemPackages = with pkgs; [
              vim
              htop
              screen
            ];

            # User setup
            users.users.root.initialPassword = "nixos";
            users.users.nixos = {
              isNormalUser = true;
              extraGroups = [ "wheel" "dialout" ];
              initialPassword = "nixos";
            };

            # Allow passwordless sudo for wheel
            security.sudo.wheelNeedsPassword = false;

            # Compress the image
            sdImage.compressImage = true;

            # System state version
            system.stateVersion = "25.05";
          })
        ];
      };

      # SD card image (build with: nix build .#images.bbb)
      images.bbb = self.nixosConfigurations.bbb.config.system.build.sdImage;

      # Dev shell for local development
      devShells.x86_64-linux.default = x86Pkgs.mkShell {
        buildInputs = with x86Pkgs; [
          gnumake
          qemu
          screen
          # Haskell dev tools
          stack
          hlint
          fourmolu
          libmodbus
        ];
      };
    };
}
