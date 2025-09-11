/// Validadores básicos para la aplicación

class Validators {
  /// Valida formato de email
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// Valida formato de teléfono
  static bool isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{7,15}$');
    return phoneRegex.hasMatch(phone);
  }

  /// Valida que el texto no esté vacío
  static bool isNotEmpty(String text) {
    return text.trim().isNotEmpty;
  }

  /// Valida longitud mínima de texto
  static bool hasMinLength(String text, int minLength) {
    return text.trim().length >= minLength;
  }

  /// Valida longitud máxima de texto
  static bool hasMaxLength(String text, int maxLength) {
    return text.trim().length <= maxLength;
  }

  /// Valida que el texto tenga longitud específica
  static bool hasExactLength(String text, int length) {
    return text.trim().length == length;
  }

  /// Valida que el número sea positivo
  static bool isPositiveNumber(num number) {
    return number > 0;
  }

  /// Valida que el número esté en rango
  static bool isInRange(num number, num min, num max) {
    return number >= min && number <= max;
  }

  /// Valida formato de URL
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Valida que el texto contenga solo números
  static bool isNumeric(String text) {
    final numericRegex = RegExp(r'^\d+$');
    return numericRegex.hasMatch(text);
  }

  /// Valida que el texto contenga solo letras
  static bool isAlphabetic(String text) {
    final alphabeticRegex = RegExp(r'^[a-zA-Z\s]+$');
    return alphabeticRegex.hasMatch(text);
  }
}
