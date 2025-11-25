{
  description = "Haskell Stack Dev Shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/979daf34c8cacebcd917d540070b52a3c2b9b16e?narHash=sha256-uKCfuDs7ZM3QpCE/jnfubTg459CnKnJG/LwqEVEdEiw%3D";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            podman # To build the image
            stack
            hlint
            fourmolu
            gmp # to be able to build the server
            zlib # to build server
          ];

          # shellHook to remind user to check Podman
          shellHook = ''
            if ! podman info &>/dev/null; then
              echo "Warning: Podman is not running properly."
              echo "Please make sure Podman is installed and working."
            fi
          '';
        };
      });
}

