import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    required this.title,
    this.subtitle,
    this.actions,
    this.showLogo = false,
    this.showBackButton = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showLogo;
  final bool showBackButton;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final leading = showBackButton
        ? IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          )
        : showLogo
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Image.asset(
                      'PDF_icon.jpg',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              )
            : null;

    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      toolbarHeight: 72,
      leadingWidth: showBackButton ? 56 : (showLogo ? 64 : null),
      leading: leading,
      titleSpacing: showLogo ? 4 : null,
      foregroundColor: AppColors.primaryRed,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primaryRed,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.titleRed,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      actions: actions,
    );
  }
}