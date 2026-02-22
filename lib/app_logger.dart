import 'package:logger/logger.dart';

class AppLogger extends PrettyPrinter{
  final String className;
  final String correlationId;

  AppLogger(this.className, this.correlationId);

  @override
  List<String> log(LogEvent event) {
    //final color = PrettyPrinter.defaultLevelColors[event.level];
    final emoji = PrettyPrinter.defaultLevelEmojis[event.level];
    final message = event.message;
    final error = event.error;
    final stackTrace = event.stackTrace;

    /*AnsiPen pen = new AnsiPen();
    pen.red();

    print(pen("$message"));*/

    final buffer = StringBuffer('[$correlationId]: $emoji: $className: $message');
    if (error != null) {
      buffer.write('\nerror: $error');
    }
    if (stackTrace != null) {
      buffer.write('\nstackTrace: $stackTrace');
    }

    return [buffer.toString()];

  }
}