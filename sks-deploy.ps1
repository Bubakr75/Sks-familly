# SKS Family - Correctif iOS Web + Deploiement (version ASCII pur)
$ErrorActionPreference = "Stop"
$ProjectId = "sks-familly-3f205"
$VapidFilePath = "lib\config\vapid_key.dart"

function W-Step($m) { Write-Host ""; Write-Host "========== $m ==========" -ForegroundColor Cyan }
function W-OK($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function W-Err($m)  { Write-Host "  [ERREUR] $m" -ForegroundColor Red; exit 1 }
function W-Info($m) { Write-Host "  $m" -ForegroundColor Gray }
function W-Warn($m) { Write-Host "  [!] $m" -ForegroundColor Yellow }

function Write-FileUTF8BOM($relativePath, $content) {
    $full = Join-Path $PWD $relativePath
    $dir = Split-Path $full -Parent
    if ($dir -and !(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8WithBom = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($full, $content, $utf8WithBom)
}

Write-Host "============================================================" -ForegroundColor Magenta
Write-Host "  SKS Family - Correctif iOS Web + Deploiement automatique" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

# --- Etape 0 : verifier dossier projet ---
W-Step "Verification du dossier projet"
if (!(Test-Path "pubspec.yaml")) {
    W-Err "pubspec.yaml introuvable. Fais cd vers le dossier de ton projet Sks-familly."
}
if (!(Test-Path "lib\services\firestore_service.dart")) {
    W-Err "lib\services\firestore_service.dart introuvable. Verifie que tu es dans le bon dossier."
}
W-OK "Dossier projet OK"

# --- Etape 1 : verifier Flutter ---
W-Step "Verification de Flutter"
try {
    $fv = flutter --version 2>&1 | Select-Object -First 1
    W-OK "Flutter detecte : $fv"
} catch {
    W-Err "Flutter n est pas installe. Installe-le depuis https://docs.flutter.dev/get-started/install/windows"
}

# --- Etape 2 : verifier Firebase CLI ---
W-Step "Verification de Firebase CLI"
try {
    $fbin = firebase --version 2>&1
    W-OK "Firebase CLI detecte : $fbin"
} catch {
    W-Err "Firebase CLI n est pas installe. Tape dans un autre PowerShell : npm install -g firebase-tools"
}

# --- Etape 3 : verifier connexion Firebase ---
W-Step "Verification connexion Firebase"
$loggedIn = $false
try {
    $null = firebase projects:list 2>&1
    if ($LASTEXITCODE -eq 0) { $loggedIn = $true }
} catch {}
if (-not $loggedIn) {
    W-Warn "Tu n es pas connecte a Firebase."
    $r = Read-Host "  Lancer firebase login maintenant ? (O/N)"
    if ($r -eq "O" -or $r -eq "o") {
        firebase login
    } else {
        W-Err "Connexion Firebase requise. Relance ce script apres firebase login."
    }
}
W-OK "Connecte a Firebase"

# --- Etape 4 : creer les fichiers ---
W-Step "Application des correctifs iOS Web"

# 4.1 - web\firebase-messaging-sw.js
W-Info "Creation : web\firebase-messaging-sw.js"
$sw = @'
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyABGqJErNqh4xr2jIyf4PHQzxX4jYHgQ0I",
  appId: "1:1033903328737:web:5e7ac00165d5edf8b2d6a0",
  messagingSenderId: "1033903328737",
  projectId: "sks-familly-3f205",
  storageBucket: "sks-familly-3f205.firebasestorage.app",
  authDomain: "sks-familly-3f205.firebaseapp.com",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle = (payload.notification && payload.notification.title) || "SKS Family";
  const notificationOptions = {
    body: (payload.notification && payload.notification.body) || "",
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    tag: "sks-family-" + Date.now(),
    data: payload.data || {},
    vibrate: [200, 100, 200],
  };
  return self.registration.showNotification(notificationTitle, notificationOptions);
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && "focus" in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) { return clients.openWindow("/"); }
    })
  );
});

