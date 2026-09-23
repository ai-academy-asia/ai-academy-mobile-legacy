/// Turns an arbitrary decoded JSON value into readable lines of text.
///
/// Exists for API fields whose *name* is confirmed but whose *shape* is not —
/// `GET /courses/{slug}` confirms `curriculum`, `instructors`, `prerequisites`
/// and `whats_included` exist, but no example response was ever given, so
/// there is no evidence for what a course's curriculum actually looks like on
/// the wire: a flat list of strings? A list of `{week, topic}` objects? A
/// single block of text?
///
/// Guessing one specific shape and asserting it — the way `id` or `slug` are
/// read elsewhere — would mean inventing a contract this feature was
/// explicitly told not to invent. This instead makes no assumption about
/// structure at all: it walks whatever came back and renders it, so it is
/// correct for *any* JSON shape the field turns out to have, at the cost of
/// not knowing which line means what. Replace a field's use of this with a
/// typed reader once a real response settles its shape.
library;

/// Flattens [value] into one line of display text per leaf, in order.
/// Returns an empty list for `null`, an empty string, an empty list, or an
/// empty map — i.e. exactly the inputs a caller should treat as "nothing to
/// show".
List<String> describeJsonLines(Object? value) {
  final lines = <String>[];
  _describeInto(value, lines);
  return lines;
}

void _describeInto(Object? value, List<String> lines, {String prefix = ''}) {
  switch (value) {
    case null:
      return;
    case String s:
      final trimmed = s.trim();
      if (trimmed.isNotEmpty) lines.add(prefix.isEmpty ? trimmed : '$prefix$trimmed');
    case num n:
      lines.add('$prefix$n');
    case bool b:
      lines.add('$prefix$b');
    case List list:
      for (final item in list) {
        _describeInto(item, lines, prefix: prefix);
      }
    case Map map:
      for (final entry in map.entries) {
        _describeInto(entry.value, lines, prefix: '${entry.key}: ');
      }
    default:
      // Nothing else `jsonDecode` produces, but a value from a source this
      // client does not control is not proven to stay that way.
      lines.add('$prefix$value');
  }
}

/// [value] read as Mongolian-preferred bilingual text, for a field suspected
/// (not confirmed) of following the same `{"en": ..., "mn": ...}` shape
/// already confirmed on `Course.title` and `Course.tagline` — plausible for
/// `description` on the same resource, but nothing says it must.
///
/// Returns null when [value] is not a map holding a non-empty `en` or `mn`
/// string, so a caller can fall back to [describeJsonLines] for whatever the
/// value actually turns out to be instead of showing nothing.
String? preferMongolianText(Object? value) {
  if (value is! Map) return null;
  final mn = value['mn'];
  if (mn is String && mn.trim().isNotEmpty) return mn.trim();
  final en = value['en'];
  if (en is String && en.trim().isNotEmpty) return en.trim();
  return null;
}
