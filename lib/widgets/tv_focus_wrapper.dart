import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/tv_detector.dart';

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
                          BoxShadow(
                            color: widget.focusBorderColor.withOpacity(0.2 * _glowAnim.value),
                            blurRadius: 8, spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: widget.focusBorderColor.withOpacity(0.15 * _glowAnim.value),
                            blurRadius: 20, spreadRadius: 2,
                          ),
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

/// TextField pour TV avec FocusScope isole
/// Le TextField est dans son propre FocusScope pour que les fleches
/// ne sortent jamais du champ. Le focus est piege dedans.
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
  });

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  late FocusNode _textFieldFocus;
  late FocusNode _wrapperFocus;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _textFieldFocus = FocusNode();
    _wrapperFocus = FocusNode();
  }

  @override
  void dispose() {
    _textFieldFocus.dispose();
    _wrapperFocus.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() => _isEditing = true);
    _textFieldFocus.requestFocus();
    // Force le clavier a s'ouvrir
    Future.delayed(const Duration(milliseconds: 100), () {
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  void _stopEditing() {
    setState(() => _isEditing = false);
    _textFieldFocus.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    // Rendre le focus au wrapper
    Future.delayed(const Duration(milliseconds: 100), () {
      _wrapperFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTV = TvDetector.isTV;

    final field = TextField(
      controller: widget.controller,
      focusNode: _textFieldFocus,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      obscureText: widget.obscureText,
      maxLength: widget.maxLength,
      autofocus: !isTV && widget.autofocus,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      style: widget.style ?? const TextStyle(color: Colors.white),
      onSubmitted: (val) {
        if (isTV) _stopEditing();
        widget.onSubmitted?.call(val);
      },
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF448AFF), width: 2),
        ),
      ),
    );

    if (!isTV) return field;

    // Mode TV : deux etats
    // 1) Pas en edition : le wrapper a le focus, OK demarre l'edition
    // 2) En edition : le TextField a le focus, le clavier est ouvert
    //    Back/Enter ferme et revient au wrapper

    if (_isEditing) {
      // En mode edition : on piege le focus dans un FocusScope
      return FocusScope(
        child: Focus(
          onKey: (node, event) {
            if (event is RawKeyDownEvent) {
              // Back ferme l'edition
              if (event.logicalKey == LogicalKeyboardKey.goBack ||
                  event.logicalKey == LogicalKeyboardKey.escape ||
                  event.logicalKey == LogicalKeyboardKey.browserBack) {
                _stopEditing();
                return KeyEventResult.handled;
              }
              // Bloquer haut/bas pour pas sortir
              if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                  event.logicalKey == LogicalKeyboardKey.arrowDown) {
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF00E5FF), width: 3),
              boxShadow: [
                BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.4), blurRadius: 16, spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                field,
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                  ),
                  child: const Text(
                    'Tapez avec la telecommande \u2022 BACK pour fermer',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Mode wrapper : affiche le texte actuel, OK pour editer
    final currentText = widget.controller?.text ?? '';
    return Focus(
      focusNode: _wrapperFocus,
      autofocus: widget.autofocus,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            _startEditing();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      onFocusChange: (hasFocus) {
        setState(() {});
      },
      child: GestureDetector(
        onTap: _startEditing,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white10,
            border: Border.all(
              color: _wrapperFocus.hasFocus ? const Color(0xFF00E5FF) : Colors.white24,
              width: _wrapperFocus.hasFocus ? 2.5 : 1,
            ),
            boxShadow: _wrapperFocus.hasFocus
                ? [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.25), blurRadius: 12, spreadRadius: 1)]
                : [],
          ),
          child: Row(
            children: [
              if (widget.decoration?.prefixIcon != null) ...[
                widget.decoration!.prefixIcon!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  currentText.isEmpty ? (widget.labelText ?? widget.hintText ?? 'Appuyez OK pour ecrire') : currentText,
                  style: TextStyle(
                    color: currentText.isEmpty ? Colors.white38 : Colors.white,
                    fontSize: (widget.style?.fontSize ?? 16),
                  ),
                ),
              ),
              if (_wrapperFocus.hasFocus)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('OK', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
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
