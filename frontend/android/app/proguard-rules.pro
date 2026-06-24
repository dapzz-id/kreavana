# Aturan Dasar untuk Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }

# Aturan Wajib untuk StringFog (agar kelas dekripsi tidak hilang)
-keep class com.github.megatronking.stringfog.** { *; }
-keep class com.github.megatronking.stringfog.xor.** { *; }

# Aturan untuk WebRTC & Callkit (mencegah class native crash saat runtime)
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
-keep class com.hiennv.flutter_callkit_incoming.** { *; }

# Menjaga file manifest dan kelas bertanda @Keep
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep <fields>;
    @androidx.annotation.Keep <methods>;
}

# Mencegah R8 menghapus kelas Google Play Core yang dibutuhkan Flutter
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**