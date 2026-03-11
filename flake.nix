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

      version = "0.7.0";

      mixFodDeps = beamPackages.fetchMixDeps {
        pname = "mix-deps-moxinet";
        inherit version;
        src = ./.;
        hash = "sha256-/eeLhmiFKs+ydXLatR2iO96sV+/nsiFKQmmdHaOFGas=";
      };
    in
    {
      packages.${system} = {
        default = beamPackages.mixRelease {
          pname = "moxinet";
          inherit version;
          src = ./.;
          inherit mixFodDeps;

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

        tests = beamPackages.mixRelease {
          pname = "moxinet-tests";
          inherit version;
          src = ./.;
          mixEnv = "test";

          mixFodDeps = beamPackages.fetchMixDeps {
            pname = "mix-deps-moxinet-test";
            inherit version;
            src = ./.;
            mixEnv = "test";
            hash = "sha256-Sr+JSUSsQffpI0yKbgwZDSkl1DbubNT79ufmRbjshTU=";
          };

          # Run tests instead of building a release
          buildPhase = ''
            runHook preBuild
            mix compile --no-deps-check
            runHook postBuild
          '';

          checkPhase = ''
            mix test --no-deps-check
          '';
          doCheck = true;

          # We don't actually need the release output
          installPhase = ''
            runHook preInstall
            touch $out
            runHook postInstall
          '';

          # Skip the postFixup from mixRelease that looks for release files
          postFixup = "";
        };
      };
    };
}
