import 'package:flutter/material.dart';
import 'package:trainware/utils/general_utils.dart';

/// Full-bleed gradient shell for NOTA screens.
///
/// Uses [SizedBox.expand] so the background always fills the viewport; a
/// [Container] with only `height: double.infinity` can leave gaps on the sides.
class NotaScreenScaffold extends StatelessWidget {
  const NotaScreenScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.padding,
    this.resizeToAvoidBottomInset = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final EdgeInsetsGeometry? padding;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    Widget content = body;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: appBar != null,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: themeGradient(context: context)),
          child: SafeArea(child: content),
        ),
      ),
    );
  }
}

/// Transparent app bar matching the NOTA gradient screens.
PreferredSizeWidget notaAppBar({
  String? title,
  List<Widget>? actions,
}) {
  return AppBar(
    title: title != null ? Text(title) : null,
    centerTitle: true,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    actions: actions,
  );
}
