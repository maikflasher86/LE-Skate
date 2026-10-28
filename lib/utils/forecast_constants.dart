/// Shared constants of the forecast pipeline (Open-Meteo and DWD).
library;

/// Precipitation strictly above this amount (mm per hour) counts as rain.
const double rainThresholdMm = 0.1;

/// Period before training start in which rain matters (asphalt drying).
const Duration preTrainingWindow = Duration(hours: 4);

/// Look-back period for the rain history and the last rain event.
const Duration rainHistoryWindow = Duration(hours: 24);

/// Maximum number of upcoming sessions considered for the forecast.
const int maxForecastSessions = 14;

/// How many days ahead upcoming sessions and one-time events are looked up.
const int sessionLookaheadDays = 28;

/// Maximum Open-Meteo `forecast_days` (free-tier limit).
const int maxForecastDays = 8;
