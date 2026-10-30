import 'package:inliner2/models/location.dart';
import 'package:inliner2/models/training_course.dart';

/// Classifies a training session.
///
/// - [regular]: regular session (core program)
/// - [alternative]: alternative session (only visible if toggle is active)
/// - [special]: special session with its own category (e.g. Cossi Training)
enum TrainingCategory { regular, alternative, special }

/// Describes in which calendar weeks a weekday is considered "regular".
enum WeekParity { any, odd, even }

// ---------------------------------------------------------------------------
// Locations
// ---------------------------------------------------------------------------

// --- Summer training locations ---------------------------------------------

const cossiLocation = Location(
  lat: 51.2858270307334,
  lon: 12.345881282832073,
  label: 'Cossi',
);

const moeckernTrackLocation = Location(
  lat: 51.3720365653869,
  lon: 12.343817084568474,
  label: 'Bahn Möckern',
);

// --- Winter training locations ---------------------------------------------

/// Outdoor training location at Landauer Brücke (winter Tuesday).
const landauerBrueckeLocation = Location(
  lat: 51.33636,
  lon: 12.37212,
  label: 'Landauer Brücke',
);

/// Indoor hall for winter Saturday training.
const sporthalleEvsLocation = Location(
  lat: 51.33499,
  lon: 12.37985,
  label: 'Evangelisches Schulzentrum (EvaSchulze)',
);

/// Indoor hall "Rabet" for winter Monday training.
const sporthalleRabetLocation = Location(
  lat: 51.3444,
  lon: 12.4046,
  label: 'TH "Am Rabet"',
);

/// Outdoor stair training at the Völki
const voelkiLocation = Location(lat: 51.3138, lon: 12.4135, label: 'Völki');

/// Indoor strength room at the RR-Bahn (winter).
const kraftraumRrBahnLocation = Location(
  lat: 51.3122137,
  lon: 12.3282271,
  label: 'Kraftraum RR-Bahn',
);

// --- One-time event locations ----------------------------------------------

const porscheLocation = Location(
  lat: 51.40619918755847,
  lon: 12.2973937917706,
  label: 'Porsche',
);

// ---------------------------------------------------------------------------
// Weekly schedule
// ---------------------------------------------------------------------------

/// The recurring training on one weekday of a season's schedule.
typedef ScheduleEntry = ({
  String trainingName,
  int startHour,
  int startMinute,
  int endHour,
  int endMinute,
  Location location,
  TrainingCategory category,

  /// In which weeks [category] applies (default: any).
  /// Used for [TrainingCategory.regular]: Outside this parity,
  /// the appointment is automatically treated as [TrainingCategory.alternative].
  WeekParity regularParity,

  /// Optional badge label shown in the training-day planner UI.
  String? badgeLabel,

  /// How many days ahead weather data is needed for this weekday.
  /// Used to limit API requests (e.g. 1 for Cossi = only today needed).
  int forecastDays,

  /// Whether this training happens indoors (e.g. sports hall), in which
  /// case weather has no bearing on the training and is not fetched or
  /// evaluated at all. Course details can still be shown.
  bool isIndoor,
  bool requiresRegistration,
  List<TrainingCourse> courses,
});

