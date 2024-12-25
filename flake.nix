{
  description = "Blog";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils = {
      url = "github:numtide/flake-utils/v1.0.0";
    };

    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      devenv,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };

      in
      {
        devShells =
          let
            tooling = with pkgs; [
              just
              sqlite

              # To generate the Graph
              (pkgs.python3.withPackages (python-pkgs: [
                python-pkgs.networkx
                python-pkgs.numpy
                python-pkgs.scipy
              ]))

              # .Net
              netcoredbg
              fsautocomplete
              fantomas
            ];

            texenv = pkgs.texlive.combine {
              inherit (pkgs.texlive)
                accsupp
                bussproofs
                collection-basic
                collection-fontsextra
                collection-fontsrecommended
                collection-langenglish
                collection-langportuguese
                collection-latexextra
                collection-mathscience
                extsizes
                etoolbox
                hyphen-portuguese
                latexmk
                paracol
                pdfx
                ragged2e
                scheme-medium
                ;
            };

            dotnet = with pkgs.dotnetCorePackages; combinePackages [ sdk_8_0 ];

            customEmacs = (pkgs.emacsPackagesFor pkgs.emacs-nox).emacsWithPackages (
              epkgs:
              with epkgs.melpaPackages;
              [
                citeproc
              ]
              ++ (with epkgs.elpaPackages; [
                org
                org-roam
                org-roam-ui
              ])
            );
          in
          {
            # `nix develop .#ci`
            # Reduce the number of packages to the bare minimum needed for CI,
            # by removing LaTeX and not using my own Emacs configuration, but
            # a custom package with just enough tools to generate the markdown
            # for org-roam.
            ci = pkgs.mkShell {
              ENVIRONMENT = "prod";
              DOTNET_ROOT = "${dotnet}";
              DOTNET_CLI_TELEMETRY_OPTOUT = "1";
              LANG = "en_US.UTF-8";
              buildInputs = [
                dotnet
                pkgs.icu
                pkgs.tzdata
              ] ++ [ customEmacs ] ++ tooling;
            };

            # `nix develop --impure`
            # This is the development shell, meant to be used as an impure
            # shell, so no custom Emacs here, just use your global package
            # switch back to the CI shell for builds.
            default = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                (
                  { pkgs, lib, ... }:
                  {
                    packages = [
                      dotnet
                      pkgs.icu
                      pkgs.tzdata
                    ] ++ [ texenv ] ++ tooling;

                    env = {
                      ENVIRONMENT = "dev";
                      DOTNET_ROOT = "${dotnet}";
                      DOTNET_CLI_TELEMETRY_OPTOUT = "1";
                      LANG = "en_US.UTF-8";
                    };

                    scripts = {
                      build.exec = "just build";
                      graph.exec = "just graph";
                      clean.exec = "just clean";
                    };

                    enterShell = ''
                      echo "Starting environment..."
                      hugo version
                      export CONTENT_DIR=$(pwd)/content-org"
                    '';
                  }
                )
              ];
            };
          };

        # nix fmt
        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
