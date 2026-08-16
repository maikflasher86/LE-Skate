# Room instantiates its generated database implementations (e.g. WorkManager's
# WorkDatabase_Impl) reflectively at runtime via Class.getDeclaredConstructor().
# R8 doesn't see this usage and can strip or rename the no-arg constructor,
# causing a release-only crash on startup:
# "Failed to create an instance of androidx.work.impl.WorkDatabase"
# (NoSuchMethodException: WorkDatabase_Impl.<init> []).
# The consumer ProGuard rules shipped with androidx.work / androidx.room don't
# fully cover this ("-keep class * extends androidx.room.RoomDatabase" without
# explicit member rules doesn't protect the constructor from removal), so we
# keep it explicitly here.
-keep class * extends androidx.room.RoomDatabase {
    <init>(...);
}
