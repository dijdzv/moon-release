test "parse simple version" {
  let result = Version::parse("1.2.3")
  match result {
    Some(v) => {
      assert_eq(v.major, 1)
      assert_eq(v.minor, 2)
      assert_eq(v.patch, 3)
      assert_eq(v.prerelease, None)
      assert_eq(v.build_metadata, None)
    }
    None => fail("Expected Some, got None")
  }
}

test "parse version with prerelease" {
  let result = Version::parse("1.2.3-alpha.1")
  match result {
    Some(v) => {
      assert_eq(v.major, 1)
      assert_eq(v.minor, 2)
      assert_eq(v.patch, 3)
      assert_eq(v.prerelease, Some("alpha.1"))
      assert_eq(v.build_metadata, None)
    }
    None => fail("Expected Some, got None")
  }
}

test "parse version with build metadata" {
  let result = Version::parse("1.2.3+build.123")
  match result {
    Some(v) => {
      assert_eq(v.major, 1)
      assert_eq(v.minor, 2)
      assert_eq(v.patch, 3)
      assert_eq(v.prerelease, None)
      assert_eq(v.build_metadata, Some("build.123"))
    }
    None => fail("Expected Some, got None")
  }
}

test "parse version with prerelease and build metadata" {
  let result = Version::parse("1.2.3-beta.2+build.456")
  match result {
    Some(v) => {
      assert_eq(v.major, 1)
      assert_eq(v.minor, 2)
      assert_eq(v.patch, 3)
      assert_eq(v.prerelease, Some("beta.2"))
      assert_eq(v.build_metadata, Some("build.456"))
    }
    None => fail("Expected Some, got None")
  }
}

test "parse version 0.0.1" {
  let result = Version::parse("0.0.1")
  match result {
    Some(v) => {
      assert_eq(v.major, 0)
      assert_eq(v.minor, 0)
      assert_eq(v.patch, 1)
    }
    None => fail("Expected Some, got None")
  }
}

test "parse invalid - empty" {
  assert_eq(Version::parse(""), None)
}

test "parse invalid - only major" {
  assert_eq(Version::parse("1"), None)
}

test "parse invalid - only major.minor" {
  assert_eq(Version::parse("1.2"), None)
}

test "parse invalid - non-numeric" {
  assert_eq(Version::parse("1.2.x"), None)
}

test "version to_string" {
  let v = Version::{ major: 1, minor: 2, patch: 3, prerelease: None, build_metadata: None }
  assert_eq(v.to_string(), "1.2.3")
}

test "version to_string with prerelease" {
  let v = Version::{ major: 1, minor: 2, patch: 3, prerelease: Some("alpha"), build_metadata: None }
  assert_eq(v.to_string(), "1.2.3-alpha")
}

test "version to_string with build metadata" {
  let v = Version::{ major: 1, minor: 2, patch: 3, prerelease: None, build_metadata: Some("build") }
  assert_eq(v.to_string(), "1.2.3+build")
}

test "version compare" {
  let v1 = Version::{ major: 1, minor: 0, patch: 0, prerelease: None, build_metadata: None }
  let v2 = Version::{ major: 2, minor: 0, patch: 0, prerelease: None, build_metadata: None }
  let v3 = Version::{ major: 1, minor: 1, patch: 0, prerelease: None, build_metadata: None }
  let v4 = Version::{ major: 1, minor: 0, patch: 1, prerelease: None, build_metadata: None }

  assert_true(v1.compare(v2) < 0)
  assert_true(v2.compare(v1) > 0)
  assert_true(v1.compare(v3) < 0)
  assert_true(v1.compare(v4) < 0)
  assert_true(v1.compare(v1) == 0)
}

test "version compare with prerelease" {
  // 1.0.0-alpha < 1.0.0
  let alpha = Version::{ major: 1, minor: 0, patch: 0, prerelease: Some("alpha"), build_metadata: None }
  let release = Version::{ major: 1, minor: 0, patch: 0, prerelease: None, build_metadata: None }

  assert_true(alpha.compare(release) < 0)
  assert_true(release.compare(alpha) > 0)
}

