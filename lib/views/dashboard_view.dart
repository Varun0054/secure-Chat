import 'package:flutter/material.dart';
import '../../controller/dashboard_controller.dart';
import '../../components/glass_container.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final DashboardController _controller = DashboardController();

  @override
  void initState() {
    super.initState();
    _controller.fetchUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        if (_controller.isLoading) {
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Stack(
            children: [
              // Background Elements (Reuse from Login or simplified)
              Positioned(
                top: -100,
                left: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        (isDark ? const Color(0xFF7B61FF) : Colors.blueAccent)
                            .withValues(alpha: 0.2),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isDark
                                    ? const Color(0xFF7B61FF)
                                    : Colors.blueAccent)
                                .withValues(alpha: 0.2),
                        blurRadius: 100,
                        spreadRadius: 50,
                      ),
                    ],
                  ),
                ),
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      // --- Header Section ---
                      _buildHeader(context),
                      const SizedBox(height: 10),

                      // --- Pending Requests Section ---
                      if (_controller.pendingRequests.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Pending Requests",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _controller.pendingRequests.length,
                            separatorBuilder: (c, i) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final req = _controller.pendingRequests[index];
                              final profile = req['profiles'] ?? {};
                              final name = profile['username'] ?? 'User';

                              return GlassContainer(
                                width: 220,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      child: Text(name[0].toUpperCase()),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.check,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          _controller.acceptRequest(req['id']),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          _controller.rejectRequest(req['id']),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // --- Chat List Section ---
                      if (_controller.friends.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _controller.isOffline ? Icons.wifi_off_rounded : Icons.people_outline,
                                  size: 48,
                                  color: theme.iconTheme.color?.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _controller.isOffline ? "No internet connection" : "No friends yet",
                                  style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withValues(alpha: 0.4),
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (!_controller.isOffline)
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/search');
                                    },
                                    child: const Text("Find People"),
                                  )
                                else
                                  ElevatedButton(
                                    onPressed: () {
                                      _controller.fetchUserProfile();
                                    },
                                    child: const Text("Retry Sync"),
                                  ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: _controller.friends.length,
                            separatorBuilder: (c, i) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final friend = _controller.friends[index];
                              final friendName =
                                  friend['username'] ?? 'Unknown';
                              return GlassContainer(
                                onTap: () {
                                  // Resolve or create room before navigation
                                  _controller
                                      .getOrCreateRoom(friend['id'])
                                      .then((roomId) {
                                        if (!context.mounted) return;
                                        if (roomId != null) {
                                          Navigator.pushNamed(
                                            context,
                                            '/chat',
                                            arguments: {
                                              'username': friendName,
                                              'id': friend['id'],
                                              'roomId': roomId,
                                            },
                                          );
                                        } else {
                                          // Offline with no prior conversation cached
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'You\'re offline. Open this chat online first to enable offline access.',
                                              ),
                                            ),
                                          );
                                        }
                                      });
                                },
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: theme.iconTheme.color
                                          ?.withValues(alpha: 0.1),
                                      child: Text(
                                        friendName[0].toUpperCase(),
                                        style: TextStyle(
                                          color:
                                              theme.textTheme.bodyLarge?.color,
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
                                            friendName,
                                            style: TextStyle(
                                              color: theme
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.color,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            friend['email'] ?? '',
                                            style: TextStyle(
                                              color: theme
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color
                                                  ?.withValues(alpha: 0.6),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      color: theme.iconTheme.color?.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // --- Floating Action Button ---
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Center(
                  child: GlassContainer(
                    onTap: () {
                      Navigator.pushNamed(context, '/search');
                    },
                    borderRadius: 30,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_comment_rounded,
                          color: theme.iconTheme.color,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Start Chat",
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return GlassContainer(
      onTap: () {
        Navigator.pushNamed(context, '/profile');
      },
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blueAccent.withValues(alpha: 0.5),
                  Colors.purpleAccent.withValues(alpha: 0.5),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Icon(Icons.person, color: Colors.white)),
          ),
          const SizedBox(width: 16),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome back,",
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _controller.username ?? "User",
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Settings/Profile Icon
          IconButton(
            icon: Icon(Icons.settings, color: theme.iconTheme.color),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
    );
  }
}
