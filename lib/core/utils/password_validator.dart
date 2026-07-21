class PasswordValidator {
  static bool hasMinLength(String password) {
    return password.length >= 8;
  }

  static bool hasUppercase(String password) {
    return RegExp(r'[A-Z]').hasMatch(password);
  }

  static bool hasLowercase(String password) {
    return RegExp(r'[a-z]').hasMatch(password);
  }

  static bool hasNumber(String password) {
    return RegExp(r'\d').hasMatch(password);
  }

  static bool hasSpecialCharacter(String password) {
    return RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
  }

  static bool isValid(String password) {
    return hasMinLength(password) &&
        hasUppercase(password) &&
        hasLowercase(password) &&
        hasNumber(password) &&
        hasSpecialCharacter(password);
  }
  static int strength(String password) {
  int score = 0;

  if (hasMinLength(password)) score++;
  if (hasUppercase(password)) score++;
  if (hasLowercase(password)) score++;
  if (hasNumber(password)) score++;
  if (hasSpecialCharacter(password)) score++;

  return score;
}

static String strengthText(String password) {
  final score = strength(password);

  if (score <= 2) return 'Weak';
  if (score == 3) return 'Fair';
  if (score == 4) return 'Good';
  return 'Strong';
}

static double strengthPercent(String password) {
  return strength(password) / 5;
}
}