test "version compare prerelease order" {
  // SemVer 2.0.0: 1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0
  let alpha = Version::{ major: 1, minor: 0, patch: 0, prerelease: Some("alpha"), build_metadata: None }
  let alpha1 = Version::{ major: 1, minor: 0, patch: 0, prerelease: Some("alpha.1"), build_metadata: None }
  let alpha_beta = Version::{ major: 1, minor: 0, patch: 0, prerelease: Some("alpha.beta"), build_metadata: None }
  let beta = Version::{ major: 1, minor: 0, patch: 0, prerelease: Some("beta"), build_metadata: None }
  let beta2 = Version::{ major: 1, minor: 0, patch: 0, prerelease: Some("beta.2"), build_metadata: None }
  let beta11 = Version::{ major: 1, minor: 0, patch: 0, prerelease: Some("beta.11"), build_metadata: None }
  let rc1 = Version::{ major: 1, minor: 0, patch: 0, prerelease: Some("rc.1"), build_metadata: None }
  let release = Version::{ major: 1, minor: 0, patch: 0, prerelease: None, build_metadata: None }

  assert_true(alpha.compare(alpha1) < 0)
  assert_true(alpha1.compare(alpha_beta) < 0)
  assert_true(alpha_beta.compare(beta) < 0)
  assert_true(beta.compare(beta2) < 0)
  assert_true(beta2.compare(beta11) < 0)
  assert_true(beta11.compare(rc1) < 0)
  assert_true(rc1.compare(release) < 0)
}

test "version compare prerelease numeric vs string" {
  // Numeric parts are compared as numbers (2 < 11)
  let v2 = Version::{ major: 1, minor: 0, patch: 0, prerelease: Some("beta.2"), build_metadata: None }
  let v11 = Version::{ major: 1, minor: 0, patch: 0, prerelease: Some("beta.11"), build_metadata: None }

  assert_true(v2.compare(v11) < 0)
}

test "version compare build metadata ignored" {
  // Build metadata does not affect comparison
  let v1 = Version::{ major: 1, minor: 0, patch: 0, prerelease: None, build_metadata: Some("build.1") }
  let v2 = Version::{ major: 1, minor: 0, patch: 0, prerelease: None, build_metadata: Some("build.999") }

  assert_true(v1.compare(v2) == 0)
}

// prerelease validation tests
test "validate_prerelease - valid alpha" {
  assert_true(validate_prerelease("alpha"))
}

test "validate_prerelease - valid alpha.1" {
  assert_true(validate_prerelease("alpha.1"))
}

test "validate_prerelease - valid rc.1" {
  assert_true(validate_prerelease("rc.1"))
}

test "validate_prerelease - valid beta.2.3" {
  assert_true(validate_prerelease("beta.2.3"))
}

test "validate_prerelease - valid with hyphen" {
  assert_true(validate_prerelease("pre-release"))
}

test "validate_prerelease - valid numeric 0" {
  assert_true(validate_prerelease("0"))
}

test "validate_prerelease - valid numeric 123" {
  assert_true(validate_prerelease("123"))
}

test "validate_prerelease - invalid empty" {
  assert_false(validate_prerelease(""))
}

test "validate_prerelease - invalid leading zero" {
  assert_false(validate_prerelease("01"))
}

test "validate_prerelease - invalid empty identifier" {
  assert_false(validate_prerelease("alpha..beta"))
}

test "validate_prerelease - invalid trailing dot" {
  assert_false(validate_prerelease("alpha."))
}

test "validate_prerelease - invalid leading dot" {
  assert_false(validate_prerelease(".alpha"))
}

test "validate_prerelease - invalid underscore" {
  assert_false(validate_prerelease("alpha_1"))
}

test "validate_prerelease - invalid space" {
  assert_false(validate_prerelease("alpha 1"))
}

test "validate_prerelease - invalid plus" {
  assert_false(validate_prerelease("alpha+1"))
}

