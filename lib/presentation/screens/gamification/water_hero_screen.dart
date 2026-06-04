import 'package:flutter/material.dart';
import '../../../core/models/gamification_data.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import 'widgets/proof_upload_dialog.dart';
import 'dart:io';

class WaterHeroScreen extends StatefulWidget {
  const WaterHeroScreen({Key? key}) : super(key: key);

  @override
  State<WaterHeroScreen> createState() => _WaterHeroScreenState();
}

class _WaterHeroScreenState extends State<WaterHeroScreen> {
  late UserProfile _userProfile;
  late List<DailyTask> _dailyTasks;
  late List<RankingUser> _rankings;
  int _totalPoints = 0;

  @override
  void initState() {
    super.initState();
    _userProfile = UserProfile.mockCurrentUser();
    _dailyTasks = DailyTask.mockDailyTasks();
    _rankings = RankingUser.mockRankings();
    _totalPoints = _userProfile.totalPoints;
  }

  void _handleTaskAcceptance(DailyTask task, bool accepted) {
    setState(() {
      task.isAccepted = accepted;
      if (!accepted) {
        task.isAccepted = false;
        task.isCompleted = false;
        task.proofPath = null;
      }
    });

    if (accepted) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => ProofUploadDialog(
              task: task,
              onProofSubmitted: (String? proofPath) {
                _handleProofSubmitted(task, proofPath);
              },
            ),
          );
        }
      });
    }
  }

  void _handleProofSubmitted(DailyTask task, String? proofPath) {
    setState(() {
      if (proofPath != null) {
        task.proofPath = proofPath;
        task.isCompleted = true;
        _totalPoints += task.points;

        // Update user profile dynamically
        _userProfile.totalPoints = _totalPoints;
        _userProfile.levelProgress += 20; // Increase level progress dynamically
        if (_userProfile.levelProgress >= 100) {
          _userProfile.level += 1;
          _userProfile.levelProgress -= 100;
        }

        // Update rank dynamically
        try {
          RankingUser currentUser = _rankings.firstWhere(
            (r) => r.isCurrentUser,
          );
          currentUser.points = _totalPoints;
          _rankings.sort((a, b) => b.points.compareTo(a.points));
          // Re-assign positions based on new sorted order
          for (int i = 0; i < _rankings.length; i++) {
            _rankings[i].position = i + 1;
          }
        } catch (e) {
          // Current user not found in mock list, safe to ignore
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!
              .get('task_completed_points')
              .replaceAll('{points}', '${task.points}'),
        ),
        backgroundColor: AppColors.fieldGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLeaderboardDialog() {
    // Leaderboard data — pos 1 is Rampur Village, pos 12 is current user
    final List<Map<String, dynamic>> allLeaders = [
      {
        'pos': 1,
        'name': 'Rampur Village',
        'initials': 'RV',
        'points': 5240,
        'trend': 'up',
      },
      {
        'pos': 2,
        'name': 'Arjun Sharma',
        'initials': 'AS',
        'points': 4820,
        'trend': 'up',
      },
      {
        'pos': 3,
        'name': 'Priya Patel',
        'initials': 'PP',
        'points': 4610,
        'trend': 'down',
      },
      {
        'pos': 4,
        'name': 'Ravi Kumar',
        'initials': 'RK',
        'points': 4390,
        'trend': 'up',
      },
      {
        'pos': 5,
        'name': 'Sunita Devi',
        'initials': 'SD',
        'points': 4150,
        'trend': 'down',
      },
      {
        'pos': 6,
        'name': 'Mohan Singh',
        'initials': 'MS',
        'points': 3980,
        'trend': 'up',
      },
      {
        'pos': 7,
        'name': 'Kavita Rao',
        'initials': 'KR',
        'points': 3740,
        'trend': 'down',
      },
      {
        'pos': 8,
        'name': 'Deepak Verma',
        'initials': 'DV',
        'points': 3520,
        'trend': 'up',
      },
      {
        'pos': 9,
        'name': 'Anita Gupta',
        'initials': 'AG',
        'points': 3310,
        'trend': 'down',
      },
      {
        'pos': 10,
        'name': 'Vijay Nair',
        'initials': 'VN',
        'points': 3090,
        'trend': 'up',
      },
      {
        'pos': 11,
        'name': 'Meena Joshi',
        'initials': 'MJ',
        'points': 2870,
        'trend': 'down',
      },
      {
        'pos': 12,
        'name': 'You',
        'initials': 'ME',
        'points': _totalPoints,
        'trend': 'up',
        'isMe': true,
      },
    ];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 540),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.deepAquiferBlue, AppColors.tealStart],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      AppLocalizations.of(context)!.get('leaderboard_title'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              // Table header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        AppLocalizations.of(context)!.get('leaderboard_rank'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mediumGrey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.get('leaderboard_name'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mediumGrey,
                        ),
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.get('leaderboard_points'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mediumGrey,
                      ),
                    ),
                    const SizedBox(width: 28),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Table rows
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: allLeaders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final leader = allLeaders[index];
                    final isMe = leader['isMe'] == true;
                    final isTop3 = leader['pos'] <= 3;
                    final isUp = leader['trend'] == 'up';
                    final medalColors = [
                      const Color(0xFFFFD700),
                      const Color(0xFFC0C0C0),
                      const Color(0xFFCD7F32),
                    ];
                    return Container(
                      color: isMe
                          ? AppColors.deepAquiferBlue.withOpacity(0.06)
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: isTop3
                                ? Icon(
                                    Icons.emoji_events_rounded,
                                    color: medalColors[leader['pos'] - 1],
                                    size: 20,
                                  )
                                : Text(
                                    '${leader['pos']}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isMe
                                          ? AppColors.deepAquiferBlue
                                          : AppColors.mediumGrey,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: isMe
                                  ? AppColors.deepAquiferBlue
                                  : AppColors.deepAquiferBlue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                leader['initials'],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isMe
                                      ? Colors.white
                                      : AppColors.deepAquiferBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              leader['name'],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isMe
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isMe
                                    ? AppColors.deepAquiferBlue
                                    : AppColors.darkGrey,
                              ),
                            ),
                          ),
                          Text(
                            '${leader['points']}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isMe
                                  ? AppColors.deepAquiferBlue
                                  : AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            isUp
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 16,
                            color: isUp
                                ? AppColors.fieldGreen
                                : AppColors.criticalRed,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.get('gamification'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.darkGrey,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Card with Points and Level
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildHeroCard(context),
            ),

            // Penalty Alert
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildPenaltyAlert(context),
            ),

            const SizedBox(height: 24),

            // Daily Assignment Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.assignment_rounded,
                    color: AppColors.deepAquiferBlue,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context)!.get('daily_assignment'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkGrey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Daily Tasks List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: List.generate(
                  _dailyTasks.length,
                  (index) => Padding(
                    padding: EdgeInsets.only(
                      bottom: index < _dailyTasks.length - 1 ? 16 : 0,
                    ),
                    child: _buildTaskCard(context, _dailyTasks[index]),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Your Rank Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.bar_chart_rounded,
                        color: AppColors.warningOrange,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        AppLocalizations.of(context)!.get('your_rank'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkGrey,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => _showLeaderboardDialog(),
                    child: Text(
                      AppLocalizations.of(context)!.get('view_all'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepAquiferBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Rankings List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: List.generate(
                  _rankings.length,
                  (index) => Padding(
                    padding: EdgeInsets.only(
                      bottom: index < _rankings.length - 1 ? 12 : 0,
                    ),
                    child: _buildRankingCard(_rankings[index]),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deepAquiferBlue, AppColors.tealStart],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rank Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${AppLocalizations.of(context)!.get('rank_label')}: ${_userProfile.rank}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Points Display
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _totalPoints.toString(),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                AppLocalizations.of(context)!.get('total_water_points'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Level Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${AppLocalizations.of(context)!.get('level_label')} ${_userProfile.level}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                AppLocalizations.of(context)!
                    .get('level_progress')
                    .replaceAll('{progress}', '${_userProfile.levelProgress}')
                    .replaceAll('{next}', '${_userProfile.level + 1}'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _userProfile.levelProgress / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPenaltyAlert(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.criticalRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.criticalRed.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: AppColors.criticalRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.get('penalty_alert'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.criticalRed,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.get('penalty_desc'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${AppLocalizations.of(context)!.get('current_value')}: ${_userProfile.totalPoints} pts',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.mediumGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, DailyTask task) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Image or placeholder
            if (task.isCompleted && task.proofPath != null)
              Container(
                width: double.infinity,
                height: 180,
                color: AppColors.lightGrey,
                child: Image.file(File(task.proofPath!), fit: BoxFit.cover),
              )
            else
              Container(
                width: double.infinity,
                height: 180,
                color: AppColors.lightGrey,
                child: Stack(
                  children: [
                    Container(color: AppColors.fieldGreen.withOpacity(0.2)),
                    Center(
                      child: Icon(
                        Icons.image_rounded,
                        size: 48,
                        color: AppColors.fieldGreen.withOpacity(0.5),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.deepAquiferBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+${task.points} PTS',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.get(task.titleKey),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.get(task.descKey),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mediumGrey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!task.isCompleted)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.get('accept_task'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    _handleTaskAcceptance(task, false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.mediumGrey,
                                  side: const BorderSide(
                                    color: AppColors.mediumGrey,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.get('no'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    _handleTaskAcceptance(task, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.deepAquiferBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.get('yes'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.fieldGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.fieldGreen,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AppLocalizations.of(context)!.get('task_completed'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.fieldGreen,
                            ),
                          ),
                        ],
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

  Widget _buildRankingCard(RankingUser user) {
    if (user.isCurrentUser) {
      // Current user card with highlight
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.deepAquiferBlue.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepAquiferBlue.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.deepAquiferBlue,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${user.position}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.deepAquiferBlue.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.deepAquiferBlue, width: 2),
              ),
              child: Center(
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepAquiferBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGrey,
                    ),
                  ),
                  Text(
                    user.status ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.fieldGreen,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${user.points}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.deepAquiferBlue,
              ),
            ),
          ],
        ),
      );
    }

    // Regular ranking card
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${user.position}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mediumGrey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.initials,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mediumGrey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGrey,
              ),
            ),
          ),
          Text(
            '${user.points}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGrey,
            ),
          ),
        ],
      ),
    );
  }
}
