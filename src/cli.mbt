///|
suberror CliValueError {
  MissingValue(String)
}

///|
fn get_cli_value(
  matches : @argparse.Matches,
  name : String,
) -> String raise CliValueError {
  match matches.values.get(name) {
    Some(values) if !values.is_empty() => values[0]
    _ => raise MissingValue(name)
  }
}

///|
fn create_parser() -> @argparse.Command {
  let bump = @argparse.OptionArg(
    "bump",
    long="bump",
    short='b',
    about="Force a version bump (major, minor, patch)",
  )
  let bump_all = @argparse.FlagArg(
    "bump-all",
    long="bump-all",
    about="Force bump all packages including unchanged ones",
  )
  let output = @argparse.OptionArg(
    "output",
    long="output",
    short='o',
    default_values=["text"],
    about="Output format (text, json)",
  )
  @argparse.Command(
    "moon-release",
    about="Automated release management tool for MoonBit",
    flags=[
      @argparse.FlagArg(
        "dry-run",
        long="dry-run",
        short='n',
        global=true,
        about="Show what would be done without making changes",
      ),
      @argparse.FlagArg(
        "verbose",
        long="verbose",
        short='v',
        global=true,
        about="Enable verbose output",
      ),
    ],
    options=[
      @argparse.OptionArg(
        "config",
        long="config",
        short='c',
        global=true,
        default_values=["release.json"],
        about="Path to config file",
      ),
    ],
    subcommands=[
      @argparse.Command(
        "update",
        about="Update version locally (no commit/push)",
        flags=[
          bump_all,
          @argparse.FlagArg(
            "packages",
            long="packages",
            short='p',
            about="Update all packages in monorepo mode",
          ),
        ],
        options=[bump, output],
      ),
      @argparse.Command(
        "release-pr",
        about="Create a release pull request",
        flags=[bump_all],
        options=[bump],
      ),
      @argparse.Command(
        "release",
        about="Create a tag and release",
        flags=[bump_all],
        options=[
          bump,
          @argparse.OptionArg(
            "prerelease",
            long="prerelease",
            short='p',
            about="Prerelease identifier (alpha, beta, rc)",
          ),
        ],
      ),
      @argparse.Command("init", about="Initialize release configuration", flags=[
        @argparse.FlagArg(
          "force",
          long="force",
          short='f',
          about="Overwrite existing configuration",
        ),
      ]),
      @argparse.Command("version", about="Show version information"),
      @argparse.Command(
        "check",
        about="Check current state without making changes",
        options=[output],
      ),
      @argparse.Command("set-version", about="Set package version manually", positionals=[
        @argparse.PositionArg(
          "version",
          num_args=@argparse.ValueRange::single(),
          about="Version to set (e.g. 1.2.3)",
        ),
      ]),
      @argparse.Command(
        "generate-completions",
        about="Generate shell completion script",
        positionals=[
          @argparse.PositionArg(
            "shell",
            num_args=@argparse.ValueRange::single(),
            about="Shell (bash, zsh, fish)",
          ),
        ],
      ),
      @argparse.Command(
        "generate-schema",
        about="Generate JSON Schema for release.json",
      ),
    ],
  )
}