// Integer overflow protection tests
test "parse version - large but valid numbers" {
  // Numbers within 9 digits are allowed (max 999,999,999)
  let result = Version::parse("999999999.0.0")
  match result {
    Some(v) => assert_eq(v.major, 999999999)
    None => fail("Should parse valid large number")
  }
}

test "parse version - number too large (10 digits)" {
  // Reject 10+ digits (overflow prevention)
  assert_eq(Version::parse("1234567890.0.0"), None)
}

test "parse version - overflow protection" {
  // 10 digits always rejected
  assert_eq(Version::parse("9999999999.0.0"), None)
}

test "parse version - 8 digit boundary" {
  // 8 digits are valid
  let result = Version::parse("12345678.0.0")
  match result {
    Some(v) => assert_eq(v.major, 12345678)
    None => fail("Should parse valid 8-digit number")
  }
}

test "parse version - exactly 9 digits" {
  // 9 digits is the maximum allowed
  let result = Version::parse("100000000.0.0")
  match result {
    Some(v) => assert_eq(v.major, 100000000)
    None => fail("Should parse valid 9-digit number")
  }
}

test "parse version - all components at boundary" {
  // Test all components with large values
  let result = Version::parse("999999999.999999999.999999999")
  match result {
    Some(v) => {
      assert_eq(v.major, 999999999)
      assert_eq(v.minor, 999999999)
      assert_eq(v.patch, 999999999)
    }
    None => fail("Should parse valid large version")
  }
}

test "parse version - leading zeros rejected per SemVer 2.0.0" {
  // SemVer 2.0.0 spec forbids leading zeros in numeric identifiers
  assert_eq(Version::parse("01.0.0"), None)
  assert_eq(Version::parse("0.01.0"), None)
  assert_eq(Version::parse("0.0.01"), None)
  assert_eq(Version::parse("007.0.0"), None)
}

test "parse version - valid zeros" {
  // Single zeros are valid
  let result = Version::parse("0.0.0")
  match result {
    Some(v) => {
      assert_eq(v.major, 0)
      assert_eq(v.minor, 0)
      assert_eq(v.patch, 0)
    }
    None => fail("Should parse 0.0.0")
  }
}

test "parse rejects empty prerelease" {
  assert_true(Version::parse("1.2.3-") is None)
}

test "parse rejects empty build metadata" {
  assert_true(Version::parse("1.2.3+") is None)
}

test "parse rejects empty prerelease with build metadata" {
  assert_true(Version::parse("1.2.3-+build") is None)
}

test "with_prerelease sets prerelease" {
  let v = Version::parse("1.2.3").unwrap()
  match v.with_prerelease("alpha.1") {
    Some(vp) => {
      assert_eq(vp.major, 1)
      assert_eq(vp.minor, 2)
      assert_eq(vp.patch, 3)
      assert_eq(vp.prerelease, Some("alpha.1"))
    }
    None => fail("Expected Some, got None")
  }
}

test "with_prerelease preserves build metadata" {
  let v = Version::parse("1.2.3+build.42").unwrap()
  match v.with_prerelease("rc.1") {
    Some(vp) => {
      assert_eq(vp.prerelease, Some("rc.1"))
      assert_eq(vp.build_metadata, Some("build.42"))
    }
    None => fail("Expected Some, got None")
  }
}

test "with_prerelease rejects invalid prerelease" {
  let v = Version::parse("1.2.3").unwrap()
  assert_true(v.with_prerelease("") is None)
  assert_true(v.with_prerelease("alpha_1") is None)
  assert_true(v.with_prerelease("01") is None)
}

test "validate_build_metadata - valid" {
  assert_true(validate_build_metadata("build"))
  assert_true(validate_build_metadata("build.123"))
  assert_true(validate_build_metadata("001"))  // leading zeros allowed
}

test "validate_build_metadata - invalid empty" {
  assert_false(validate_build_metadata(""))
}

test "validate_build_metadata - invalid empty identifier" {
  assert_false(validate_build_metadata("build..123"))
}

test "validate_build_metadata - invalid characters" {
  assert_false(validate_build_metadata("build+1"))
  assert_false(validate_build_metadata("build_1"))
}
