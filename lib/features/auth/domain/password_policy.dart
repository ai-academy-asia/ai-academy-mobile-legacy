/// The five rules a new password has to satisfy, and how to check them.
///
/// Pure Dart with no Flutter import, so the rules can be tested directly and
/// reused anywhere a password is set — the reset screen is simply the first
/// caller. The wording lives with the screen; this file only decides pass or
/// fail.
enum PasswordRequirement {
  /// At least [PasswordPolicy.minLength] characters.
  minLength,

  /// At least one A–Z.
  uppercase,

  /// At least one a–z.
  lowercase,

  /// At least one 0–9.
  digit,

  /// At least one character that is none of the above.
  special,
}

abstract final class PasswordPolicy {
  /// The reference's first rule reads "8 ба түүнээс дээш тэмдэгт ашиглах".
  static const int minLength = 8;

  /// Every rule, in the order the design lists them.
  static const List<PasswordRequirement> all = PasswordRequirement.values;

  static final RegExp _uppercase = RegExp('[A-Z]');
  static final RegExp _lowercase = RegExp('[a-z]');
  static final RegExp _digit = RegExp('[0-9]');

  /// Anything that is not a letter, a digit or whitespace. Deliberately not a
  /// fixed list of punctuation: a password should not be rejected for using a
  /// symbol nobody thought to enumerate.
  static final RegExp _special = RegExp(r'[^A-Za-z0-9\s]');

  static bool isSatisfied(PasswordRequirement requirement, String password) =>
      switch (requirement) {
        PasswordRequirement.minLength => password.length >= minLength,
        PasswordRequirement.uppercase => _uppercase.hasMatch(password),
        PasswordRequirement.lowercase => _lowercase.hasMatch(password),
        PasswordRequirement.digit => _digit.hasMatch(password),
        PasswordRequirement.special => _special.hasMatch(password),
      };

  /// The rules [password] currently passes.
  static Set<PasswordRequirement> satisfiedBy(String password) => {
    for (final requirement in all)
      if (isSatisfied(requirement, password)) requirement,
  };

  /// How many of the five rules [password] passes, 0–5.
  static int satisfiedCount(String password) => satisfiedBy(password).length;

  /// True only when every rule passes.
  static bool isAcceptable(String password) => satisfiedCount(password) == all.length;

  /// Progress for the strength meter, 0.0–1.0.
  static double strength(String password) => satisfiedCount(password) / all.length;
}
