# Flutter 相关的 ProGuard 规则
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn io.flutter.embedding.**

# Gson 相关
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.examples.android.model.** { <fields>; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# OkHttp 相关
-dontwarn okhttp3.**
-dontwarn okio.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# Dio 相关
-dontwarn dio.**
-keep class dio.** { *; }

# GetX 相关
-keep class com.getxtk.** { *; }
-keep class get.** { *; }

# SQLCipher / SQLite 相关
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# Shared Preferences
-keep class android.support.v7.preference.** { *; }

# 二维码扫描相关
-keep class com.google.mlkit.vision.** { *; }
-keep class com.google.android.gms.internal.** { *; }

# 蓝牙相关
-keep class com.lib.flutter_blue_plus.** { *; }

# 图片选择相关
-keep class io.flutter.plugins.imagepicker.** { *; }

# Secure Storage 相关
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# 保留原生方法
-keepclasseswithmembernames class * {
    native <methods>;
}

# 保留枚举类
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# 保留 Parcelable 序列化类
-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# 保留 Serializable 序列化类
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# 移除日志
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Google Play Core 相关（解决 R8 混淆问题）
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Dio 网络请求相关（解决 403/Token 问题）
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.plugins.**

# GetX 相关
-keep class com.getxtk.** { *; }
-keep class get.** { *; }
-dontwarn com.getxtk.**
-dontwarn get.**

# Dio 相关
-dontwarn dio.**
-keep class dio.** { *; }
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# JSON 序列化相关
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Flutter 相关
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class com.healthcenter.health_center_app.** { *; }
