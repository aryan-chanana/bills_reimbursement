# Flutter engine + plugin registrants
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase / Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Google ML Kit (text recognition uses reflection)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.mlkit.vision.text.** { *; }
-dontwarn com.google.mlkit.**

# flutter_local_notifications
-keep class com.dexterous.** { *; }

# printing / pdf plugin native bridges
-keep class net.nfet.flutter.printing.** { *; }

# image_picker / file_picker
-keep class androidx.lifecycle.DefaultLifecycleObserver

# Desugared JDK libs
-keep class j$.** { *; }
-dontwarn j$.**

# Keep Parcelables / Serializables (common reflection target)
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
