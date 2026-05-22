/// User intents the screen forwards to [MainViewModel.dispatch]. Keeping
/// these as a sealed hierarchy means new buttons add one case here and one
/// branch in the ViewModel, never a new public method on the ViewModel.
sealed class UiAction {
  const UiAction();
}

class ConfigureAction extends UiAction {
  final String organizationId;
  final String projectId;
  final String publicKey;

  const ConfigureAction({
    required this.organizationId,
    required this.projectId,
    required this.publicKey,
  });
}

class ConfigureFromBundleAction extends UiAction {
  const ConfigureFromBundleAction();
}

class TestConnectionAction extends UiAction {
  final String url;

  const TestConnectionAction(this.url);
}

class ClearLogAction extends UiAction {
  const ClearLogAction();
}

class ConsumeTransientMessageAction extends UiAction {
  const ConsumeTransientMessageAction();
}