self.addEventListener("push", (event) => {
  if (!event.data) return;
  let payload;
  try { payload = event.data.json(); } catch (e) {
    payload = { notification: { title: "SKS Family", body: event.data.text() } };
  }
  const notificationTitle = (payload.notification && payload.notification.title) || "SKS Family";
  const notificationOptions = {
    body: (payload.notification && payload.notification.body) || "",
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    data: payload.data || {},
  };
  event.waitUntil(self.registration.showNotification(notificationTitle, notificationOptions));
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});
self.addEventListener("install", () => { self.skipWaiting(); });
'@
Write-FileUTF8BOM "web\firebase-messaging-sw.js" $sw

# 4.2 - lib\config\vapid_key.dart
W-Info "Creation : lib\config\vapid_key.dart"
$vapid = @'
class VapidKeyConfig {
  static const String vapidKey = "VOTRE_CLE_VAPID_ICI";

  static bool get isConfigured =>
      vapidKey.isNotEmpty &&
      vapidKey != "VOTRE_CLE_VAPID_ICI" &&
      vapidKey.startsWith("B");
}
'@
Write-FileUTF8BOM "lib\config\vapid_key.dart" $vapid

# 4.3 - lib\utils\web_reconnect.dart
W-Info "Creation : lib\utils\web_reconnect.dart"
$wr = @'
import "web_reconnect_factory.dart";

void attachWebReconnectHandlers(void Function() reconnectFn) {
  WebReconnectFactory.attach(reconnectFn);
}
'@
Write-FileUTF8BOM "lib\utils\web_reconnect.dart" $wr

# 4.4 - lib\utils\web_reconnect_factory.dart
W-Info "Creation : lib\utils\web_reconnect_factory.dart"
$wrf = @'
export "web_reconnect_stub.dart"
    if (dart.library.html) "web_reconnect_web.dart";
'@
Write-FileUTF8BOM "lib\utils\web_reconnect_factory.dart" $wrf

# 4.5 - lib\utils\web_reconnect_stub.dart
W-Info "Creation : lib\utils\web_reconnect_stub.dart"
$wrs = @'
class WebReconnectFactory {
  static void attach(void Function() reconnectFn) {
    // No-op sur natif.
  }
}
'@
Write-FileUTF8BOM "lib\utils\web_reconnect_stub.dart" $wrs

# 4.6 - lib\utils\web_reconnect_web.dart
W-Info "Creation : lib\utils\web_reconnect_web.dart"
$wrw = @'
// ignore: avoid_web_libraries_in_flutter
import "dart:html" as html;
import "dart:async";

class WebReconnectFactory {
  static StreamSubscription? _visibilitySub;
  static StreamSubscription? _onlineSub;
  static StreamSubscription? _focusSub;
  static StreamSubscription? _customVisibleSub;
  static StreamSubscription? _customOnlineSub;

  static void attach(void Function() reconnectFn) {
    _visibilitySub ??= html.document.onVisibilityChange.listen((_) {
      if (html.document.visibilityState == "visible") {
        reconnectFn();
      }
    });

    _onlineSub ??= html.window.onOnline.listen((_) {
      reconnectFn();
    });

    _focusSub ??= html.window.onFocus.listen((_) {
      reconnectFn();
    });

    _customVisibleSub ??= html.window.on["flutter-web-became-visible"].listen((_) {
      reconnectFn();
    });
    _customOnlineSub ??= html.window.on["flutter-web-online"].listen((_) {
      reconnectFn();
    });
  }

  static void detach() {
    _visibilitySub?.cancel();
    _onlineSub?.cancel();
    _focusSub?.cancel();
    _customVisibleSub?.cancel();
    _customOnlineSub?.cancel();
    _visibilitySub = null;
    _onlineSub = null;
    _focusSub = null;
    _customVisibleSub = null;
    _customOnlineSub = null;
  }
}
'@
Write-FileUTF8BOM "lib\utils\web_reconnect_web.dart" $wrw

