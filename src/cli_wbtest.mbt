///|
test "global options work before and after release commands" {
  for
    argv in [
      ["--dry-run", "--verbose", "--config", "custom.json", "release-pr"],
      ["release-pr", "--dry-run", "--verbose", "--config", "custom.json"],
      ["release-pr", "-n", "-v", "-c", "custom.json"],
    ] {
    let matches = create_parser().parse(argv=argv[:])
    let (name, subcmd) = matches.subcommand.unwrap()
    assert_eq(name, "release-pr")
    assert_true(get_dry_run_flag(subcmd, get_flag_or_false(matches, "dry-run")))
    assert_true(get_flag_or_false(matches, "verbose"))
    assert_eq(get_cli_value(matches, "config"), "custom.json")
  }
}

///|
test "commands retain positionals defaults and command-specific options" {
  for
    (argv, name, key, expected) in [
      (["set-version", "2.0.0", "--dry-run"], "set-version", "version", "2.0.0"),
      (
        ["generate-completions", "bash"],
        "generate-completions",
        "shell",
        "bash",
      ),
      (["update", "--bump", "minor", "--packages"], "update", "bump", "minor"),
      (["check"], "check", "output", "text"),
      (["check", "--output=json"], "check", "output", "json"),
      (["release", "--prerelease", "rc"], "release", "prerelease", "rc"),
    ] {
    let parsed = create_parser().parse(argv=argv[:])
    let (command, matches) = parsed.subcommand.unwrap()
    assert_eq(command, name)
    assert_eq(get_cli_value(matches, key), expected)
    assert_eq(get_cli_value(parsed, "config"), "release.json")
  }
  for
    name in [
      "init", "version", "generate-schema", "release", "release-pr", "update",
    ] {
    assert_eq(create_parser().parse(argv=[name]).subcommand.unwrap().0, name)
  }
}

///|
test "invalid commands and missing option values cannot reach release operations" {
  for
    argv in [
      ["unknown"],
      ["set-version"],
      ["set-version", "1.0.0", "extra"],
      ["generate-completions"],
      ["release", "--unknown"],
      ["release", "--bump"],
      ["release", "--prerelease"],
      ["check", "--config"],
    ] {
    try ignore(create_parser().parse(argv=argv[:])) catch {
      _ => ()
    } noraise {
      _ => fail("Expected invalid arguments to be rejected: " + argv.join(" "))
    }
  }
}
