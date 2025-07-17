{ pkgs }:

pkgs.emacs.pkgs.trivialBuild {
  pname = "org-cv";
  version = "unstable-2025-01-24";

  src = pkgs.fetchFromGitLab {
    owner = "Titan-C";
    repo = "org-cv";
    rev = "e8de952df7669b38ca475d00fe943ab96d8cfac4";
    sha256 = "sha256-qwJTtyfNZpA4YCOxh90hXW89aYThE9K6GnJIxeUI7No=";
  };

  packageRequires = [ pkgs.emacsPackages.org pkgs.emacsPackages.ox-hugo ];

  meta = {
    description = "Org exporter for CV generation";
    longDescription = ''
      org-cv provides various export backends for Org mode to generate
      professional CVs and resumes. It includes exporters for:
      - ModernCV LaTeX template (ox-moderncv)
      - AltaCV LaTeX template (ox-altacv) 
      - Hugo Academic theme (ox-hugocv)
      - AwesomeCV LaTeX template (ox-awesomecv)
    '';
    homepage = "https://gitlab.com/Titan-C/org-cv";
    license = pkgs.lib.licenses.gpl3Plus;
    maintainers = [ ];
    platforms = pkgs.lib.platforms.all;
  };
}
