class PwaInstallService {
  static final PwaInstallService _instance = PwaInstallService._internal();
  factory PwaInstallService() => _instance;
  PwaInstallService._internal();

  bool get isSupported => false;
  bool get isIOS => false;
  bool get isStandalone => false;
  bool get canPrompt => false;
  bool get isInstalled => false;

  Future<bool> shouldShowPrompt() async => false;

  Future<String> promptInstall() async => 'unavailable';

  Future<void> dismiss({int days = 7}) async {}

  Future<void> clearDismiss() async {}

  Stream<void> get onPromptReady => const Stream.empty();
  Stream<void> get onInstalled => const Stream.empty();
}
