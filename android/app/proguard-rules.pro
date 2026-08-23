# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Firebase / Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore document parsing happens in Dart (cloud_firestore serializes to
# Map<String,dynamic>), not via reflection on native Kotlin/Java model
# classes, so no app-specific -keep rules are needed for that.

# TikTok Business SDK
-keep class com.tiktok.** { *; }
-dontwarn com.tiktok.**

# Install Referrer
-keep class com.android.installreferrer.** { *; }

# AndroidX Lifecycle
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.lifecycle.**

# Keep annotations & generic signatures (needed for Firebase reflection)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Keep native method names (JNI)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep this app's Application/Activity classes and their no-arg
# constructors (Android instantiates these by reflection)
-keep class com.example.jidoapp.MyApplication { *; }
-keep class com.example.jidoapp.MainActivity { *; }

# Keep Parcelable CREATOR fields (standard Android requirement)
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep enum values()/valueOf() (used by SDKs like TikTok's currency/event enums)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}