component output=false {

  variables.formatName = "pbkdf2-sha256";
  variables.algorithm = "PBKDF2WithHmacSHA256";
  variables.iterations = 600000;
  variables.saltBits = 128;
  variables.keyBits = 256;
  variables.minimumAcceptedIterations = 100000;
  variables.maximumAcceptedIterations = 2000000;

  public any function init() {
    return this;
  }

  public string function hashPassword(required string plainPassword) {
    if (!len(arguments.plainPassword)) {
      throw(
        type = "FPW.PasswordHash.EmptyPassword",
        message = "A non-empty password is required."
      );
    }

    var salt = generateSecretKey("AES", variables.saltBits);
    var derivedKey = generatePBKDFKey(
      variables.algorithm,
      arguments.plainPassword,
      salt,
      variables.iterations,
      variables.keyBits
    );

    return "$" & variables.formatName
      & "$i=" & variables.iterations & ",l=" & variables.keyBits
      & "$" & salt
      & "$" & derivedKey;
  }

  public boolean function verifyPassword(
    required string plainPassword,
    required string storedPassword
  ) {
    var format = detectPasswordFormat(arguments.storedPassword);

    if (format == "ADAPTIVE") {
      return verifyAdaptivePassword(arguments.plainPassword, arguments.storedPassword);
    }

    if (format == "LEGACY_SHA256") {
      return verifyLegacySha256(arguments.plainPassword, arguments.storedPassword);
    }

    return false;
  }

  public string function detectPasswordFormat(required string storedPassword) {
    var stored = toString(arguments.storedPassword);

    if (
      reFind(
        "^\$pbkdf2-sha256\$i=[1-9][0-9]*,l=[1-9][0-9]*\$[A-Za-z0-9+/]+={0,2}\$[A-Za-z0-9+/]+={0,2}$",
        stored
      ) == 1
    ) {
      return "ADAPTIVE";
    }

    if (reFindNoCase("^[0-9a-f]{64}$", stored) == 1) {
      return "LEGACY_SHA256";
    }

    return "LEGACY_PLAINTEXT_OR_UNKNOWN";
  }

  public boolean function needsRehash(required string storedPassword) {
    if (detectPasswordFormat(arguments.storedPassword) != "ADAPTIVE") {
      return true;
    }

    var parsed = parseAdaptiveHash(arguments.storedPassword);
    return !parsed.valid
      || parsed.iterations != variables.iterations
      || parsed.keyBits != variables.keyBits;
  }

  public boolean function verifyLegacySha256(
    required string plainPassword,
    required string storedPassword
  ) {
    if (detectPasswordFormat(arguments.storedPassword) != "LEGACY_SHA256") {
      return false;
    }

    try {
      return secureBinaryEquals(
        binaryDecode(hash(arguments.plainPassword, "SHA-256", "UTF-8"), "hex"),
        binaryDecode(arguments.storedPassword, "hex")
      );
    } catch (any ignored) {
      return false;
    }
  }

  public struct function getConfiguration() {
    return {
      algorithm = variables.algorithm,
      format = variables.formatName,
      iterations = variables.iterations,
      saltBits = variables.saltBits,
      keyBits = variables.keyBits
    };
  }

  private boolean function verifyAdaptivePassword(
    required string plainPassword,
    required string storedPassword
  ) {
    var parsed = parseAdaptiveHash(arguments.storedPassword);
    if (!parsed.valid) {
      return false;
    }

    try {
      var calculated = generatePBKDFKey(
        variables.algorithm,
        arguments.plainPassword,
        parsed.salt,
        parsed.iterations,
        parsed.keyBits
      );

      return secureBinaryEquals(
        binaryDecode(calculated, "base64"),
        binaryDecode(parsed.derivedKey, "base64")
      );
    } catch (any ignored) {
      return false;
    }
  }

  private struct function parseAdaptiveHash(required string storedPassword) {
    var result = {
      valid = false,
      iterations = 0,
      keyBits = 0,
      salt = "",
      derivedKey = ""
    };

    if (detectPasswordFormat(arguments.storedPassword) != "ADAPTIVE") {
      return result;
    }

    try {
      var parts = listToArray(arguments.storedPassword, "$");
      if (arrayLen(parts) != 4 || parts[1] != variables.formatName) {
        return result;
      }

      var settings = listToArray(parts[2], ",");
      if (
        arrayLen(settings) != 2
        || listFirst(settings[1], "=") != "i"
        || listFirst(settings[2], "=") != "l"
      ) {
        return result;
      }

      result.iterations = val(listLast(settings[1], "="));
      result.keyBits = val(listLast(settings[2], "="));
      result.salt = parts[3];
      result.derivedKey = parts[4];

      if (
        result.iterations < variables.minimumAcceptedIterations
        || result.iterations > variables.maximumAcceptedIterations
        || result.keyBits != variables.keyBits
      ) {
        return result;
      }

      binaryDecode(result.salt, "base64");
      binaryDecode(result.derivedKey, "base64");
      result.valid = true;
      return result;
    } catch (any ignored) {
      return result;
    }
  }

  private boolean function secureBinaryEquals(required any leftValue, required any rightValue) {
    return createObject("java", "java.security.MessageDigest").isEqual(
      arguments.leftValue,
      arguments.rightValue
    );
  }
}