# 4.7 - lib\services\fcm_service.dart
W-Info "Remplacement : lib\services\fcm_service.dart"
$fcm = @'
import "package:flutter/foundation.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../config/vapid_key.dart";
import "notification_service.dart";

@pragma("vm:entry-point")
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) debugPrint("BG message: ${message.notification?.title}");
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _platformName {
    if (kIsWeb) return "web";
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return "android";
      case TargetPlatform.iOS:
        return "ios";
      case TargetPlatform.macOS:
        return "macos";
      case TargetPlatform.windows:
        return "windows";
      case TargetPlatform.linux:
        return "linux";
      case TargetPlatform.fuchsia:
        return "fuchsia";
    }
  }

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: false,
      announcement: false,
      carPlay: false,
      provisional: false,
    );

    if (kDebugMode) {
      debugPrint("FCM permission: ${settings.authorizationStatus}");
      debugPrint("FCM platform detectee: $_platformName");
    }

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _saveToken();
      _messaging.onTokenRefresh.listen((newToken) {
        _saveTokenToFirestore(newToken);
      });
    } else {
      if (kDebugMode) {
        debugPrint("FCM: permission refusee sur $_platformName. Sur iOS Safari Web, verifiez que l app est installee comme PWA.");
      }
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint("FG message: ${message.notification?.title}");
      }
      final notification = message.notification;
      if (notification == null) return;
      final type = _getNotificationType(message.data["type"] ?? "");
      NotificationService.show(
        title: notification.title ?? "SKS Family",
        message: notification.body ?? "",
        type: type,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint("Notification tapped: ${message.notification?.title}");
      }
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null && kDebugMode) {
      debugPrint("App opened from notification: ${initialMessage.notification?.title}");
    }
  }

  NotificationType _getNotificationType(String type) {
    switch (type) {
      case "points":
      case "history":
        return NotificationType.bonus;
      case "badge":
        return NotificationType.badge;
      case "punishment":
      case "punishment_progress":
      case "punishment_done":
        return NotificationType.punishment;
      case "immunity":
        return NotificationType.progress;
      case "trade_new":
      case "trade_update":
        return NotificationType.goal;
      case "tribunal_new":
      case "tribunal_update":
        return NotificationType.penalty;
      case "school_note":
        return NotificationType.bonus;
      case "screen_time":
      case "saturday_rating":
        return NotificationType.screenTime;
      default:
        return NotificationType.sync;
    }
  }

  Future<void> registerToken() async {
    await _saveToken();
  }

  Future<void> _saveToken() async {
    try {
      String? token;
      if (kIsWeb) {
        if (!VapidKeyConfig.isConfigured) {
          if (kDebugMode) {
            debugPrint("==========================================");
            debugPrint("FCM WEB: VAPID key non configuree !");
            debugPrint("Voir lib/config/vapid_key.dart");
            debugPrint("Notifications push NE FONCTIONNERONT PAS sur Web.");
            debugPrint("La synchro Firestore continuera de fonctionner.");
            debugPrint("==========================================");
          }
          return;
        }
        token = await _messaging.getToken(vapidKey: VapidKeyConfig.vapidKey);
      } else {
        token = await _messaging.getToken();
      }

      if (kDebugMode) debugPrint("FCM Token ($_platformName): $token");
      if (token != null) {
        await _saveTokenToFirestore(token);
      } else {
        if (kDebugMode) {
          debugPrint("FCM: getToken() a retourne null sur $_platformName.");
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("FCM getToken error: $e");
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final familyId = prefs.getString("family_id");
      final deviceId = prefs.getString("device_id");

      if (familyId == null || deviceId == null) return;

      await _db
          .collection("families")
          .doc(familyId)
          .collection("fcm_tokens")
          .doc(deviceId)
          .set({
        "token": token,
        "deviceId": deviceId,
        "platform": _platformName,
        "updatedAt": FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint("FCM token saved for device $deviceId ($_platformName)");
    } catch (e) {
      if (kDebugMode) debugPrint("Save FCM token error: $e");
    }
  }
}
'@
Write-FileUTF8BOM "lib\services\fcm_service.dart" $fcm

# 4.8 - web\index.html
W-Info "Remplacement : web\index.html"
$html = @'
<!DOCTYPE html>
<html>
<head>
  <base href="$FLUTTER_BASE_HREF">

  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="SKS Family - Application familiale">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">

  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="SKS Family">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  <meta name="theme-color" content="#1A1A2E">

  <link rel="icon" type="image/png" href="favicon.png"/>

  <title>SKS Family</title>
  <link rel="manifest" href="manifest.json">

  <style>
    body {
      margin: 0;
      padding: 0;
      background-color: #1A1A2E;
      overflow: hidden;
    }
  </style>
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>

  <script>
    if ("serviceWorker" in navigator) {
      window.addEventListener("load", function () {
        navigator.serviceWorker.register("/firebase-messaging-sw.js")
          .then(function (registration) {
            console.log("[SW] Service Worker enregistre:", registration.scope);
          })
          .catch(function (err) {
            console.warn("[SW] Echec enregistrement Service Worker:", err);
          });

        document.addEventListener("visibilitychange", function () {
          if (document.visibilityState === "visible") {
            window.dispatchEvent(new CustomEvent("flutter-web-became-visible"));
          }
        });

        window.addEventListener("online", function () {
          window.dispatchEvent(new CustomEvent("flutter-web-online"));
        });
      });
    }
  </script>
</body>
</html>
'@
Write-FileUTF8BOM "web\index.html" $html

# 4.9 - web\manifest.json
W-Info "Remplacement : web\manifest.json"
$manifest = @'
{
    "name": "SKS Family",
    "short_name": "SKS Family",
    "start_url": ".",
    "display": "standalone",
    "background_color": "#1A1A2E",
    "theme_color": "#E94560",
    "description": "Application familiale SKS - Gestion des scores et activites",
    "orientation": "portrait-primary",
    "prefer_related_applications": false,
    "icons": [
        {
            "src": "icons/Icon-192.png",
            "sizes": "192x192",
            "type": "image/png"
        },
        {
            "src": "icons/Icon-512.png",
            "sizes": "512x512",
            "type": "image/png"
        },
        {
            "src": "icons/Icon-maskable-192.png",
            "sizes": "192x192",
            "type": "image/png",
            "purpose": "maskable"
        },
        {
            "src": "icons/Icon-maskable-512.png",
            "sizes": "512x512",
            "type": "image/png",
            "purpose": "maskable"
        }
    ],
    "gcm_sender_id": "1033903328737"
}
'@
Write-FileUTF8BOM "web\manifest.json" $manifest

# 4.10 - Patcher lib\services\firestore_service.dart
W-Info "Patch : lib\services\firestore_service.dart"
$fsPath = Join-Path $PWD "lib\services\firestore_service.dart"
if (!(Test-Path $fsPath)) {
    W-Err "lib\services\firestore_service.dart introuvable."
}
$fs = [System.IO.File]::ReadAllText($fsPath)
$fs = $fs -replace "`r`n", "`n"

# Patch 1 : remplacer le 2e import duplique
$old1 = "import 'fcm_service.dart';`nimport 'fcm_service.dart';"
$new1 = "import 'fcm_service.dart';`nimport '../utils/web_reconnect.dart';"
if ($fs.Contains($old1)) {
    $fs = $fs.Replace($old1, $new1)
    W-OK "Patch 1/4 : import web_reconnect ajoute"
} else {
    W-Warn "Patch 1/4 : pattern non trouve (deja applique ?)"
}

# Patch 2 : config long-polling
$old2 = "  Future<void> init() async {`n    try {`n      final prefs = await SharedPreferences.getInstance();"
$new2 = @"
  Future<void> init() async {
    try {
      // CORRIGE : configuration Firestore pour iOS Safari Web.
      // Le WebSocket par defaut se coupe silencieusement sur iOS Safari.
      // Le long-polling HTTP est beaucoup plus fiable.
      if (kIsWeb) {
        try {
          _db.settings = const Settings(
            persistenceEnabled: true,
            sslEnabled: true,
            webExperimentalForceLongPolling: true,
            webExperimentalAutoDetectLongPolling: false,
          );
          if (kDebugMode) debugPrint('Firestore: long-polling force sur Web (iOS Safari compat)');
        } catch (e) {
          if (kDebugMode) debugPrint('Firestore settings error (non bloquant): ' + e.toString());
        }
      }

      final prefs = await SharedPreferences.getInstance();
"@
if ($fs.Contains($old2)) {
    $fs = $fs.Replace($old2, $new2)
    W-OK "Patch 2/4 : config long-polling ajoutee"
} else {
    W-Warn "Patch 2/4 : pattern non trouve (deja applique ?)"
}

# Patch 3 : appel _startWebLifecycleHandlers()
$old3 = "      if (_familyId != null) {`n        await FcmService().registerToken();`n        _startListening();`n        _startKeepAlive();`n      }"
$new3 = "      _startWebLifecycleHandlers();`n      if (_familyId != null) {`n        await FcmService().registerToken();`n        _startListening();`n        _startKeepAlive();`n      }"
if ($fs.Contains($old3)) {
    $fs = $fs.Replace($old3, $new3)
    W-OK "Patch 3/4 : appel _startWebLifecycleHandlers() ajoute"
} else {
    W-Warn "Patch 3/4 : pattern non trouve (deja applique ?)"
}

# Patch 4 : methode _startWebLifecycleHandlers()
$old4 = "    } catch (e) {`n      if (kDebugMode) debugPrint('FirestoreService init error: ' + e.toString());`n    }`n  }"
$new4 = @"
    } catch (e) {
      if (kDebugMode) debugPrint('FirestoreService init error: ' + e.toString());
    }
  }

  // --- Web lifecycle handlers ---
  // iOS Safari gele les timers JS en arriere-plan. Au retour, on force
  // la reconnexion Firestore via les evenements natifs du navigateur.
  void _startWebLifecycleHandlers() {
    try {
      attachWebReconnectHandlers(() {
        if (kDebugMode) debugPrint('Web lifecycle event : reconnect Firestore');
        reconnect();
      });
      if (kDebugMode && kIsWeb) debugPrint('Web lifecycle handlers attaches');
    } catch (e) {
      if (kDebugMode) debugPrint('Web lifecycle listener error: ' + e.toString());
    }
  }
"@
if ($fs.Contains($old4)) {
    $fs = $fs.Replace($old4, $new4)
    W-OK "Patch 4/4 : methode _startWebLifecycleHandlers() ajoutee"
} else {
    W-Warn "Patch 4/4 : pattern non trouve (deja applique ?)"
}

$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($fsPath, $fs, $utf8Bom)

W-OK "Tous les correctifs ont ete appliques"

# --- Etape 5 : ouvrir console Firebase ---
W-Step "Console Firebase - Generation de la cle VAPID"
Write-Host ""
Write-Host "  +----------------------------------------------------------+" -ForegroundColor Yellow
Write-Host "  |  DANS LA CONSOLE FIREBASE :                              |" -ForegroundColor Yellow
Write-Host "  |                                                          |" -ForegroundColor Yellow
Write-Host "  |  1. Va dans Parametres du projet - Cloud Messaging       |" -ForegroundColor Yellow
Write-Host "  |  2. Section Configuration Web - Web Push certificates   |" -ForegroundColor Yellow
Write-Host "  |  3. Clique Generer une paire de cles                     |" -ForegroundColor Yellow
Write-Host "  |  4. COPIE la cle publique (commence par B...)            |" -ForegroundColor Yellow
Write-Host "  |  5. Reviens ici et colle-la quand demande                |" -ForegroundColor Yellow
Write-Host "  +----------------------------------------------------------+" -ForegroundColor Yellow
Write-Host ""
$r = Read-Host "Ouvrir la console Firebase maintenant ? (O/N)"
if ($r -eq "O" -or $r -eq "o") {
    Start-Process "https://console.firebase.google.com/project/sks-familly-3f205/messaging"
    W-OK "Console Firebase ouverte dans ton navigateur"
} else {
    W-Warn "Ouvre manuellement : https://console.firebase.google.com/project/sks-familly-3f205/messaging"
}

# --- Etape 6 : demander et inserer la cle VAPID ---
W-Step "Saisie de la cle VAPID"
Write-Host "  Colle la cle publique VAPID (commence par B, ~150 caracteres) :" -ForegroundColor White
$vapidKey = Read-Host "VAPID key"

$vapidKey = $vapidKey.Trim()
if ([string]::IsNullOrEmpty($vapidKey)) {
    W-Err "Cle VAPID vide. Abandon."
}
if (-not $vapidKey.StartsWith("B")) {
    W-Warn "La cle VAPID devrait commencer par B. Verifie que tu as copie la cle PUBLIQUE."
    $c = Read-Host "Continuer quand meme ? (O/N)"
    if ($c -ne "O" -and $c -ne "o") { exit 1 }
}

W-Info "Insertion de la cle VAPID dans lib\config\vapid_key.dart..."
$vapidPath = Join-Path $PWD "lib\config\vapid_key.dart"
$vapidContent = [System.IO.File]::ReadAllText($vapidPath)
$vapidContent = $vapidContent.Replace("VOTRE_CLE_VAPID_ICI", $vapidKey)
[System.IO.File]::WriteAllText($vapidPath, $vapidContent, $utf8Bom)
W-OK "Cle VAPID inseree"

# --- Etape 7 : flutter clean + pub get ---
W-Step "Nettoyage et dependances Flutter"
flutter clean
if ($LASTEXITCODE -ne 0) { W-Err "flutter clean a echoue" }
flutter pub get
if ($LASTEXITCODE -ne 0) { W-Err "flutter pub get a echoue" }
W-OK "Dependances a jour"

# --- Etape 8 : flutter build web ---
W-Step "Build Flutter Web (2-5 minutes, sois patient...)"
flutter build web --release
if ($LASTEXITCODE -ne 0) { W-Err "flutter build web a echoue" }
W-OK "Build Web termine"

# --- Etape 9 : firebase deploy ---
W-Step "Deploiement sur Firebase Hosting"
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) {
    W-Err "firebase deploy a echoue. Verifie que tu es bien connecte (firebase login)"
}
W-OK "Deploiement termine !"

# --- Etape 10 : recapitulatif ---
$hostingUrl = "https://sks-familly-3f205.web.app"
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  DEPLOIEMENT REUSSI !" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Ton app est accessible ici :" -ForegroundColor White
Write-Host "  $hostingUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "  PROCHAINES ETAPES POUR TESTER SUR IPHONE :" -ForegroundColor Yellow
Write-Host "  1. Ouvre SAFARI sur l iPhone (pas Chrome iOS)"
Write-Host "  2. Va sur : $hostingUrl"
Write-Host "  3. Bouton Partager - Sur l ecran d accueil"
Write-Host "  4. Ouvre l app depuis l icone (NE PAS utiliser Safari)"
Write-Host "  5. Autorise les notifications quand demande"
Write-Host "  6. Fais une action (tribunal, immunite) - verifie la synchro"
Write-Host ""
Write-Host "  Logs debug : Safari - Developper - [iPhone] - Console" -ForegroundColor Gray
Write-Host ""
Write-Host "============================================================" -ForegroundColor Magenta
