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

    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      devenv,
      treefmt-nix,
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

        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

        tooling = with pkgs; [
          bash
          just
          sqlite
          icu
          tzdata

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

            # For CV builds
            moderncv
            ;
        };

        dotnet = with pkgs.dotnetCorePackages; combinePackages [ sdk_8_0 ];

        customEmacs = (pkgs.emacsPackagesFor pkgs.emacs-nox).emacsWithPackages (
          epkgs:
          with epkgs.melpaPackages;
          [
            citeproc
            htmlize
            ox-rss
          ]
          ++ (with epkgs.elpaPackages; [
            org
            org-roam
            org-roam-ui
          ])
        );

      in
      {
        packages = {
          # nix build
          default = pkgs.stdenv.mkDerivation {
            name = "site";
            src = pkgs.lib.cleanSource ./.;
            buildInputs = [
              dotnet
              customEmacs
            ] ++ tooling;
            buildPhase = ''
              just build
            '';
            installPhase = ''
              mkdir -p $out
              cp -r public/* $out/
            '';
          };
        };

        devShells = {
          # `nix develop .#ci`
          # Reduce the number of packages to the bare minimum needed for CI,
          # by removing LaTeX and not using my own Emacs configuration, but
          # a custom package with just enough tools for org-publish.
          ci = pkgs.mkShell {
            ENVIRONMENT = "prod";
            OUT_URL = "https://schonfinkel.github.io/";
            IS_CI = "1";
            DOTNET_ROOT = "${dotnet}";
            DOTNET_CLI_TELEMETRY_OPTOUT = "1";
            LANG = "en_US.UTF-8";
            buildInputs = [
              dotnet
              customEmacs
            ] ++ tooling;
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
                    texenv
                  ] ++ tooling;

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
                    publish.exec = "just publish";
                  };

                  enterShell = ''
                    echo "Starting environment..."
                  '';
                }
              )
            ];
          };
        };

        # nix fmt
        formatter = treefmtEval.config.build.wrapper;
      }
    );
}
