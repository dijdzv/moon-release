/// Shell completion script generation

/// generate-completions command
pub fn cmd_generate_completions(subcmd : @clap.SimpleValue) -> Unit {
  let shell : String = if subcmd.positional_args.length() > 0 {
    subcmd.positional_args[0]
  } else {
    println("Error: shell argument is required")
    println("Usage: moon-release generate-completions <shell>")
    println("Supported shells: bash, zsh, fish")
    exit_error()
  }

  match shell {
    "bash" => print_bash_completion()
    "zsh" => print_zsh_completion()
    "fish" => print_fish_completion()
    _ => {
      println("Error: unsupported shell: " + shell)
      println("Supported shells: bash, zsh, fish")
      exit_error()
    }
  }
}

/// Output bash completion script
fn print_bash_completion() -> Unit {
  let script =
    #|# moon-release bash completion
    #|# Add this to ~/.bashrc or source it
    #|
    #|_moon_release_completions() {
    #|    local cur prev opts commands
    #|    COMPREPLY=()
    #|    cur="${COMP_WORDS[COMP_CWORD]}"
    #|    prev="${COMP_WORDS[COMP_CWORD-1]}"
    #|
    #|    commands="update release-pr release init version check set-version generate-completions generate-schema"
    #|    global_opts="-n --dry-run -v --verbose -c --config -h --help"
    #|
    #|    case "${COMP_WORDS[1]}" in
    #|        update)
    #|            opts="-n --dry-run -b --bump --bump-all -p --packages -o --output"
    #|            ;;
    #|        release-pr)
    #|            opts="-n --dry-run -b --bump --bump-all"
    #|            ;;
    #|        release)
    #|            opts="-n --dry-run -b --bump --bump-all -p --prerelease"
    #|            ;;
    #|        init)
    #|            opts="-f --force"
    #|            ;;
    #|        check)
    #|            opts="-o --output"
    #|            ;;
    #|        set-version)
    #|            opts="-n --dry-run"
    #|            ;;
    #|        generate-completions)
    #|            if [[ ${COMP_CWORD} -eq 2 ]]; then
    #|                COMPREPLY=( $(compgen -W "bash zsh fish" -- ${cur}) )
    #|                return 0
    #|            fi
    #|            opts=""
    #|            ;;
    #|        *)
    #|            if [[ ${COMP_CWORD} -eq 1 ]]; then
    #|                COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
    #|                return 0
    #|            fi
    #|            opts="${global_opts}"
    #|            ;;
    #|    esac
    #|
    #|    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    #|    return 0
    #|}
    #|
    #|complete -F _moon_release_completions moon-release
  println(script)
}

/// Output zsh completion script
fn print_zsh_completion() -> Unit {
  let script =
    #|#compdef moon-release
    #|# moon-release zsh completion
    #|# Add this to ~/.zshrc or place in your fpath
    #|
    #|_moon-release() {
    #|    local -a commands
    #|    commands=(
    #|        'update:Update version locally (no commit/push)'
    #|        'release-pr:Create a release pull request'
    #|        'release:Create a release (tag and GitHub release)'
    #|        'init:Initialize release configuration'
    #|        'version:Show version information'
    #|        'check:Check the current state without making changes'
    #|        'set-version:Set the package version manually'
    #|        'generate-completions:Generate shell completion script'
    #|        'generate-schema:Generate JSON schema for release.json'
    #|    )
    #|
    #|    local -a global_opts
    #|    global_opts=(
    #|        '-n[Show what would be done without making changes]'
    #|        '--dry-run[Show what would be done without making changes]'
    #|        '-v[Enable verbose output]'
    #|        '--verbose[Enable verbose output]'
    #|        '-c[Path to config file]:config file:_files'
    #|        '--config[Path to config file]:config file:_files'
    #|        '-h[Show help]'
    #|        '--help[Show help]'
    #|    )
    #|
    #|    _arguments -C \
    #|        $global_opts \
    #|        '1:command:->command' \
    #|        '*::arg:->args'
    #|
    #|    case $state in
    #|        command)
    #|            _describe -t commands 'moon-release command' commands
    #|            ;;
    #|        args)
    #|            case $words[1] in
    #|                update)
    #|                    _arguments \
    #|                        '-n[Show what would be done]' \
    #|                        '--dry-run[Show what would be done]' \
    #|                        '-b[Force version bump]:bump:(major minor patch)' \
    #|                        '--bump[Force version bump]:bump:(major minor patch)' \
    #|                        '--bump-all[Force bump ALL packages]' \
    #|                        '-p[Update all packages]' \
    #|                        '--packages[Update all packages]' \
    #|                        '-o[Output format]:format:(text json)' \
    #|                        '--output[Output format]:format:(text json)'
    #|                    ;;
    #|                release-pr)
    #|                    _arguments \
    #|                        '-n[Show what would be done]' \
    #|                        '--dry-run[Show what would be done]' \
    #|                        '-b[Force version bump]:bump:(major minor patch)' \
    #|                        '--bump[Force version bump]:bump:(major minor patch)' \
    #|                        '--bump-all[Force bump ALL packages]'
    #|                    ;;
    #|                release)
    #|                    _arguments \
    #|                        '-n[Show what would be done]' \
    #|                        '--dry-run[Show what would be done]' \
    #|                        '-b[Force version bump]:bump:(major minor patch)' \
    #|                        '--bump[Force version bump]:bump:(major minor patch)' \
    #|                        '--bump-all[Force bump ALL packages]' \
    #|                        '-p[Prerelease identifier]:prerelease:' \
    #|                        '--prerelease[Prerelease identifier]:prerelease:'
    #|                    ;;
    #|                init)
    #|                    _arguments \
    #|                        '-f[Overwrite existing configuration]' \
    #|                        '--force[Overwrite existing configuration]'
    #|                    ;;
    #|                check)
    #|                    _arguments \
    #|                        '-o[Output format]:format:(text json)' \
    #|                        '--output[Output format]:format:(text json)'
    #|                    ;;
    #|                set-version)
    #|                    _arguments \
    #|                        '-n[Show what would be done]' \
    #|                        '--dry-run[Show what would be done]' \
    #|                        ':version:'
    #|                    ;;
    #|                generate-completions)
    #|                    _arguments \
    #|                        ':shell:(bash zsh fish)'
    #|                    ;;
    #|                generate-schema)
    #|                    ;;
    #|            esac
    #|            ;;
    #|    esac
    #|}
    #|
    #|_moon-release "$@"
  println(script)
}

