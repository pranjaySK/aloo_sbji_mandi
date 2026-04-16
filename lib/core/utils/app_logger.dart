import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: _AppLogPrinter(),
    level: kReleaseMode ? Level.warning : Level.debug,
  );

  static void trace(String message, {String tag = 'TRACE', Object? data}) {
    _logger.t(_LogEntry(tag: tag, message: message, data: data));
  }

  static void debug(String message, {String tag = 'DEBUG', Object? data}) {
    _logger.d(_LogEntry(tag: tag, message: message, data: data));
  }

  static void info(String message, {String tag = 'INFO', Object? data}) {
    _logger.i(_LogEntry(tag: tag, message: message, data: data));
  }

  static void success(String message, {String tag = 'SUCCESS', Object? data}) {
    _logger.i(_LogEntry(tag: tag, message: message, data: data));
  }

  static void warning(String message, {String tag = 'WARNING', Object? data}) {
    _logger.w(_LogEntry(tag: tag, message: message, data: data));
  }

  static void error(
    String message, {
    String tag = 'ERROR',
    Object? error,
    StackTrace? stackTrace,
    Object? data,
  }) {
    _logger.e(
      _LogEntry(tag: tag, message: message, data: data ?? error),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void request(
    String method,
    String url, {
    Map<String, dynamic>? headers,
    Object? query,
    Object? body,
    String tag = 'REQUEST',
  }) {
    _logger.i(
      _LogEntry(
        tag: tag,
        message: '$method $url',
        data: _buildRequestData(headers: headers, query: query, body: body),
      ),
    );
  }

  static void response(
    String method,
    String url, {
    required int statusCode,
    Object? data,
    Duration? duration,
    String tag = 'RESPONSE',
  }) {
    final suffix = duration == null ? '' : ' (${duration.inMilliseconds}ms)';
    _logger.i(
      _LogEntry(
        tag: tag,
        message: '$method $url -> $statusCode$suffix',
        data: data,
      ),
    );
  }

  static void networkError(
    String method,
    String url, {
    Object? error,
    StackTrace? stackTrace,
    Object? data,
    String tag = 'NETWORK_ERROR',
  }) {
    _logger.e(
      _LogEntry(
        tag: tag,
        message: '$method $url failed',
        data: data,
      ),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static Map<String, dynamic> _buildRequestData({
    Map<String, dynamic>? headers,
    Object? query,
    Object? body,
  }) {
    final data = <String, dynamic>{};

    if (headers != null && headers.isNotEmpty) {
      data['headers'] = headers;
    }
    if (query != null) {
      data['query'] = query;
    }
    if (body != null) {
      data['body'] = body;
    }

    return data;
  }
}

class _LogEntry {
  const _LogEntry({
    required this.tag,
    required this.message,
    this.data,
  });

  final String tag;
  final String message;
  final Object? data;
}

class _AppLogPrinter extends LogPrinter {
  static const String _reset = '\x1B[0m';
  static const String _bold = '\x1B[1m';
  static const String _grey = '\x1B[38;5;244m';
  static const String _blue = '\x1B[38;5;39m';
  static const String _cyan = '\x1B[38;5;44m';
  static const String _green = '\x1B[38;5;46m';
  static const String _yellow = '\x1B[38;5;220m';
  static const String _red = '\x1B[38;5;196m';
  static const String _pink = '\x1B[38;5;213m';

  @override
  List<String> log(LogEvent event) {
    final now = DateTime.now().toIso8601String();
    final message = event.message;

    if (message is! _LogEntry) {
      return ['$now ${event.level.name.toUpperCase()} ${message.toString()}'];
    }

    final color = _colorFor(message.tag, event.level);
    final lines = <String>[
      '$color$_bold[$now] [${message.tag}]$_reset ${message.message}',
    ];

    if (message.data != null) {
      final formatted = _formatData(message.data);
      for (final line in formatted.split('\n')) {
        lines.add('$_grey$line$_reset');
      }
    }

    if (event.error != null) {
      lines.add('$_red${event.error}$_reset');
    }

    if (event.stackTrace != null) {
      final traceLines = event.stackTrace.toString().trim().split('\n');
      for (final line in traceLines.take(8)) {
        lines.add('$_pink$line$_reset');
      }
    }

    return lines;
  }

  String _colorFor(String tag, Level level) {
    final upperTag = tag.toUpperCase();

    if (upperTag.contains('REQUEST')) return _blue;
    if (upperTag.contains('RESPONSE')) return _green;
    if (upperTag.contains('SUCCESS')) return _green;
    if (upperTag.contains('WARNING')) return _yellow;
    if (upperTag.contains('ERROR')) return _red;
    if (upperTag.contains('SOCKET')) return _cyan;
    if (upperTag.contains('AUTH')) return _pink;

    if (level == Level.trace) return _grey;
    if (level == Level.debug) return _cyan;
    if (level == Level.info) return _green;
    if (level == Level.warning) return _yellow;
    if (level == Level.error || level == Level.fatal) return _red;
    return _grey;
  }

  String _formatData(Object? data) {
    if (data == null) return '';

    if (data is String) {
      return data;
    }

    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    } catch (_) {
      return data.toString();
    }
  }
}
