{
  inputs,
  pkgs,
  ...
}:
let
  firefox-addons = inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ inputs.zen-browser.homeModules.twilight ];

  programs.zen-browser = {
    enable = true;
    package = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.twilight;
    setAsDefaultBrowser = true;

    profiles.default = {
      isDefault = true;

      extensions.packages = with firefox-addons; [
        consent-o-matic
        dont-track-me-google1
        facebook-container
        github-file-icons
        hover-zoom-plus
        web-clipper-obsidian
        privacy-badger
        proton-pass
        return-youtube-dislikes
        sponsorblock
        ublock-origin
        violentmonkey
      ];

      settings = {
        "browser.search.region" = "PL";
        "browser.search.serpEventTelemetryCategorization.regionEnabled" = false;
        "browser.toolbars.bookmarks.visibility" = "always";
        "browser.urlbar.showSearchSuggestionsFirst" = false;
        "extensions.formautofill.creditCards.enabled" = false;
        "network.dns.disablePrefetch" = true;
        "network.http.speculative-parallel-limit" = 0;
        "network.prefetch-next" = false;
        "privacy.clearOnShutdown_v2.formdata" = true;
        "sidebar.visibility" = "hide-sidebar";
        "zen.tabs.show-newtab-vertical" = false;
        "zen.view.compact.enable-at-startup" = false;
        "zen.view.window.scheme" = 0;
      };

      search = {
        force = true;
        default = "qwant";

        engines.qwant = {
          name = "Qwant";
          urls = [
            {
              template = "https://www.qwant.com/?q={searchTerms}";
            }
          ];
          definedAliases = [ "@qwant" ];
        };
      };
    };
  };

  # Zotero Connector is not currently packaged by rycee's Firefox add-on set,
  # so install its signed AMO artifact through Zen's declarative policy.
  programs.zen-browser.policies.ExtensionSettings."zotero@chnm.gmu.edu" = {
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/zotero-connector/latest.xpi";
    installation_mode = "force_installed";
  };
}
