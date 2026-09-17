import 'dart:async';

bool isStandaloneMode(
        {required bool displayMode, required bool navigatorFlag}) =>
    displayMode || navigatorFlag;

enum PwaEvent { visible, hidden, focus, online, pageShow, pageHide }

/// Compteurs locaux uniquement : aucune chaîne ou donnée applicative acceptée.
class PwaDiagnostics {
  PwaDiagnostics({this.enabled = false});
  final bool enabled;
  int _events = 0;
  int _resumes = 0;
  Map<String, int> get snapshot =>
      enabled ? {'events': _events, 'resumes': _resumes} : {};
}

/// Un seul propriétaire des abonnements et du délai de reprise.
class PwaLifecycle {
  PwaLifecycle({
    required this.isVisible,
    required this.standalone,
    required this.onResume,
    this.onPause,
    PwaDiagnostics? diagnostics,
  }) : diagnostics = diagnostics ?? PwaDiagnostics();

  final bool Function() isVisible;
  final bool standalone;
  final void Function() onResume;
  final void Function()? onPause;
  final PwaDiagnostics diagnostics;
  final List<StreamSubscription<PwaEvent>> _subscriptions = [];
  Timer? _resumeDebounce;
  bool _hidden = false;
  bool _attached = false;

  void attach(List<Stream<PwaEvent>> streams) {
    detach();
    _attached = true;
    _hidden = !isVisible();
    for (final stream in streams) {
      _subscriptions.add(stream.listen(handle));
    }
  }

  void handle(PwaEvent event) {
    if (!_attached) return;
    if (diagnostics.enabled) diagnostics._events++;
    if (event == PwaEvent.hidden || event == PwaEvent.pageHide) {
      _resumeDebounce?.cancel();
      _resumeDebounce = null;
      if (!_hidden) onPause?.call();
      _hidden = true;
      return;
    }
    if (!isVisible()) return;
    // Le focus des contrôles dans une PWA déjà visible n'est pas une reprise.
    if (standalone && !_hidden && event != PwaEvent.online) return;
    _resumeDebounce?.cancel();
    _resumeDebounce = Timer(const Duration(milliseconds: 700), () {
      _resumeDebounce = null;
      if (!_attached || !isVisible()) return;
      _hidden = false;
      if (diagnostics.enabled) diagnostics._resumes++;
      onResume();
    });
  }

  void detach() {
    _attached = false;
    _resumeDebounce?.cancel();
    _resumeDebounce = null;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }
}
