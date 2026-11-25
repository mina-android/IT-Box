# Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }

# App & local plugins
-keep class com.ma.itbox.** { *; }
-keep class dev.fluttercommunity.workmanager.** { *; }
-keep class androidx.work.** { *; }
-dontwarn dev.fluttercommunity.workmanager.**

# flutter_local_notifications keep rules
-keepattributes *Annotation*
-keepattributes Signature
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.** { *; }
-keep class com.google.android.gms.internal.** { *; }

# Drift & sqlite3_flutter_libs native FFI rules
-keep class com.simonbinder.sqlite3_flutter_libs.** { *; }
-dontwarn com.simonbinder.sqlite3_flutter_libs.**
-keep class net.sqlcipher.** { *; }
-dontwarn net.sqlcipher.**

# ML Kit Document Scanner & Printing
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class net.nfet.printing.** { *; }

# Flutter Play Core / Deferred Components
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
