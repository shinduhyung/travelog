# Flutter — 엔진이 JNI로 참조하는 최소 범위만 유지
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase / Google Play Services
# → 자체 consumer-rules.pro가 필요한 클래스는 알아서 keep 하므로 전체 keep 삭제
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# TikTok Business SDK — SDK 자체 요구사항이면 유지, 문서 재확인 권장
-keep class com.tiktok.** { *; }
-dontwarn com.tiktok.**

# Install Referrer
-keep class com.android.installreferrer.** { *; }

# AndroidX Lifecycle — 자체 consumer-rules.pro로 충분, 전체 keep 삭제
-dontwarn androidx.lifecycle.**

# Keep annotations & generic signatures (Firebase 리플렉션에 필요)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# JNI native 메서드 이름 유지
-keepclasseswithmembernames class * {
    native <methods>;
}

# 앱의 Application/Activity 클래스 (리플렉션으로 생성됨)
-keep class com.example.jidoapp.MyApplication { *; }
-keep class com.example.jidoapp.MainActivity { *; }

# Parcelable CREATOR 필드 유지
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# enum values()/valueOf() 유지 (TikTok SDK 등에서 사용)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}