/// Summer training data per weekday (April–last Monday of October).
const Map<int, ScheduleEntry> summerSchedule = {
  1: (
    // Monday
    trainingName: 'Cossi',
    startHour: 18,
    startMinute: 00,
    endHour: 19,
    endMinute: 30,
    location: cossiLocation,
    category: TrainingCategory.special,
    regularParity: WeekParity.any,
    badgeLabel: 'Cossi',
    // Cossi training is always Monday – no multi-day forecast needed
    forecastDays: 1,
    isIndoor: false,
    requiresRegistration: false,
    courses: [],
  ),
  2: (
    // Tuesday
    trainingName: 'Training',
    startHour: 19,
    startMinute: 0,
    endHour: 21,
    endMinute: 0,
    location: moeckernTrackLocation,
    category: TrainingCategory.alternative,
    regularParity: WeekParity.any,
    badgeLabel: null,
    forecastDays: 8,
    isIndoor: false,
    requiresRegistration: false,
    courses: [],
  ),
  3: (
    // Wednesday
    trainingName: 'Technik',
    startHour: 19,
    startMinute: 0,
    endHour: 20,
    endMinute: 30,
    location: moeckernTrackLocation,
    category: TrainingCategory.regular,
    regularParity: WeekParity.any,
    badgeLabel: 'Technik',
    forecastDays: 8,
    isIndoor: false,
    requiresRegistration: false,
    courses: [],
  ),
  4: (
    // Thursday
    trainingName: 'Training',
    startHour: 19,
    startMinute: 0,
    endHour: 21,
    endMinute: 0,
    location: moeckernTrackLocation,
    category: TrainingCategory.alternative,
    regularParity: WeekParity.any,
    badgeLabel: null,
    forecastDays: 8,
    isIndoor: false,
    requiresRegistration: false,
    courses: [],
  ),
  5: (
    // Friday
    trainingName: 'Training',
    startHour: 19,
    startMinute: 0,
    endHour: 21,
    endMinute: 0,
    location: moeckernTrackLocation,
    category: TrainingCategory.regular,
    regularParity: WeekParity.even,
    badgeLabel: 'gerade KW',
    forecastDays: 8,
    isIndoor: false,
    requiresRegistration: false,
    courses: [],
  ),
  6: (
    // Saturday
    trainingName: 'Training',
    startHour: 10,
    startMinute: 0,
    endHour: 12,
    endMinute: 0,
    location: moeckernTrackLocation,
    category: TrainingCategory.alternative,
    regularParity: WeekParity.any,
    badgeLabel: null,
    forecastDays: 8,
    isIndoor: false,
    requiresRegistration: false,
    courses: [],
  ),
  7: (
    // Sunday
    trainingName: 'Training',
    startHour: 10,
    startMinute: 0,
    endHour: 12,
    endMinute: 0,
    location: moeckernTrackLocation,
    category: TrainingCategory.regular,
    regularParity: WeekParity.odd,
    badgeLabel: 'ungerade KW',
    forecastDays: 8,
    isIndoor: false,
    requiresRegistration: false,
    courses: [],
  ),
};

