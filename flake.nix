{
  description = "Moxinet - HTTP mocking server for parallel testing";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      beamPackages = pkgs.beam.packages.erlang;
      inherit (beamPackages) elixir hex;
    in
    {
      packages.${system} = {
        default = beamPackages.mixRelease {
          pname = "moxinet";
          version = "0.7.0";
          src = ./.;

          mixFodDeps = beamPackages.fetchMixDeps {
            pname = "mix-deps-moxinet";
            version = "0.7.0";
            src = ./.;
            hash = "sha256-/eeLhmiFKs+ydXLatR2iO96sV+/nsiFKQmmdHaOFGas=";
          };

          meta = {
            description = "Mocking server that allows parallel testing over HTTP";
            license = pkgs.lib.licenses.mit;
          };
        };
      };

      devShells.${system} = {
        default = pkgs.mkShell {
          packages = [
            elixir
            hex
          ];
        };
      };

      checks.${system} = {
        inherit (self.packages.${system}) default;
        devShell = self.devShells.${system}.default;
      };
    };
}
