import 'package:flutter/material.dart';
import '../../../core/models/notification_data.dart';
import '../../../core/theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late List<NotificationItem> _notifications;
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Alert', 'Task', 'Achievement', 'Community'];

  @override
  void initState() {
    super.initState();
    _notifications = NotificationItem.mockNotifications();
  }

  List<NotificationItem> _getFilteredNotifications() {
    if (_selectedFilter == 'All') {
      return _notifications;
    }
    return _notifications
        .where((notification) => notification.type.toLowerCase() == _selectedFilter.toLowerCase())
        .toList();
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'alert':
        return AppColors.warning;
      case 'task':
        return AppColors.primary;
      case 'achievement':
        return Color(0xFF4CAF50);
      case 'community':
        return Colors.yellow;
      default:
        return AppColors.mediumGrey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'alert':
        return Icons.warning_rounded;
      case 'task':
        return Icons.assignment_rounded;
      case 'achievement':
        return Icons.emoji_events_rounded;
      case 'community':
        return Icons.people_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotifications = _getFilteredNotifications();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.darkGrey,
          ),
        ),
        centerTitle: true,
        actions: [
          if (filteredNotifications.any((n) => !n.isRead))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _notifications = _notifications
                          .map((n) => NotificationItem(
                                id: n.id,
                                title: n.title,
                                message: n.message,
                                type: n.type,
                                icon: n.icon,
                                timestamp: n.timestamp,
                                isRead: true,
                              ))
                          .toList();
                    });
                  },
                  child: const Text(
                    'Mark All Read',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      backgroundColor: Colors.white,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppColors.mediumGrey,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.mediumGrey.withOpacity(0.3),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Notifications List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: filteredNotifications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            Icon(
                              Icons.notifications_off_rounded,
                              size: 48,
                              color: AppColors.mediumGrey.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No notifications yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mediumGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: List.generate(
                        filteredNotifications.length,
                        (index) {
                          final notification = filteredNotifications[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index < filteredNotifications.length - 1
                                  ? 12
                                  : 32,
                            ),
                            child: _buildNotificationCard(notification),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    final typeColor = _getTypeColor(notification.type);
    final typeIcon = _getTypeIcon(notification.type);

    return GestureDetector(
      onTap: () {
        setState(() {
          _notifications = _notifications
              .map((n) => n.id == notification.id
                  ? NotificationItem(
                      id: n.id,
                      title: n.title,
                      message: n.message,
                      type: n.type,
                      icon: n.icon,
                      timestamp: n.timestamp,
                      isRead: true,
                    )
                  : n)
              .toList();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: notification.isRead
              ? Border.all(color: AppColors.lightGrey)
              : Border.all(
                  color: typeColor.withOpacity(0.3),
                  width: 1.5,
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                  notification.isRead ? 0.04 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  typeIcon,
                  color: typeColor,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGrey,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mediumGrey,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(notification.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mediumGrey.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
