{
  description = "Dev shell with Zig from nixpkgs-unstable";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/979daf34c8cacebcd917d540070b52a3c2b9b16e?narHash=sha256-uKCfuDs7ZM3QpCE/jnfubTg459CnKnJG/LwqEVEdEiw%3D";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # Add the allowUnfree setting here
          #config.allowUnfree = true;
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            ruff # Dev dependency
            uv
          ];
        };

        # shellHook to remind user to check Podman
        shellHook = ''
        '';
      });
}

