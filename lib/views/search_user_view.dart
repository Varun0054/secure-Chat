import 'package:flutter/material.dart';
import '../../controller/search_user_controller.dart';
import '../../components/glass_container.dart';
import '../../utils/chat_utils.dart';

class SearchUserView extends StatefulWidget {
  const SearchUserView({super.key});

  @override
  State<SearchUserView> createState() => _SearchUserViewState();
}

class _SearchUserViewState extends State<SearchUserView> {
  final _controller = SearchUserController();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Elements
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? Colors.cyanAccent : Colors.blue).withValues(
                  alpha: 0.15,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.cyanAccent : Colors.blue)
                        .withValues(alpha: 0.15),
                    blurRadius: 80,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back_ios,
                      color: theme.iconTheme.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    "Find People",
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Search Input
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                      decoration: InputDecoration(
                        hintText: 'Search username...',
                        hintStyle: TextStyle(
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: theme.iconTheme.color),
                      ),
                      onChanged: (value) {
                        // Debounce could be added here
                        _controller.searchUsers(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Results List
                  Expanded(
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (context, child) {
                        if (_controller.isLoading) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: theme.iconTheme.color,
                            ),
                          );
                        }

                        if (_controller.errorMessage != null) {
                          return Center(
                            child: Text(
                              _controller.errorMessage!,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          );
                        }

                        if (_controller.searchResults.isEmpty) {
                          if (_searchController.text.isNotEmpty) {
                            return Center(
                              child: Text(
                                "User not found",
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.4),
                                ),
                              ),
                            );
                          }
                          return Center(
                            child: Text(
                              "Search users by username",
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.4),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: _controller.searchResults.length,
                          separatorBuilder: (c, i) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final user = _controller.searchResults[index];
                            final userId = user['id'];
                            final status = _controller.friendStatus[userId];

                            return GlassContainer(
                              onTap: () {
                                if (status == 'accepted') {
                                  ChatUtils.getOrCreateRoom(user['id']).then((
                                    roomId,
                                  ) {
                                    if (roomId != null && context.mounted) {
                                      Navigator.pushNamed(
                                        context,
                                        '/chat',
                                        arguments: {
                                          'username': user['username'],
                                          'id': user['id'],
                                          'roomId': roomId,
                                        },
                                      );
                                    }
                                  });
                                }
                              },
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: theme.iconTheme.color
                                        ?.withValues(alpha: 0.1),
                                    child: Text(
                                      (user['username'] as String)[0]
                                          .toUpperCase(),
                                      style: TextStyle(
                                        color: theme.textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      user['username'],
                                      style: TextStyle(
                                        color: theme.textTheme.bodyLarge?.color,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (status == 'accepted')
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  else if (status == 'pending')
                                    Text(
                                      "Request Sent",
                                      style: TextStyle(
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.6),
                                        fontSize: 12,
                                      ),
                                    )
                                  else if (status == 'received')
                                    Text(
                                      "Request Received",
                                      style: TextStyle(
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.6),
                                        fontSize: 12,
                                      ),
                                    )
                                  else
                                    ElevatedButton(
                                      onPressed: () async {
                                        final success = await _controller
                                            .sendFriendRequest(userId);
                                        if (context.mounted) {
                                          if (success) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Friend request sent!',
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  _controller.errorMessage ??
                                                      'Failed to send request',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text("Add"),
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
