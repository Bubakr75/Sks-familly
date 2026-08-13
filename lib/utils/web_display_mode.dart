import 'web_display_mode_stub.dart'
    if (dart.library.html) 'web_display_mode_web.dart';

bool get isIosStandalonePwa => WebDisplayMode.isIosStandalonePwa;
