/// Truncates [dateTime] to midnight (year/month/day only), dropping the
/// time-of-day component. Useful for day-based comparisons such as
/// "how many days ahead is this?".
DateTime dateOnly(DateTime dateTime) =>
    DateTime(dateTime.year, dateTime.month, dateTime.day);
