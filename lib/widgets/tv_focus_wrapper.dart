import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/tv_detector.dart';
import 'tv_keyboard.dart';

class TvFocusWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double focusBorderWidth;
  final Color focusBorderColor;
  final double borderRadius;
  final bool autofocus;
  final double focusScale;
  final double? order;

  const TvFocusWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.focusBorderWidth = 2.5,
    this.focusBorderColor = const Color(0xFF448AFF),
    this.borderRadius = 14,
    this.autofocus = false,
    this.focusScale = 1.04,
    this.order,
  });

  @override
  State<TvFocusWrapper> createState() => _TvFocusWrapperState();
}

class _TvFocusWrapperState extends State<TvFocusWrapper>
    with SingleTickerProviderStateMixin {
  bool _isFocused = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool hasFocus) {
    setState(() => _isFocused = hasFocus);
    if (hasFocus) {
      _glowController.repeat(reverse: true);
    } else {
      _glowController.stop();
      _glowController.value = 0.0;
    }
  }

  KeyEventResult _handleKey(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        widget.onTap?.call();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    Widget focusWidget = Focus(
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
      onKey: _handleKey,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _glowAnim,
          builder: (context, child) {
            return AnimatedScale(
              scale: _isFocused ? widget.focusScale : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: _isFocused
                      ? Border.all(
                          color: widget.focusBorderColor.withOpacity(_glowAnim.value),
                          width: widget.focusBorderWidth,
                        )
                      : Border.all(color: Colors.transparent, width: widget.focusBorderWidth),
                  boxShadow: _isFocused
                      ? [
                          BoxShadow(color: widget.focusBorderColor.withOpacity(0.2 * _glowAnim.value), blurRadius: 8, spreadRadius: 1),
                          BoxShadow(color: widget.focusBorderColor.withOpacity(0.15 * _glowAnim.value), blurRadius: 20, spreadRadius: 2),
                        ]
                      : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius - widget.focusBorderWidth),
                  child: child,
                ),
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );

    if (widget.order != null) {
      focusWidget = FocusTraversalOrder(
        order: NumericFocusOrder(widget.order!),
        child: focusWidget,
      );
    }

    return focusWidget;
  }
}

class TvTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLength;
  final bool autofocus;
  final TextAlign textAlign;
  final TextStyle? style;
  final InputDecoration? decoration;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final String? keyboardTitle;

  const TvTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLength,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.style,
    this.decoration,
    this.onSubmitted,
    this.onChanged,
    this.maxLines = 1,
    this.keyboardTitle,
  });

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  late TextEditingController _ctrl;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? TextEditingController();
    _focusNode = FocusNode();
    _ctrl.addListener(() {
      if (mounted) setState(() {});
      widget.onChanged?.call(_ctrl.text);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  void _openTvKeyboard() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, anim, secondAnim) {
          return _TvKeyboardOverlay(
            controller: _ctrl,
            title: widget.keyboardTitle ?? widget.labelText ?? 'Saisir du texte',
            onDone: () {
              Navigator.of(context).pop();
              widget.onSubmitted?.call(_ctrl.text);
              // Restore focus to this field
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) _focusNode.requestFocus();
              });
            },
            onCancel: () {
              Navigator.of(context).pop();
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) _focusNode.requestFocus();
              });
            },
          );
        },
        transitionsBuilder: (context, anim, secondAnim, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!TvDetector.isTV) {
      return TextField(
        controller: _ctrl,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        obscureText: widget.obscureText,
        maxLength: widget.maxLength,
        autofocus: widget.autofocus,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        style: widget.style ?? const TextStyle(color: Colors.white),
        onSubmitted: widget.onSubmitted,
        onChanged: widget.onChanged,
        decoration: widget.decoration ?? InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          labelStyle: const TextStyle(color: Colors.white60),
          hintStyle: const TextStyle(color: Colors.white30),
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.suffixIcon,
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF448AFF), width: 2)),
        ),
      );
    }

    final currentText = _ctrl.text;
    final displayText = widget.obscureText && currentText.isNotEmpty
        ? '\u2022' * currentText.length
        : currentText;

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            _openTvKeyboard();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      onFocusChange: (_) => setState(() {}),
      child: GestureDetector(
        onTap: _openTvKeyboard,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white10,
            border: Border.all(
              color: _focusNode.hasFocus ? const Color(0xFF00E5FF) : Colors.white24,
              width: _focusNode.hasFocus ? 2.5 : 1,
            ),
            boxShadow: _focusNode.hasFocus
                ? [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.25), blurRadius: 12, spreadRadius: 1)]
                : [],
          ),
          child: Row(
            children: [
              if (widget.prefixIcon != null) ...[
                widget.prefixIcon!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  displayText.isEmpty ? (widget.hintText ?? widget.labelText ?? 'Appuyez OK pour ecrire') : displayText,
                  style: TextStyle(
                    color: displayText.isEmpty ? Colors.white38 : Colors.white,
                    fontSize: (widget.style?.fontSize ?? 16),
                  ),
                ),
              ),
              if (_focusNode.hasFocus)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.keyboard, color: Color(0xFF00E5FF), size: 16),
                    SizedBox(width: 4),
                    Text('OK', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.bold)),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlay plein ecran qui contient le TvKeyboard avec son propre FocusScope
class _TvKeyboardOverlay extends StatelessWidget {
  final TextEditingController controller;
  final String title;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  const _TvKeyboardOverlay({
    required this.controller,
    required this.title,
    required this.onDone,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FocusScope(
        autofocus: true,
        child: Column(
          children: [
            // Zone du haut : tap pour fermer
            Expanded(
              child: GestureDetector(
                onTap: onCancel,
                child: Container(color: Colors.transparent),
              ),
            ),
            // Clavier en bas
            TvKeyboard(
              controller: controller,
              title: title,
              onDone: onDone,
            ),
          ],
        ),
      ),
    );
  }
}

class TvFocusScope extends StatelessWidget {
  final Widget child;
  final bool autofocus;

  const TvFocusScope({
    super.key,
    required this.child,
    this.autofocus = true,
  });

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      autofocus: autofocus,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: child,
      ),
    );
  }
}

class TvKeyboardHandler extends StatelessWidget {
  final Widget child;
  const TvKeyboardHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: (_) {},
      child: Actions(
        actions: {
          ActivateIntent: _TvActivateAction(),
          ButtonActivateIntent: _TvButtonActivateAction(),
        },
        child: child,
      ),
    );
  }
}

class _TvActivateAction extends Action<ActivateIntent> {
  @override
  bool isEnabled(ActivateIntent intent) => true;
  @override
  Object? invoke(ActivateIntent intent) => null;
}

class _TvButtonActivateAction extends Action<ButtonActivateIntent> {
  @override
  bool isEnabled(ButtonActivateIntent intent) => true;
  @override
  Object? invoke(ButtonActivateIntent intent) => null;
}
