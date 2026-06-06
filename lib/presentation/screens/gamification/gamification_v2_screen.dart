import 'package:flutter/material.dart';
import '../../../core/models/gamification_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import 'widgets/proof_upload_dialog.dart';
import 'widgets/task_acceptance_dialog.dart';
import '../notifications/notifications_screen.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GamificationV2Screen extends StatefulWidget {
  const GamificationV2Screen({super.key});

  @override
  State<GamificationV2Screen> createState() => _GamificationV2ScreenState();
}

class _GamificationV2ScreenState extends State<GamificationV2Screen> {
  final List<DailyTask> _dailyTasks = DailyTask.mockDailyTasks();
  final UserProfile _userProfile = UserProfile.mockCurrentUser();
  int _totalPoints = 0;
  List<QueryDocumentSnapshot> _leaderboardUsers = [];
  int _currentUserRank = 0;

  @override
  void initState() {
    super.initState();
    _totalPoints = _userProfile.totalPoints;
    _loadLeaderboard();
  }

  void _onAcceptTask(DailyTask task) {
    showDialog(
      context: context,
      builder: (_) => TaskAcceptanceDialog(
        task: task,
        onTaskResponse: (accepted) {
          if (accepted) {
            Future.delayed(const Duration(milliseconds: 150), () {
              if (!mounted) return;
              showDialog(
                context: context,
                builder: (_) => ProofUploadDialog(
                  task: task,
                  onProofSubmitted: (proofPath) {
                    if (proofPath != null) {
                      setState(() {
                        task.proofPath = proofPath;
                        task.isCompleted = true;
                        _totalPoints += task.points;
                        _userProfile.totalPoints = _totalPoints;
                        final newLevel = (_totalPoints ~/ 500) + 1;
                        final progressPoints = _totalPoints % 500;
                        _userProfile.level = newLevel;
                        _userProfile.levelProgress =
                            ((progressPoints / 500) * 100).toInt();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '🎉 +${task.points} points earned! Keep it up!'),
                          backgroundColor: const Color(0xFF6D5DF6),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              );
            });
          }
        },
      ),
    );
  }

  Future<void> _loadLeaderboard() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('waterPoints', descending: true)
        .get();

    int rank = 0;
    for (int i = 0; i < snapshot.docs.length; i++) {
      if (snapshot.docs[i].id == currentUid) {
        rank = i + 1;
        break;
      }
    }
    setState(() {
      _leaderboardUsers = snapshot.docs;
      _currentUserRank = rank;
    });
  }

  void _showAllTasksDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "All Tasks",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _dailyTasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final task = _dailyTasks[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: [
                              const Color(0xFFDDD6FE),
                              const Color(0xFFCCFBF1),
                              const Color(0xFFFEF9C3),
                              const Color(0xFFFFE4E6),
                              const Color(0xFFE0F2FE),
                            ][index % 5],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            [
                              Icons.speed_rounded,
                              Icons.water_rounded,
                              Icons.science_rounded,
                              Icons.plumbing_rounded,
                              Icons.edit_note_rounded,
                            ][index % 5],
                            color: [
                              const Color(0xFF6D5DF6),
                              const Color(0xFF0D9488),
                              const Color(0xFFCA8A04),
                              const Color(0xFFE11D48),
                              const Color(0xFF0284C7),
                            ][index % 5],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                task.description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "+${task.points} PTS",
                                style: const TextStyle(
                                  color: Color(0xFF6D5DF6),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 100,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _onAcceptTask(task);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6D5DF6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  "Accept",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showLeaderboardDialog() {
    final medalColors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];
    final avatarColors = [
      const Color(0xFFFBBF24),
      const Color(0xFF60A5FA),
      const Color(0xFFA78BFA),
      const Color(0xFF34D399),
      const Color(0xFFF87171),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Leaderboard",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _leaderboardUsers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final data =
                  _leaderboardUsers[index].data() as Map<String, dynamic>;
                  final uid = _leaderboardUsers[index].id;
                  final currentUid = FirebaseAuth.instance.currentUser?.uid;
                  final isMe = uid == currentUid;
                  final name = (data['displayName'] ?? 'User') as String;
                  final pts = data['waterPoints'] ?? 0;
                  final initials = name
                      .trim()
                      .split(' ')
                      .take(2)
                      .map((w) => w[0].toUpperCase())
                      .join();

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFFF0EEFF)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isMe
                            ? const Color(0xFFCBBEFF)
                            : const Color(0xFFE2E8F0),
                        width: isMe ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Rank badge
                        Container(
                          width: 32,
                          height: 32,
                          decoration: index < 3
                              ? BoxDecoration(
                            shape: BoxShape.circle,
                            color: medalColors[index]
                                .withOpacity(0.15),
                            border: Border.all(
                                color: medalColors[index], width: 2),
                          )
                              : BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: isMe
                                ? const Color(0xFFEDE9FE)
                                : const Color(0xFFF1F5F9),
                          ),
                          child: Center(
                            child: Text(
                              "${index + 1}",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: index < 3
                                    ? medalColors[index]
                                    : isMe
                                    ? const Color(0xFF6D5DF6)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Avatar
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isMe
                                ? const Color(0xFF6D5DF6)
                                : avatarColors[index % avatarColors.length]
                                .withOpacity(0.25),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isMe
                                    ? Colors.white
                                    : avatarColors[
                                index % avatarColors.length],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isMe ? "You" : name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isMe
                                      ? const Color(0xFF6D5DF6)
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              if (isMe)
                                const Text(
                                  "Keep going! 💧",
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                        // Points
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "$pts ",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: isMe
                                      ? const Color(0xFF6D5DF6)
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const TextSpan(
                                text: "PTS",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _bubble(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(opacity),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      indent: 66,
      endIndent: 16,
      color: Color(0xFFF1F5F9),
    );
  }

  @override
  Widget build(BuildContext context) {
    final medalColors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];
    final avatarColors = [
      const Color(0xFFFBBF24),
      const Color(0xFF60A5FA),
      const Color(0xFFA78BFA),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Gamification",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              "Earn points, complete tasks\nand climb the leaderboard!",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Column(
                              children: const [
                                Text(
                                  "✦",
                                  style: TextStyle(
                                      color: Color(0xFF8B5CF6), fontSize: 12),
                                ),
                                Text(
                                  "✦",
                                  style: TextStyle(
                                      color: Color(0xFF8B5CF6), fontSize: 8),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.07),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: Color(0xFF334155),
                            size: 24,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              "3",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Hero Card ────────────────────────────────────────────
              Container(
                width: double.infinity,
                height: 210,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5B4FE8), Color(0xFF38BDF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B4FE8).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(top: 14, right: 140, child: _bubble(10, 0.3)),
                    Positioned(top: 60, right: 110, child: _bubble(7, 0.2)),
                    Positioned(
                        bottom: 40, right: 160, child: _bubble(14, 0.25)),
                    Positioned(top: 30, right: 30, child: _bubble(8, 0.2)),
                    Positioned(
                      right: 10,
                      top: 15,
                      child: Image.asset(
                        "assets/images/trophy.png",
                        width: 135,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      bottom: 54,
                      left: 24,
                      child: Icon(
                        Icons.water_drop,
                        size: 22,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    Positioned(
                      top: 24,
                      left: 24,
                      right: 150,
                      bottom: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  "Rank #$_currentUserRank",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                "$_totalPoints",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.water_drop,
                                  color: Colors.white70, size: 20),
                            ],
                          ),
                          const Text(
                            "Total Water Points",
                            style: TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Level ${_userProfile.level}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                "${_userProfile.levelProgress}% to Level ${_userProfile.level + 1}",
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _userProfile.levelProgress / 100,
                              minHeight: 8,
                              backgroundColor:
                              Colors.white.withValues(alpha: 0.25),
                              valueColor:
                              const AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${_userProfile.levelProgress * 50} / 5,000 XP",
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Daily Assignment Header ───────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.assignment_outlined,
                            color: Color(0xFF6D5DF6), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Daily Assignment",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _showAllTasksDialog,
                    child: Row(
                      children: const [
                        Text("View All",
                            style: TextStyle(
                                color: Color(0xFF6D5DF6),
                                fontWeight: FontWeight.w600)),
                        Icon(Icons.chevron_right,
                            color: Color(0xFF6D5DF6), size: 18),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Task Cards Row ────────────────────────────────────────
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _dailyTasks.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final task = _dailyTasks[index];
                    final icons = [
                      Icons.speed_rounded,
                      Icons.water_rounded,
                      Icons.science_rounded,
                      Icons.plumbing_rounded,
                      Icons.edit_note_rounded,
                    ];
                    final iconBgs = [
                      const Color(0xFFDDD6FE),
                      const Color(0xFFCCFBF1),
                      const Color(0xFFFEF9C3),
                      const Color(0xFFFFE4E6),
                      const Color(0xFFE0F2FE),
                    ];
                    final iconColors = [
                      const Color(0xFF6D5DF6),
                      const Color(0xFF0D9488),
                      const Color(0xFFCA8A04),
                      const Color(0xFFE11D48),
                      const Color(0xFF0284C7),
                    ];
                    return SizedBox(
                      width: 160,
                      child: _TaskCard(
                        pts: "+${task.points} PTS",
                        onAccept: () => _onAcceptTask(task),
                        icon: icons[index % icons.length],
                        iconBg: iconBgs[index % iconBgs.length],
                        iconColor: iconColors[index % iconColors.length],
                        cardBg: Colors.white,
                        title: task.title,
                        subtitle: task.description,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),

              // ── Your Rank Header ────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bar_chart_rounded,
                            color: Color(0xFF6D5DF6), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Your Rank",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _showLeaderboardDialog,
                    child: Row(
                      children: const [
                        Text("View All",
                            style: TextStyle(
                                color: Color(0xFF6D5DF6),
                                fontWeight: FontWeight.w600)),
                        Icon(Icons.chevron_right,
                            color: Color(0xFF6D5DF6), size: 18),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Leaderboard ─────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    // Top 3 from Firestore
                    ..._leaderboardUsers.take(3).toList().asMap().entries.map(
                          (entry) {
                        final index = entry.key;
                        final data =
                        entry.value.data() as Map<String, dynamic>;
                        final name =
                        (data['displayName'] ?? 'User') as String;
                        final pts = data['waterPoints'] ?? 0;
                        final initials = name
                            .trim()
                            .split(' ')
                            .take(2)
                            .map((w) => w[0].toUpperCase())
                            .join();
                        return Column(
                          children: [
                            _LeaderboardRow(
                              rank: index + 1,
                              initials: initials,
                              name: name,
                              pts: pts.toString(),
                              avatarColor: avatarColors[index],
                              isUp: index < 2,
                              medalColor: medalColors[index],
                            ),
                            _divider(),
                          ],
                        );
                      },
                    ).toList(),

                    // "You" row
                    Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EEFF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: const Color(0xFFCBBEFF), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                "$_currentUserRank",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6D5DF6),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFF6D5DF6),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                "AK",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "You",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF6D5DF6),
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  "Keep going, Aditya! 💧",
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: "$_totalPoints ",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF6D5DF6),
                                    fontSize: 15,
                                  ),
                                ),
                                const TextSpan(
                                  text: "PTS",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_upward_rounded,
                              color: Color(0xFF16A34A),
                              size: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Task Card Widget ─────────────────────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  final String pts;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color cardBg;
  final String title;
  final String subtitle;
  final VoidCallback onAccept;

  const _TaskCard({
    required this.pts,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.cardBg,
    required this.title,
    required this.subtitle,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  pts,
                  style: const TextStyle(
                    color: Color(0xFF6D5DF6),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const Icon(Icons.favorite_border_rounded,
                  color: Colors.grey, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration:
              BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, color: iconColor, size: 26),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border:
                        Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 10, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11, color: Colors.grey, height: 1.3),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D5DF6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                elevation: 0,
              ),
              child: const Text(
                "Accept Task",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Leaderboard Row Widget ──────────────────────────────────────────────────
class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final String initials;
  final String name;
  final String pts;
  final Color avatarColor;
  final bool isUp;
  final Color medalColor;

  const _LeaderboardRow({
    required this.rank,
    required this.initials,
    required this.name,
    required this.pts,
    required this.avatarColor,
    required this.isUp,
    required this.medalColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: _MedalBadge(rank: rank, color: medalColor),
          ),
          const SizedBox(width: 10),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: avatarColor,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "$pts ",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                  ),
                ),
                const TextSpan(
                  text: "PTS",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color:
              isUp ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUp
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: isUp
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626),
              size: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Medal Badge Widget ──────────────────────────────────────────────────────
class _MedalBadge extends StatelessWidget {
  final int rank;
  final Color color;

  const _MedalBadge({required this.rank, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          "$rank",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: color,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}