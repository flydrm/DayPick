({String text, String? route}) stripInlineRouteToken(String raw) {
  final match = RegExp(r'\[\[route:([^\]]+)\]\]').firstMatch(raw);
  if (match == null) return (text: raw, route: null);

  final route = match.group(1)?.trim();
  if (route == null || route.isEmpty) return (text: raw, route: null);
  if (!route.startsWith('/')) return (text: raw, route: null);

  final without = raw.replaceFirst(RegExp(r'\s*\[\[route:[^\]]+\]\]'), '');
  return (text: without.trimRight(), route: route);
}
