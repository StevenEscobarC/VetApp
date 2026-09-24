import 'package:flutter/material.dart';

/// Standard top bar. Wraps [AppBar] so screens don't restate
/// `centerTitle`/`elevation` — those already come from [AppTheme].
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return AppBar(title: Text(title), actions: actions);
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
