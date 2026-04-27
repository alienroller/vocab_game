/// Date helpers shared by streak and week-reset logic.
///
/// These are pure functions — no Hive, no I/O, fully unit-testable.
class AppDateUtils {
  const AppDateUtils._();

  /// Returns an ISO-8601 week key (e.g. "2026-W15") for [date].
  ///
  /// The week is anchored to the year of its Thursday, matching the behaviour
  /// of Postgres' `extract(week from ...)` used on the backend. Using this
  /// key instead of the local-date Monday means DST changes and timezone
  /// hops can't double-trigger or skip a weekly reset.
  static String isoWeekKey(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final jan4 = DateTime(thursday.year, 1, 4);
    final week1Thursday = jan4.add(Duration(days: 4 - jan4.weekday));
    final weekNumber =
        1 + (thursday.difference(week1Thursday).inDays / 7).floor();
    return '${thursday.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  /// Returns `yyyy-MM-dd` for [date] — used as the `lastPlayedDate` Hive key.
  static String ymd(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
