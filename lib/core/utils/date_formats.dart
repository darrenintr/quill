import 'package:intl/intl.dart';

/// Friendly relative-time helper used in note lists.
String formatRelativeTime(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) {
    final weeks = (diff.inDays / 7).floor();
    return '${weeks}w ago';
  }
  if (now.year == time.year) {
    return DateFormat('MMM d').format(time);
  }
  return DateFormat('MMM d, yyyy').format(time);
}

/// Compact title for the home dashboard ("Tuesday, Aug 12").
String formatLongDate(DateTime time) => DateFormat('EEEE, MMM d').format(time);

/// "Aug 12, 2026 · 3:42 PM" used in note metadata.
String formatFullDateTime(DateTime time) =>
    DateFormat('MMM d, yyyy · h:mm a').format(time);