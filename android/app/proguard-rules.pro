# Flutter Engine Keep Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep native methods and enum values
-keepclasseswithmembernames class * {
    native <methods>;
}

-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# SQFlite & SQLite Native Wrappers
-keep class com.tekartik.sqflite.** { *; }

# Secure Storage & Biometric Auth
-keep class com.it_ne.flutter_secure_storage.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }

# Local Notifications & Files
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Prevent obfuscation of serializable models
-keepattributes Signature, InnerClasses, EnclosingMethod, *Annotation*
