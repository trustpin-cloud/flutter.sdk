/// Use-case-facing log sink. Concrete implementations route lines to the UI
/// log feed, the OS logger, or both.
abstract interface class Logger {
  void info(String message);

  void success(String message);

  void warning(String message);

  void error(String message);

  void debug(String message);
}
