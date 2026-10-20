/// One immutable order proposal. A failed acknowledgement is resolved by a
/// server read before any repeat write. Never allocate a new ID during retry.
class OrderAttempt {
  final Future<bool> Function() existsOnServer;
  final Future<void> Function() write;
  Future<void>? _active;
  bool _attempted = false;
  bool _confirmed = false;

  OrderAttempt(
      {required this.existsOnServer,
      required this.write,
      bool previouslyAttempted = false})
      : _attempted = previouslyAttempted;

  Future<void> submit() =>
      _active ??= _submit().whenComplete(() => _active = null);

  Future<void> _submit() async {
    if (_confirmed) return;
    if (_attempted && await existsOnServer()) {
      _confirmed = true;
      return;
    }
    _attempted = true;
    await write();
    _confirmed = true;
  }
}
