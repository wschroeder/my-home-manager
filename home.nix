# From flake without installation yet:
#   nix run home-manager/master -- switch --flake path:$PWD
#
# After installation:
#   home-manager switch --flake path:$PWD
#
# Clean up old cruft:
#   nix-collect-garbage -d

{ pkgs, lib, beads, ... }:

{
  programs.home-manager.enable = true;

  nix = {
    package = pkgs.nix;
    settings = {
      experimental-features = "nix-command flakes";
      keep-outputs = true;
      keep-derivations = true;
    };
  };

  home.packages = with pkgs; [
    aerospace
    awscli2
    beads
    bat
    cacert
    coreutils
    duckdb
    eksctl
    emacs
    fq
    gh
    git-lfs
    google-cloud-sdk
    graphviz
    heroku
    htop
    jq
    json-plot
    kubent
    moreutils
    mosh
    nerd-fonts.fira-code
    nix-direnv
    nodejs
    python313Packages.sqlparse
    rlwrap
    s3cmd
    silver-searcher-ng
    socat
    sqlite-interactive
    ssm-session-manager-plugin
    termshark
    tmux
    vim
    universal-ctags
    unixtools.watch
    xmlformat
    yq

    buildkite-cli
    kubectl
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    silent = true;

    stdlib = ''
      source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
    '';
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;

    shellAliases = {
      ls = "ls --color=auto -F";
      ll = "ls --color=auto -Frtal";
      k = "kubectl";
      reb = "git pull --rebase origin $(if git rev-parse master &>/dev/null; then echo master; else echo main; fi)";
      gpf = "git push --force-with-lease";
      gprune = "git fetch --prune --tags && git remote prune origin";
      ghpr = "git pull --rebase origin $(if git rev-parse master &>/dev/null; then echo master; else echo main; fi) && git push -u origin HEAD && gh pr create --fill --web";
    };

    initExtra = ''
      ulimit -n 4096

      # This gives the greatest control over the PATH
      export PATH="$HOME/bin:$HOME/.rd/bin:$HOME/.local/bin:$HOME/.nix-profile/bin:$PATH:$HOME/.vim/plugged/vim-iced/bin:$HOME/.mix/escripts:$HOME/.npm/bin"

      export EDITOR='vim'
      check_for_cursor_ide() {
        local pid=$$
        while [ "$pid" -gt 1 ]; do
          proc_name=$(ps -p $pid -o comm= 2>/dev/null)
          if [[ "$proc_name" =~ Cursor ]]; then
            return 0
          fi
          pid=$(ps -p $pid -o ppid= 2>/dev/null | tr -d ' ')
        done
        return 1
      }
      if check_for_cursor_ide; then
        export EDITOR='cursor --wait'
      fi


      # Machine-specific functions
      [ -f ~/.bash_functions ] && source ~/.bash_functions

      # mix bash completion
      complete_mix_command() {
        [ -f mix.exs ] || exit 0

        now=$(date +%s)
        half_hour_ago=$((now - 1800))
        if [[ ! -f $TMPDIR/mix-completion || $half_hour_ago -gt $(stat -c %Y $TMPDIR/mix-completion) ]]; then
          mix help > $TMPDIR/mix-completion
        fi
        grep "^mix $2" $TMPDIR/mix-completion | cut -f1 -d'#' | cut -f2 -d' '
        return $?
      }

      complete -C complete_mix_command -o default mix

      function get_output_saver_home() {
          local home="$TMPDIR/$USER/.output-saver"
          if [ ! -d "$home" ]; then
              mkdir -p $home
          else
              # Delete all output files older than a week
              find "$home" -type f -mtime +7 | xargs rm -f
          fi
          echo "$home"
      }

      function s() {
          local home=$(get_output_saver_home)
          local id=$1
          if [ "$id" == "" ]; then
              id=$(uuidgen)
          fi

          tee "$home/$id" 2>&1
      }

      function r() {
          local home=$(get_output_saver_home)
          local id=$1
          if [ "$id" == "" ]; then
              id=$(ls -1rt $home/ | tail -n 1)
          fi
          cat "$home/$id"
      }

      function c() {
          local field=$1
          if [[ "$field" == "" ]]; then
              field=1
          fi
          if [[ $field < 0 ]]; then
              field="(NF$field)"
          fi
          if [[ "$field" == "0" ]]; then
              field="NF"
          fi
          awk "{print \$$field}"
      }

      function g() {
          local config=$HOME/.g-places
          local command=$1
          local go_place=$2
          if [[ ! -f $config ]]; then
              sqlite3 -line $config 'create table actions (key VARCHAR2(255), action_type VARCHAR2(10), action VARCHAR2(2048), constraint actions_pk primary key (key))'
          fi
          case "$command" in
              -h|--help)
                  echo "Usage:" && \
                  echo "  g -h|--help                       Display this help" && \
                  echo "  g -s|--save KEY                   Save current directory as KEY for future g" && \
                  echo "  g -d|--delete|-f|--forget [KEY]   Delete from g's memory the current directory or KEY" && \
                  echo "  g -l|--list                       List all g keys and destinations" && \
                  echo "  g -a|--action KEY COMMAND         Saves a commandline COMMAND that may be called by KEY" && \
                  echo "  g KEY                             cd to the directory referred to by KEY" |
                  less -E
                  ;;
              -s|--save)
                  if [[ "$go_place" == "" ]]; then
                      echo "g: You must specify a key for your new location."
                      return 1
                  fi
                  if [[ "$(sqlite3 $config "select key from actions where key='$go_place'" | wc -l | xargs)" != "0" ]]; then
                      local destination=$(sqlite3 $config "select action from actions where key='$go_place'")
                      echo "g: Key \"$go_place\" is already defined as having this destination:"
                      echo "  $destination"
                      return 1
                  fi
                  sqlite3 $config "insert into actions (key, action_type, action) values ('$go_place', 'cd', '$PWD')"
                  echo "g: $go_place = $PWD"
                  ;;
              -a|--action)
                  if [[ "$go_place" == "" ]]; then
                      echo "g: You must specify a key for your new command"
                      return 1
                  fi
                  shift
                  shift
                  local new_command="$*"
                  if [[ "$new_command" == "" ]]; then
                      echo "g: You must specify a command for your new command"
                      return 1
                  fi
                  if [[ "$(sqlite3 $config "select key from actions where key='$go_place'" | wc -l | xargs)" != "0" ]]; then
                      local destination=$(sqlite3 $config "select action from actions where key='$go_place'")
                      local action_type=$(sqlite3 $config "select action_type from actions where key='$go_place'")
                      echo "g: Key \"$go_place\" is already defined as having this action (type $action_type):"
                      echo "  $destination"
                      return 1
                  fi
                  sqlite3 $config "insert into actions (key, action_type, action) values ('$go_place', 'cmd', '$new_command')"
                  echo "g: $go_place = $new_command"
                  ;;
              -d|--delete|-f|--forget)
                  if [[ "$go_place" == "" ]]; then
                      if [[ "$(sqlite3 $config "select action from actions where action_type='cd' and action='$PWD'" | wc -l | xargs)" != "0" ]]; then
                          sqlite3 $config "delete from actions where action_type='cd' and action='$PWD'"
                          echo "g: Destination forgotten:"
                          echo "  $PWD"
                      else
                          echo "g: g does not know the destination:"
                          echo "  $PWD"
                          return 1
                      fi
                  else
                      if [[ "$(sqlite3 $config "select key from actions where key='$go_place'" | wc -l | xargs)" != "0" ]]; then
                          sqlite3 $config "delete from actions where key='$go_place'"
                          echo "g: Key \"$go_place\" is forgotten"
                      else
                          echo "g: g does not know key \"$go_place\""
                          return 1
                      fi
                  fi
                  ;;
              -l|--list)
                  if [[ "$go_place" == "" ]]; then
                      sqlite3 -header -column $config "select * from actions"
                  else
                      echo "g: $command does not take arguments"
                      return 1
                  fi
                  ;;
              *)
                  if [[ "$command" == "" ]]; then
                      echo "g: Use \"g --help\" to learn how to use g."
                      return 1
                  fi
                  if [[ "$go_place" != "" ]]; then
                      echo "g: g can only go one place at a time."
                      return 1
                  fi
                  if [[ "$(sqlite3 $config "select key from actions where key='$command'" | wc -l | xargs)" != "0" ]]; then
                      local action_type=$(sqlite3 $config "select action_type from actions where key='$command'")
                      local action=$(sqlite3 $config "select action from actions where key='$command'")
                      if [[ "$action_type" == "cd" ]]; then
                          pushd . > /dev/null
                          echo $action
                          cd $action
                      else
                          $action
                      fi
                  else
                      echo "g: g does not know key \"$command\""
                      return 1
                  fi
                  ;;
          esac
      }

      function vg() {
        vim -q <(rg -n "$@" | sort -t: -k1,1 -k2,2n)
      }
    '';

    # profileExtra = ''
    #   export PATH="$PATH:$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
    # '';
  };

  home.sessionVariables = {
    BASH_SILENCE_DEPRECATION_WARNING = "1";
    NIXPKGS_ALLOW_UNFREE = "1";
    LESS = "-eiMXR";
    HISTTIMEFORMAT = "%h %d - %H:%M:%S  ";
    DFT_SYNTAX_HIGHLIGHT = "off";
    ERL_AFLAGS = "-kernel shell_history enabled";
    DIRENV_LOG_FORMAT = "";
    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
  } // (if builtins.pathExists ./secret-env-vars.nix then import ./secret-env-vars.nix else {});

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    defaultCommand = "rg --files --hidden";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
    ];
  };

  programs.starship.enable = true;
  programs.zsh.enable = true;

  programs.git = {
    enable = true;

    ignores = [
      "*~"
      ".DS_Store"
    ];

    settings = {
      user = {
        name = "William Schroeder";
        email = "schroederw@objectcomputing.com";
      };

      alias = {
        tlog = "log --graph --full-history --date-order --pretty=format:'%w(120, 0, 9)%C(yellow)%h%Cred%d%Creset %C(green)%an%Creset %C(white)%s%Creset'";
        tdlog = "log --graph --full-history --date-order --pretty=format:'%w(120, 0, 9)%C(yellow)%h%Cred%d%Creset %C(magenta)(%ci)%Creset %C(green)%an%Creset %C(white)%s%Creset'";
        cleanup = "!git branch --merged | grep  -v '\\*\\|master\\|develop' | xargs -n 1 git branch -d";
      };

      color = {
        diff = "auto";
        branch = "auto";
        status = "auto";
      };

      merge = {
        tool = "vimdiff";
        conflictstyle = "diff3";
      };

      branch.autoSetupRebase = "always";
      push.default = "upstream";

      core = {
        preloadIndex = true;
        # editor = "cursor --wait";
      };

      init.defaultBranch = "master";

      pull.rebase = true;

      filter.lfs = {
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
        process = "git-lfs filter-process";
        required = true;
      };

      credential = {
        helper = [
          ""
          "!${pkgs.gh}/bin/gh auth git-credential"
        ];
      };
    };
  };

  programs.k9s = {
    enable = true;
    plugins = if builtins.pathExists ./k9s-plugins.nix then import ./k9s-plugins.nix else {};
  };

  programs.ripgrep = {
    enable = true;
    arguments = [ "-n" ];
  };
}
