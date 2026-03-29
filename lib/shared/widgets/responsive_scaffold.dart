import 'package:flutter/material.dart';
import '../../app/theme/app_dimensions.dart';

/// Responsive scaffold that adapts to tablet/desktop widths.
/// On narrow screens, behaves like a regular Scaffold.
/// On wide screens (>= 600dp), centers content with max width constraint.
class ResponsiveScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final Color? backgroundColor;
  final bool centerContent;

  const ResponsiveScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.drawer,
    this.backgroundColor,
    this.centerContent = true,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = AppDimensions.isTablet(context);
    final maxWidth = AppDimensions.maxContentWidth(context);

    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      drawer: isWide ? null : drawer,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: isWide && centerContent
          ? Row(
              children: [
                if (drawer != null) SizedBox(width: 280, child: drawer!),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: body,
                    ),
                  ),
                ),
              ],
            )
          : body,
    );
  }
}
