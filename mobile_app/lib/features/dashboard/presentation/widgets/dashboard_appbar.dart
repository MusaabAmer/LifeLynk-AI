import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '/features/dashboard/presentation/widgets/profile_avatar.dart';
import '/features/notifications/presentation/providers/notification_provider.dart';
import '../../../../core/router/routes.dart';

class DashboardAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String userName;
  final String profileImage;
  final VoidCallback? onProfileTap;

  const DashboardAppBar({
    super.key,
    required this.userName,
    required this.profileImage,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Keep enough room for the notification action.
    final leadingWidth = screenWidth < 360
        ? 195.0
        : screenWidth < 400
            ? 220.0
            : 240.0;

    return AppBar(
      automaticallyImplyLeading: false,

      // ============================================================
      // RESPONSIVE LEFT SIDE
      // ============================================================

      leadingWidth: leadingWidth,

      leading: Padding(
        padding: const EdgeInsets.only(
          left: 16,
        ),
        child: InkWell(
          onTap: onProfileTap,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              // ----------------------------------------------------
              // PROFILE AVATAR
              // ----------------------------------------------------

              ProfileAvatar(
                imageUrl: profileImage,
                radius: 20,
              ),

              const SizedBox(width: 10),

              // ----------------------------------------------------
              // USER NAME
              // ----------------------------------------------------

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Welcome',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                    ),

                    Text(
                      userName.isEmpty ? 'User' : userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // ============================================================
      // RIGHT SIDE
      // NOTIFICATIONS
      // ============================================================

      actions: [
        Consumer<NotificationProvider>(
          builder: (
            context,
            notificationProvider,
            child,
          ) {
            final unreadCount =
                notificationProvider.unreadCount;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'Notifications',
                  icon: const Icon(
                    Icons.notifications_rounded,
                  ),
                  onPressed: () {
                    context.push(
                      Routes.notifications,
                    );
                  },
                ),

                if (unreadCount > 0)
                  Positioned(
                    right: 5,
                    top: 5,
                    child: Container(
                      constraints:
                          const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.error,
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context)
                              .scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 99
                              ? '99+'
                              : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        const SizedBox(width: 4),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(
        kToolbarHeight,
      );
}