import 'package:flutter/material.dart';
import '../../controller/profile_controller.dart';
import '../../controller/theme_controller.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final ProfileController _controller = ProfileController();

  @override
  void initState() {
    super.initState();
    _controller.fetchUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeController = ThemeController();
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, child) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Premium Hero Header
              SliverAppBar(
                expandedHeight: 280.0,
                pinned: true,
                stretch: true,
                backgroundColor: isDark
                    ? const Color(0xFF0F1223)
                    : Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Vibrant Gradient Cover
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [
                                    Colors.purpleAccent.shade700.withValues(
                                      alpha: 0.6,
                                    ),
                                    Colors.blueAccent.shade700.withValues(
                                      alpha: 0.8,
                                    ),
                                  ]
                                : [
                                    Colors.purpleAccent.shade100,
                                    Colors.blueAccent.shade100,
                                  ],
                          ),
                        ),
                      ),
                      // Glassy Overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                theme.scaffoldBackgroundColor,
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Avatar and Info Centered
                      Positioned(
                        bottom: 40,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? Colors.white10 : Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                                border: Border.all(
                                  color: theme.scaffoldBackgroundColor,
                                  width: 4,
                                ),
                              ),
                              child: ClipOval(
                                child: Container(
                                  color: theme.primaryColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: 55,
                                    color: isDark
                                        ? Colors.white
                                        : theme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _controller.username ?? "Loading...",
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "SecureChat User",
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Friend Requests Section
                      if (_controller.friendRequests.isNotEmpty) ...[
                        Text(
                          "Friend Requests",
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color?.withValues(
                              alpha: 0.8,
                            ),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _controller.friendRequests.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final request = _controller.friendRequests[index];
                            final senderProfile =
                                request['profiles'] as Map<String, dynamic>?;
                            final senderName =
                                senderProfile?['username'] ?? 'Unknown';
                            final requestId = request['id'];

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E2235)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  if (!isDark)
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: theme.primaryColor
                                        .withValues(alpha: 0.1),
                                    child: Text(
                                      senderName[0].toUpperCase(),
                                      style: TextStyle(
                                        color: theme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          senderName,
                                          style: TextStyle(
                                            color: theme
                                                .textTheme
                                                .bodyLarge
                                                ?.color,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          "wants to be friends",
                                          style: TextStyle(
                                            color: theme
                                                .textTheme
                                                .bodyMedium
                                                ?.color
                                                ?.withValues(alpha: 0.6),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildActionButton(
                                        icon: Icons.close_rounded,
                                        color: Colors.redAccent,
                                        backgroundColor: Colors.redAccent
                                            .withValues(alpha: 0.1),
                                        onPressed: () async {
                                          final success = await _controller
                                              .rejectFriendRequest(requestId);
                                          if (!context.mounted) return;
                                          _showSnackBar(
                                            context,
                                            success,
                                            "Friend request rejected",
                                            "Failed to reject request",
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _buildActionButton(
                                        icon: Icons.check_rounded,
                                        color: Colors.green,
                                        backgroundColor: Colors.green
                                            .withValues(alpha: 0.1),
                                        onPressed: () async {
                                          final success = await _controller
                                              .acceptFriendRequest(requestId);
                                          if (!context.mounted) return;
                                          _showSnackBar(
                                            context,
                                            success,
                                            "Friend request accepted!",
                                            "Failed to accept request",
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Settings grouped card
                      Text(
                        "Settings",
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color?.withValues(
                            alpha: 0.8,
                          ),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E2235)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Theme Toggle Tile
                            ListenableBuilder(
                              listenable: themeController,
                              builder: (context, _) {
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.purpleAccent.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      themeController.isDarkMode
                                          ? Icons.dark_mode_rounded
                                          : Icons.light_mode_rounded,
                                      color: Colors.purpleAccent,
                                      size: 22,
                                    ),
                                  ),
                                  title: Text(
                                    "Dark Mode",
                                    style: TextStyle(
                                      color: theme.textTheme.bodyLarge?.color,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  trailing: Switch(
                                    value: themeController.isDarkMode,
                                    activeTrackColor: Colors.purpleAccent,
                                    onChanged: (value) =>
                                        themeController.toggleTheme(value),
                                  ),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(24),
                                      topRight: Radius.circular(24),
                                    ),
                                  ),
                                  onTap: () => themeController.toggleTheme(
                                    !themeController.isDarkMode,
                                  ),
                                );
                              },
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              indent: 64,
                              color: theme.dividerColor.withValues(alpha: 0.1),
                            ),
                            // Optional placeholder for future settings
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              title: Text(
                                "Account Guidelines",
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.blueAccent,
                                  size: 22,
                                ),
                              ),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: theme.iconTheme.color?.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(24),
                                  bottomRight: Radius.circular(24),
                                ),
                              ),
                              onTap: () {
                                // Placeholder action
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Guidelines coming soon"),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Elegant Logout Button
                      InkWell(
                        onTap: () => _controller.logout(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                color: Colors.redAccent,
                              ),
                              SizedBox(width: 12),
                              Text(
                                "Log Out",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 48), // Bottom padding
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  void _showSnackBar(
    BuildContext context,
    bool success,
    String successMsg,
    String failMsg,
  ) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? successMsg : failMsg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: success ? Colors.green.shade800 : Colors.red.shade800,
      ),
    );
  }
}
