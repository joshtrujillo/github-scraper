{
  # Auto loads with direnv
  description = "Ruby development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Ruby with common gems
        rubyEnv = pkgs.ruby_3_3.withPackages (
          ps: with ps; [
            # gems
            activerecord
            sqlite3
            octokit
            dotenv
            faraday
            json
          ]
        );
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            bundler
            rubyEnv
            sqlite
            solargraph
          ];

          shellHook = ''
            echo "Ruby development environment loaded!"
            echo "Ruby version: $(ruby --version)"
            echo "Bundler version: $(bundle --version)"

            # Set up environment variables
            export BUNDLE_PATH="$PWD/.bundle"
            export BUNDLE_BIN="$PWD/.bundle/bin"
            export PATH="$BUNDLE_BIN:$PATH"

            # Create .bundle directory if it doesn't exist
            mkdir -p .bundle
          '';
        };

        # Optional: provide Ruby directly as a package
        packages.default = rubyEnv;
      }
    );
}
