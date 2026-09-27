# Masjidly release R8 rules — keep reflection / serialization surfaces intact.

# Line numbers in stack traces (Play / Crashlytics mapping still applies).
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# kotlinx.serialization (models use @Serializable + Json.decodeFromString).
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.mikhailspeaks.masjidly.**$$serializer { *; }
-keepclassmembers class com.mikhailspeaks.masjidly.** {
    *** Companion;
}
-keepclasseswithmembers class com.mikhailspeaks.masjidly.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-if @kotlinx.serialization.Serializable class com.mikhailspeaks.masjidly.**
-keepclassmembers class <1> {
    static <1>$Companion Companion;
}

# Glance / AppWidget receivers and providers referenced from the manifest.
-keep class com.mikhailspeaks.masjidly.widget.** { *; }

# Notification BroadcastReceivers.
-keep class com.mikhailspeaks.masjidly.features.notifications.**Receiver { *; }

# Enums used via name / wire values in prefs.
-keepclassmembers enum com.mikhailspeaks.masjidly.** {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
