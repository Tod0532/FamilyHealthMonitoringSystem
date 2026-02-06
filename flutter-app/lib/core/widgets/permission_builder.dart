import 'package:flutter/material.dart';
import 'package:health_center_app/core/utils/permission_utils.dart';

/// 权限控制Widget
///
/// 根据权限检查结果决定是否显示子组件
class PermissionBuilder extends StatelessWidget {
  final bool Function() permissionCheck;
  final Widget child;
  final Widget? fallback;

  const PermissionBuilder({
    Key? key,
    required this.permissionCheck,
    required this.child,
    this.fallback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (permissionCheck()) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}

/// 权限控制按钮
///
/// 无权限时点击显示提示，不执行回调
class PermissionButton extends StatelessWidget {
  final bool Function() permissionCheck;
  final VoidCallback onPressed;
  final Widget child;
  final ButtonStyle? style;

  const PermissionButton({
    Key? key,
    required this.permissionCheck,
    required this.onPressed,
    required this.child,
    this.style,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: style,
      onPressed: permissionCheck()
          ? onPressed
          : () => PermissionUtils.showPermissionDeniedTip(),
      child: child,
    );
  }
}

/// 权限控制IconButton
class PermissionIconButton extends StatelessWidget {
  final bool Function() permissionCheck;
  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;
  final Color? color;

  const PermissionIconButton({
    Key? key,
    required this.permissionCheck,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!permissionCheck()) {
      return const SizedBox.shrink();
    }
    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}

/// 权限控制FloatingActionButton
class PermissionFab extends StatelessWidget {
  final bool Function() permissionCheck;
  final VoidCallback onPressed;
  final Widget child;
  final String? tooltip;
  final Object? heroTag;

  const PermissionFab({
    Key? key,
    required this.permissionCheck,
    required this.onPressed,
    required this.child,
    this.tooltip,
    this.heroTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!permissionCheck()) {
      return const SizedBox.shrink();
    }
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      heroTag: heroTag,
      child: child,
    );
  }
}
