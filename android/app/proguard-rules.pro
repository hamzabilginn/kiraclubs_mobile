# OneSignal ProGuard Rules
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# Agora RTC ProGuard Rules
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# App Links / Deep Links (app_links) ProGuard Rules
-keep class com.llfbandit.applinks.** { *; }
-dontwarn com.llfbandit.applinks.**

# Pusher Channels ProGuard Rules
-keep class com.pusher.** { *; }
-dontwarn com.pusher.**

# Play Core Split Install (Deferred Components) missing classes warnings suppression
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# AndroidX WorkManager ProGuard Rules
-keep class androidx.work.impl.background.systemalarm.SystemAlarmService { *; }
-keep class androidx.work.impl.background.systemjob.SystemJobService { *; }
-keep class androidx.work.impl.foreground.SystemForegroundService { *; }
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.model.** { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-keep class * extends androidx.work.impl.WorkDatabase { *; }
-dontwarn androidx.work.impl.**

# AndroidX Startup ProGuard Rules
-keep class androidx.startup.** { *; }
-dontwarn androidx.startup.**

# Flutter and general Android ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
