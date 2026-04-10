# ============================================================
# ProGuard / R8 rules for Aloo Market (com.mandi.aloo_market)
# ============================================================

# ──── Flutter & Dart ────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ──── OkHttp & OkIO (uCrop / image_cropper / HTTP clients) ────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# ──── Razorpay ────
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }
-optimizations !method/inlining/*
-keepclasseswithmembers class * {
  public void onPayment*(...);
}

# ──── Firebase ────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ──── Gson (used by Firebase, Razorpay, and other plugins) ────
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# ──── Google Fonts (runtime HTTP font loading) ────
-keep class com.google.android.gms.common.** { *; }

# ──── Geolocator / Geocoding ────
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**
-keep class com.baseflow.geocoding.** { *; }
-dontwarn com.baseflow.geocoding.**

# ──── Image Cropper (uCrop) ────
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

# ──── Image Picker ────
-keep class io.flutter.plugins.imagepicker.** { *; }
-dontwarn io.flutter.plugins.imagepicker.**

# ──── Flutter Local Notifications ────
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# ──── Fluttertoast ────
-keep class io.github.nicosantux.fluttertoast.** { *; }
-dontwarn io.github.nicosantux.fluttertoast.**

# ──── Share Plus ────
-keep class dev.fluttercommunity.plus.share.** { *; }
-dontwarn dev.fluttercommunity.plus.share.**

# ──── URL Launcher ────
-keep class io.flutter.plugins.urllauncher.** { *; }
-dontwarn io.flutter.plugins.urllauncher.**

# ──── Path Provider ────
-keep class io.flutter.plugins.pathprovider.** { *; }
-dontwarn io.flutter.plugins.pathprovider.**

# ──── Shared Preferences ────
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**

# ──── Package Info Plus ────
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }
-dontwarn dev.fluttercommunity.plus.packageinfo.**

# ──── General Android / AndroidX ────
-keep class androidx.** { *; }
-dontwarn androidx.**
-keep class android.** { *; }
-dontwarn android.**

# ──── Keep annotations ────
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes InnerClasses,EnclosingMethod

# ──── Keep Serializable classes ────
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ──── Keep native methods ────
-keepclasseswithmembernames class * {
    native <methods>;
}

# ──── Keep enums ────
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ──── Keep Parcelables ────
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# ──── Keep R classes ────
-keepclassmembers class **.R$* {
    public static <fields>;
}

# ──── Suppress warnings for missing optional dependencies ────
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn javax.annotation.**
-dontwarn kotlin.**
-dontwarn kotlinx.**