/// Output fish completion script
fn print_fish_completion() -> Unit {
  let script =
    #|# moon-release fish completion
    #|# Add this to ~/.config/fish/completions/moon-release.fish
    #|
    #|# Disable file completions
    #|complete -c moon-release -f
    #|
    #|# Global options
    #|complete -c moon-release -s n -l dry-run -d 'Show what would be done without making changes'
    #|complete -c moon-release -s v -l verbose -d 'Enable verbose output'
    #|complete -c moon-release -s c -l config -r -d 'Path to config file'
    #|complete -c moon-release -s h -l help -d 'Show help'
    #|
    #|# Commands
    #|complete -c moon-release -n '__fish_use_subcommand' -a update -d 'Update version locally'
    #|complete -c moon-release -n '__fish_use_subcommand' -a release-pr -d 'Create a release pull request'
    #|complete -c moon-release -n '__fish_use_subcommand' -a release -d 'Create a release'
    #|complete -c moon-release -n '__fish_use_subcommand' -a init -d 'Initialize release configuration'
    #|complete -c moon-release -n '__fish_use_subcommand' -a version -d 'Show version information'
    #|complete -c moon-release -n '__fish_use_subcommand' -a check -d 'Check the current state'
    #|complete -c moon-release -n '__fish_use_subcommand' -a set-version -d 'Set the package version manually'
    #|complete -c moon-release -n '__fish_use_subcommand' -a generate-completions -d 'Generate shell completion script'
    #|complete -c moon-release -n '__fish_use_subcommand' -a generate-schema -d 'Generate JSON schema for release.json'
    #|
    #|# update options
    #|complete -c moon-release -n '__fish_seen_subcommand_from update' -s n -l dry-run -d 'Show what would be done'
    #|complete -c moon-release -n '__fish_seen_subcommand_from update' -s b -l bump -r -a 'major minor patch' -d 'Force version bump'
    #|complete -c moon-release -n '__fish_seen_subcommand_from update' -l bump-all -d 'Force bump ALL packages'
    #|complete -c moon-release -n '__fish_seen_subcommand_from update' -s p -l packages -d 'Update all packages'
    #|complete -c moon-release -n '__fish_seen_subcommand_from update' -s o -l output -r -a 'text json' -d 'Output format'
    #|
    #|# release-pr options
    #|complete -c moon-release -n '__fish_seen_subcommand_from release-pr' -s n -l dry-run -d 'Show what would be done'
    #|complete -c moon-release -n '__fish_seen_subcommand_from release-pr' -s b -l bump -r -a 'major minor patch' -d 'Force version bump'
    #|complete -c moon-release -n '__fish_seen_subcommand_from release-pr' -l bump-all -d 'Force bump ALL packages'
    #|
    #|# release options
    #|complete -c moon-release -n '__fish_seen_subcommand_from release' -s n -l dry-run -d 'Show what would be done'
    #|complete -c moon-release -n '__fish_seen_subcommand_from release' -s b -l bump -r -a 'major minor patch' -d 'Force version bump'
    #|complete -c moon-release -n '__fish_seen_subcommand_from release' -l bump-all -d 'Force bump ALL packages'
    #|complete -c moon-release -n '__fish_seen_subcommand_from release' -s p -l prerelease -r -d 'Prerelease identifier'
    #|
    #|# init options
    #|complete -c moon-release -n '__fish_seen_subcommand_from init' -s f -l force -d 'Overwrite existing configuration'
    #|
    #|# check options
    #|complete -c moon-release -n '__fish_seen_subcommand_from check' -s o -l output -r -a 'text json' -d 'Output format'
    #|
    #|# set-version options
    #|complete -c moon-release -n '__fish_seen_subcommand_from set-version' -s n -l dry-run -d 'Show what would be done'
    #|
    #|# generate-completions options
    #|complete -c moon-release -n '__fish_seen_subcommand_from generate-completions' -a 'bash zsh fish' -d 'Shell type'
  println(script)
}
