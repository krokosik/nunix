{ pkgs, ... }:
{
  programs.fish = {
    enable = true;
    shellAliases = {
      ls = "eza -al --color=always --group-directories-first --icons";
      la = "eza -a --color=always --group-directories-first --icons";
      ll = "eza -l --color=always --group-directories-first --icons";
      lt = "eza -aT --color=always --group-directories-first --icons";
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";
      "......" = "cd ../../../../..";
      dir = "dir --color=auto";
      vdir = "vdir --color=auto";
      grep = "grep --color=auto";
      fgrep = "fgrep --color=auto";
      egrep = "egrep --color=auto";
      hw = "hwinfo --short";
      d = "docker";
      dc = "docker compose";
      smbup = "sudo systemctl start smb";
      smbdown = "sudo systemctl stop smb";
      please = "sudo";
      tb = "nc termbin.com 9999";
      jctl = "journalctl -p 3 -xb";
      ff = "fzf --preview 'bat --style=numbers --color=always {}'";
      c = "opencode";
    };
    functions = {
      fish_greeting = "";
      __history_previous_command = {
        body = ''
          switch (commandline -t)
              case "!"
                  commandline -t $history[1]
                  commandline -f repaint
              case "*"
                  commandline -i !
          end
        '';
      };
      __history_previous_command_arguments = {
        body = ''
          switch (commandline -t)
              case "!"
                  commandline -t ""
                  commandline -f history-token-search-backward
              case "*"
                  commandline -i '$'
          end
        '';
      };
      history = {
        body = "builtin history --show-time='%F %T '";
      };
      backup = {
        argumentNames = [ "filename" ];
        body = "cp $filename $filename.bak";
      };
      copy = {
        body = ''
          set count (count $argv | tr -d '\n')
          if test "$count" = 2; and test -d "$argv[1]"
              set from (echo $argv[1] | trim-right /)
              set to (echo $argv[2])
              command cp -r $from $to
          else
              command cp $argv
          end
        '';
      };
      n = {
        body = ''
          if test (count $argv) -eq 0
              nvim .
          else
              nvim $argv
          end
        '';
      };
      zd = {
        body = ''
          if test (count $argv) -eq 0
              builtin cd ~; and return
          else if test -d "$argv[1]"
              builtin cd "$argv[1]"
          else
              z $argv; and printf "-> "; and pwd; or echo "Error: Directory not found"
          end
        '';
      };
    };
    interactiveShellInit = ''
      set -gx MANROFFOPT -c
      set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"

      if test -f ~/.fish_profile
          source ~/.fish_profile
      end

      if test -d ~/.cargo/bin
          if not contains -- ~/.cargo/bin $PATH
              set -p PATH ~/.cargo/bin
          end
      end

      if test -d ~/Applications/depot_tools
          if not contains -- ~/Applications/depot_tools $PATH
              set -p PATH ~/Applications/depot_tools
          end
      end

      if test -f ~/expost-esp.sh
          . ~/expost-esp.sh
      end

      if [ "$fish_key_bindings" = fish_vi_key_bindings ]
          bind -Minsert ! __history_previous_command
          bind -Minsert '$' __history_previous_command_arguments
      else
          bind ! __history_previous_command
          bind '$' __history_previous_command_arguments
      end

      if command -v zoxide >/dev/null
          alias cd="zd"
      end

      mise activate fish | source || true
    '';
  };

  programs.starship.enable = true;

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
  };

  home.packages = [ pkgs.fish ];
}
