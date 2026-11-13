{
  pkgs,
  osConfig,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe getExe';
  batExe = getExe pkgs.bat;
  dirExe = getExe' pkgs.coreutils "dir";
  ezaExe = getExe pkgs.eza;
  egrepExe = getExe' pkgs.gnugrep "egrep";
  fgrepExe = getExe' pkgs.gnugrep "fgrep";
  fzfExe = getExe pkgs.fzf;
  grepExe = getExe pkgs.gnugrep;
  hwinfoExe = getExe pkgs.hwinfo;
  journalctlExe = getExe' osConfig.systemd.package "journalctl";
  ncExe = getExe pkgs.netcat;
  run0Exe = getExe' osConfig.systemd.package "run0";
  vdirExe = getExe' pkgs.coreutils "vdir";
in
{
  programs = {
    fish = {
      enable = true;

      plugins = with pkgs; [
        {
          name = "plugin-git";
          src = fishPlugins.plugin-git.src;
        }
        {
          name = "fzf";
          src = fishPlugins.fzf-fish.src;
        }
        {
          name = "bass";
          src = fishPlugins.bass.src;
        }
      ];
      shellAbbrs = {
        # `systemctl` resolves to the fish wrapper function defined below.
        sc = "systemctl";
        scu = "systemctl --user";
        jr = "journalctl --no-pager";
        jru = "journalctl --user --no-pager";
        nl = "git -C $NH_FLAKE pull";
        nos = "nh os switch";
      };
      shellAliases = {
        ls = "${ezaExe} --all --long --color=always --group-directories-first --icons auto";
        la = "${ezaExe} --all --color=always --group-directories-first --icons auto";
        ll = "${ezaExe} --long --color=always --group-directories-first --icons auto";
        lt = "${ezaExe} --all --tree --color=always --group-directories-first --icons auto";
        ".." = "cd ..";
        "..." = "cd ../..";
        "...." = "cd ../../..";
        "....." = "cd ../../../..";
        "......" = "cd ../../../../..";
        dir = "${dirExe} --color=auto";
        vdir = "${vdirExe} --color=auto";
        grep = "${grepExe} --color=auto";
        fgrep = "${fgrepExe} --color=auto";
        egrep = "${egrepExe} --color=auto";
        hw = "${hwinfoExe} --short";
        d = "docker";
        dc = "docker compose";
        smbup = "${run0Exe} systemctl start smb";
        smbdown = "${run0Exe} systemctl stop smb";
        please = run0Exe;
        tb = "${ncExe} termbin.com 9999";
        jctl = "${journalctlExe} --priority=3 --catalog --boot";
        ff = "${fzfExe} --preview '${batExe} --style=numbers --color=always {}'";
        # opencode is installed via the private llm-agents override; the
        # alias intentionally keeps the PATH lookup.
        c = "opencode";
        # In-file fish function defined below.
        gti = "ghostty_terminfo_push";
      };
      functions = {
        fish_greeting = "";
        __history_previous_command = {
          body = /* fish */ ''
            switch (commandline --current-token)
                case "!"
                    commandline --current-token $history[1]
                    commandline --function repaint
                case "*"
                    commandline --insert !
            end
          '';
        };
        __history_previous_command_arguments = {
          body = /* fish */ ''
            switch (commandline --current-token)
                case "!"
                    commandline --current-token ""
                    commandline --function history-token-search-backward
                case "*"
                    commandline --insert '$'
            end
          '';
        };
        history = {
          body = "builtin history --show-time='%F %T '";
        };
        backup = {
          argumentNames = singleton "filename";
          body = "cp $filename $filename.bak";
        };
        copy = {
          body = /* fish */ ''
            set count (count $argv | tr --delete '\n')
            if test "$count" = 2; and test -d "$argv[1]"
                set from (echo $argv[1] | trim-right /)
                set to (echo $argv[2])
                command cp --recursive $from $to
            else
                command cp $argv
            end
          '';
        };
        n = {
          body = /* fish */ ''
            if test (count $argv) -eq 0
                nvim .
            else
                nvim $argv
            end
          '';
        };
        ghostty_terminfo_push = {
          description = "Install xterm-ghostty terminfo on remote host";
          body = /* fish */ ''
            if test (count $argv) -lt 1
                echo "Usage: ghostty_terminfo_push <ssh-target> [ssh args...]"
                return 2
            end

            if not command --query infocmp
                echo "infocmp is required locally"
                return 1
            end

            infocmp -x xterm-ghostty | ssh $argv -- tic -x -
          '';
        };
        zd = {
          body = /* fish */ ''
            if test (count $argv) -eq 0
                builtin cd ~; and return
            else if test -d "$argv[1]"
                builtin cd "$argv[1]"
            else
                z $argv; and printf "-> "; and pwd; or echo "Error: Directory not found"
            end
          '';
        };
        systemctl = {
          body = /* fish */ ''
            set --local user_commands \
              list-units list-unit-files list-jobs list-timers \
              list-sockets list-dependencies list-machines \
              is-active is-enabled is-failed \
              status show help get-default show-environment cat

            set --local root_commands start stop reload restart try-restart \
                reload-or-restart try-reload-or-restart isolate kill clean \
                set-property reset-failed enable disable reenable preset \
                preset-all mask unmask link revert add-wants add-requires \
                edit set-default cancel set-environment unset-environment import-environment \
                daemon-reload daemon-reexec default rescue emergency halt poweroff reboot \
                kexec exit switch-root suspend hibernate hybrid-sleep suspend-then-hibernate

            if contains -- --user $argv; or not contains -- $argv[1] $root_commands
                command systemctl $argv
            else
                 command run0 systemctl $argv
            end
          '';
          description = "wraps privileged and user systemctl commands to use run0 when necessary";
          wraps = "systemctl";
        };
        nxeval = {
          body = /* fish */ ''
            set --local attr (string join "." $argv)

            nix eval \
              "$NH_FLAKE#nixosConfigurations.$NIXOS_HOST.config.$attr" \
              --json
          '';
          description = "Evaluate a NixOS configuration option";
        };

        hmeval = {
          body = /* fish */ ''
            set --local attr (string join "." $argv)

            nix eval \
              "$NH_FLAKE#nixosConfigurations.$NIXOS_HOST.config.home-manager.users.$USER.$attr" \
              --json
          '';
          description = "Evaluate a Home Manager configuration option";
        };
      };
      interactiveShellInit = /* fish */ ''
        set --global --export MANROFFOPT -c
        set --global --export MANPAGER "sh -c 'col --no-backspaces --spaces | bat --language man --plain'"

        if test -f ~/.fish_profile
            source ~/.fish_profile
        end

        if test -d ~/.cargo/bin
            if not contains -- ~/.cargo/bin $PATH
                set --prepend PATH ~/.cargo/bin
            end
        end

        if test -d ~/Applications/depot_tools
            if not contains -- ~/Applications/depot_tools $PATH
                set --prepend PATH ~/Applications/depot_tools
            end
        end

        if test -f ~/expost-esp.sh
            . ~/expost-esp.sh
        end

        if [ "$fish_key_bindings" = fish_vi_key_bindings ]
            bind --mode insert ! __history_previous_command
            bind --mode insert '$' __history_previous_command_arguments
        else
            bind ! __history_previous_command
            bind '$' __history_previous_command_arguments
        end

        if command --search zoxide >/dev/null
            alias cd="zd"
        end
      '';
    };

    zoxide = {
      enable = true;
    };

    fzf = {
      enable = true;
    };

    eza = {
      enable = true;
      icons = "auto";
      git = true;
    };

    lazygit = {
      enable = true;
    };

    fd.enable = true;
    bat.enable = true;
    tealdeer = {
      enable = true;
      settings = {
        display.compact = true;
        updates = {
          auto_update = true;
          auto_update_interval_hours = 240;
        };
      };
      enableAutoUpdates = true;
    };
  };

  home.packages = singleton pkgs.fish;
}
