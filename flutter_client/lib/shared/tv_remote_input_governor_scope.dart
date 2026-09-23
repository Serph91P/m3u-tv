import 'package:dpad/dpad.dart';
import 'package:flutter/widgets.dart';
import 'package:m3u_tv/services/tv_remote_key_governor.dart';

/// Moderates the Siri Remote's native swipe-to-arrow-key stream before it
/// reaches `dpad`'s `Shortcuts`, without replacing or racing that native
/// translation - see [TvRemoteKeyGovernor] for the debounce/acceleration
/// logic this delegates to.
///
/// Must wrap `Dpad`'s `child` (a descendant of `Dpad`'s own `Shortcuts`, so
/// key-event bubbling from the focused leaf reaches this widget's `Focus`
/// first) rather than sit outside `Dpad`.
class TvRemoteInputGovernorScope extends StatefulWidget {
  const TvRemoteInputGovernorScope({
    super.key,
    required this.enabled,
    required this.child,
  });

  /// Only meaningful on tvOS - the native swipe-to-key translation this
  /// moderates doesn't exist on other platforms.
  final bool enabled;

  final Widget child;

  @override
  State<TvRemoteInputGovernorScope> createState() =>
      _TvRemoteInputGovernorScopeState();
}

class _TvRemoteInputGovernorScopeState
    extends State<TvRemoteInputGovernorScope> {
  final TvRemoteKeyGovernor _governor = TvRemoteKeyGovernor();

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;

    switch (_governor.decide(event)) {
      case TvRemoteKeyDecision.passThrough:
        return KeyEventResult.ignored;
      case TvRemoteKeyDecision.suppress:
        return KeyEventResult.handled;
      case TvRemoteKeyDecision.accelerate:
        final direction = _governor.directionOf(event.logicalKey);
        if (direction != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Dpad.of(context).move(direction);
          });
        }
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKeyEvent,
      child: widget.child,
    );
  }
}
