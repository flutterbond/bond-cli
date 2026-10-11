import 'package:pub_semver/pub_semver.dart';

/// One `## <version>` section of a CHANGELOG.md.
class ChangelogSection {
  const ChangelogSection(this.version, this.text);

  final String version;

  /// The section including its heading.
  final String text;
}

final _heading = RegExp(r'^##\s+\[?v?(\d+\.\d+\.\d+[^\s\]]*)', multiLine: true);

/// The version sections of [markdown], in file order (newest first by
/// convention).
List<ChangelogSection> parseChangelog(String markdown) {
  final matches = _heading.allMatches(markdown).toList();
  return [
    for (var i = 0; i < matches.length; i++)
      ChangelogSection(
        matches[i].group(1)!,
        markdown
            .substring(
              matches[i].start,
              i + 1 < matches.length ? matches[i + 1].start : markdown.length,
            )
            .trim(),
      ),
  ];
}

/// The first [count] sections of [markdown].
List<ChangelogSection> latestSections(String markdown, int count) =>
    parseChangelog(markdown).take(count).toList();

/// The sections newer than [from] (exclusive) up to [to] (inclusive). Missing
/// bounds are open; sections whose version can't be parsed are skipped.
List<ChangelogSection> sectionsBetween(
  String markdown, {
  String? from,
  String? to,
}) {
  final lower = from == null ? null : Version.parse(from);
  final upper = to == null ? null : Version.parse(to);
  return [
    for (final section in parseChangelog(markdown))
      if (_inRange(section.version, lower, upper)) section,
  ];
}

bool _inRange(String version, Version? lower, Version? upper) {
  final Version parsed;
  try {
    parsed = Version.parse(version);
  } on FormatException {
    return false;
  }
  if (lower != null && parsed <= lower) return false;
  if (upper != null && parsed > upper) return false;
  return true;
}
