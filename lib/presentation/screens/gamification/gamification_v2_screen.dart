import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/gamification_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import 'widgets/proof_upload_dialog.dart';
import 'widgets/task_acceptance_dialog.dart';
import '../notifications/notifications_screen.dart';
import 'dart:io';

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

  static const _medalColors = [
    Color(0xFFFFD700),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
  ];
  static const _avatarColors = [
    Color(0xFFFBBF24),
    Color(0xFF60A5FA),
    Color(0xFFA78BFA),
    Color(0xFF34D399),
    Color(0xFFF87171),
  ];

  @override
  void initState() {
    super.initState();
    _totalPoints = _userProfile.totalPoints;
    _loadLeaderboard();
  }

  void _onAcceptTask(DailyTask task) {
    final l = AppLocalizations.of(context)!;
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
                            '🎉 +${task.points} points earned! Keep it up!',
                          ),
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

  void _showLeaderboardDialog() {
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
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFFF0EEFF) : Colors.white,
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
                                  color: _medalColors[index].withOpacity(0.15),
                                  border: Border.all(
                                    color: _medalColors[index],
                                    width: 2,
                                  ),
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
                                    ? _medalColors[index]
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
                                : _avatarColors[index % _avatarColors.length]
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
                                    : _avatarColors[index %
                                          _avatarColors.length],
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
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
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
    final l = AppLocalizations.of(context)!;
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
                        Text(
                          l.get('gamification'),
                          style: const TextStyle(
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
                        child: const Icon(
                          Icons.assignment_outlined,
                          color: Color(0xFF6D5DF6),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l.get('daily_assignment'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Task Cards List ────────────────────────────────────────
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _dailyTasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final task = _dailyTasks[index];
                  return _TaskCard(
                    pts: "+${task.points} ${l.get('pts')}",
                    onAccept: () => _onAcceptTask(task),
                    title: task.title,
                    subtitle: task.description,
                  );
                },
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
                        child: const Icon(
                          Icons.bar_chart_rounded,
                          color: Color(0xFF6D5DF6),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l.get('your_rank'),
                        style: const TextStyle(
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
                        Text(
                          "View All",
                          style: TextStyle(
                            color: Color(0xFF6D5DF6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Color(0xFF6D5DF6),
                          size: 18,
                        ),
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
                    ..._leaderboardUsers.take(3).toList().asMap().entries.map((
                      entry,
                    ) {
                      final index = entry.key;
                      final data = entry.value.data() as Map<String, dynamic>;
                      final name = (data['displayName'] ?? 'User') as String;
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
                            avatarColor: _avatarColors[index],
                            isUp: index < 2,
                            medalColor: _medalColors[index],
                          ),
                          _divider(),
                        ],
                      );
                    }).toList(),

                    // "You" row
                    Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.black,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                "$_currentUserRank",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
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
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                (FirebaseAuth.instance.currentUser?.displayName ?? 'User').trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join(),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  FirebaseAuth.instance.currentUser?.displayName ?? 'User',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  "Keep going, ${(FirebaseAuth.instance.currentUser?.displayName ?? 'User').split(' ').first}! 💧",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
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
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                                const TextSpan(
                                  text: "PTS",
                                  style: TextStyle(
                                    color: Colors.white70,
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
  final String title;
  final String subtitle;
  final VoidCallback onAccept;

  const _TaskCard({
    required this.pts,
    required this.title,
    required this.subtitle,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  pts,
                  style: const TextStyle(
                    color: Color(0xFF6D5DF6),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 90,
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.get('accept_task_btn'),
                    style: const TextStyle(
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
              color: isUp ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: isUp ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
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