/// Winter training data per weekday (last Monday of October – end of March).
const Map<int, ScheduleEntry> winterSchedule = {
  1: (
    // Monday
    trainingName: 'Rabet',
    startHour: 18,
    startMinute: 30,
    endHour: 20,
    endMinute: 15,
    location: sporthalleRabetLocation,
    category: TrainingCategory.regular,
    regularParity: WeekParity.any,
    badgeLabel: 'Rabet',
    forecastDays: 8,
    isIndoor: true,
    requiresRegistration: false,
    courses: [
      TrainingCourse(
        category: 'Fitness',
        instructors: ['Annett Marien', 'Michael Marien', 'Annett Voigt'],
        content: 'Athletik + Spiel',
        equipment: 'Turnschuh',
      ),
    ],
  ),
  2: (
    // Tuesday
    trainingName: 'Landauer Brücke',
    startHour: 18,
    startMinute: 30,
    endHour: 19,
    endMinute: 30,
    location: landauerBrueckeLocation,
    category: TrainingCategory.regular,
    regularParity: WeekParity.any,
    badgeLabel: 'Landauer Brücke',
    forecastDays: 8,
    isIndoor: false,
    requiresRegistration: false,
    courses: [
      TrainingCourse(
        category: 'Fitness',
        instructors: ['Annett Marien', 'Michael Marien', 'Annett Voigt'],
        content: 'Athletik/Lauf',
        equipment: 'Turnschuh / warme Kleidung',
      ),
    ],
  ),
  3: (
    // Wednesday
    trainingName: 'Kraftraum RR-Bahn',
    startHour: 18,
    startMinute: 30,
    endHour: 20,
    endMinute: 30,
    location: kraftraumRrBahnLocation,
    category: TrainingCategory.regular,
    regularParity: WeekParity.any,
    badgeLabel: 'Kraftraum',
    forecastDays: 8,
    isIndoor: true,
    requiresRegistration: true,
    courses: [
      TrainingCourse(
        category: 'Fitness',
        instructors: ['Annett Marien', 'Michael Marien', 'Annett Voigt'],
        content: 'Athletik',
        equipment: 'Turnschuh',
        notes: ['Nur nach Voranmeldung'],
      ),
    ],
  ),
  4: (
    // Thursday
    trainingName: 'Völki',
    startHour: 18,
    startMinute: 45,
    endHour: 20,
    endMinute: 15,
    location: voelkiLocation,
    category: TrainingCategory.regular,
    regularParity: WeekParity.any,
    badgeLabel: 'Völki',
    forecastDays: 8,
    isIndoor: false,
    requiresRegistration: false,
    courses: [
      TrainingCourse(
        category: 'Fitness',
        instructors: ['Annett Marien', 'Michael Marien', 'Annett Voigt'],
        content: 'Lauf + Athletik',
        equipment: 'Turnschuh / warme Kleidung',
      ),
    ],
  ),
  6: (
    // Saturday
    trainingName: 'Evangelisches Schulzentrum',
    startHour: 14,
    startMinute: 0,
    endHour: 16,
    endMinute: 0,
    location: sporthalleEvsLocation,
    category: TrainingCategory.regular,
    regularParity: WeekParity.any,
    badgeLabel: 'EVS',
    forecastDays: 8,
    // Indoor sports hall training: no weather forecast is fetched or evaluated.
    isIndoor: true,
    requiresRegistration: false,
    courses: [
      TrainingCourse(
        category: 'Fitness',
        instructors: ['Annett Marien', 'Michael Marien', 'Annett Voigt'],
        content: 'Skate',
        equipment: 'Skates / Technik & Spaß',
      ),
      TrainingCourse(
        category: 'Kurs',
        instructors: ['Sven Knauer-Goldschmidt'],
        content: 'Skate',
        equipment: 'Skates / Technik & Spaß',
        notes: ['Nur nach Voranmeldung'],
      ),
    ],
  ),
};

// ---------------------------------------------------------------------------
// One-time events
// ---------------------------------------------------------------------------

/// A single event that is shown only once on a specific calendar date,
/// e.g. an external event or exhibition, independent of the weekday schedule
/// and the active-days toggle.
typedef OneTimeEvent = ({
  DateTime date,
  String title,
  String trainingName,
  int startHour,
  int startMinute,
  int endHour,
  int endMinute,
  Location location,
});

/// One-off special events. Add new entries here to show a single event on a
/// specific date; it disappears automatically once it is over.
final List<OneTimeEvent> oneTimeEvents = [
  (
    date: DateTime(2026, 9, 20),
    title: 'Porsche Event',
    trainingName: 'Porsche Event',
    startHour: 11,
    startMinute: 45,
    endHour: 17,
    endMinute: 0,
    location: porscheLocation,
  ),
];

/// Prefix used for the synthetic session id of one-time events (see
/// [oneTimeEvents]). Used to recognize such sessions later in the pipeline
/// (e.g. JSON payload, UI) without relying on weekday/date-based rules,
/// which don't apply to one-off events.
const String oneTimeEventIdPrefix = 'event_';

/// Whether [id] (a `TrainingSession.id` / training id) belongs to a one-time
/// event. Such sessions are never "Alternativ" and are always shown,
/// independent of the "Alternative Trainings anzeigen" toggle.
bool isOneTimeEventId(String id) => id.startsWith(oneTimeEventIdPrefix);
