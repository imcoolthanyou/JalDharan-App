import 'package:flutter/material.dart';
import '../../../core/models/gamification_data.dart';

import '../../../core/theme/app_colors.dart';
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
          RankingUser currentUser = _rankings.firstWhere((r) => r.isCurrentUser);
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
        content: Text('Task completed! +${task.points} points earned'),
        backgroundColor: AppColors.fieldGreen,
        duration: const Duration(seconds: 2),
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
        title: const Text(
          'Water Hero',
          style: TextStyle(
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
              child: _buildHeroCard(),
            ),

            // Penalty Alert
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildPenaltyAlert(),
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
                  const Text(
                    'Daily Assignment',
                    style: TextStyle(
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
                    child: _buildTaskCard(_dailyTasks[index]),
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
                      const Text(
                        'Your Rank',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkGrey,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'View All',
                      style: TextStyle(
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

  Widget _buildHeroCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.deepAquiferBlue,
            AppColors.tealStart,
          ],
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
                const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'RANK: ${_userProfile.rank}',
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
              const Text(
                'TOTAL WATER POINTS',
                style: TextStyle(
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
                'Level ${_userProfile.level}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                '${_userProfile.levelProgress}% to Level ${_userProfile.level + 1}',
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

  Widget _buildPenaltyAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.criticalRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.criticalRed.withOpacity(0.2),
        ),
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
              const Text(
                'PENALTY ALERT',
                style: TextStyle(
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
            '-50 pts if daily extraction exceeds 500L.',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Current Usage: 320L / 500L',
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

  Widget _buildTaskCard(DailyTask task) {
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
                child: Image.file(
                  File(task.proofPath!),
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 180,
                color: AppColors.lightGrey,
                child: Stack(
                  children: [
                    Container(
                      color: AppColors.fieldGreen.withOpacity(0.2),
                    ),
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
                    task.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    task.description,
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
                        const Text(
                          'Accept Task?',
                          style: TextStyle(
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
                                onPressed: () => _handleTaskAcceptance(task, false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.mediumGrey,
                                  side: const BorderSide(
                                    color: AppColors.mediumGrey,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'No',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _handleTaskAcceptance(task, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.deepAquiferBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Yes',
                                  style: TextStyle(
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
                          const Text(
                            'Task Completed',
                            style: TextStyle(
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
                border: Border.all(
                  color: AppColors.deepAquiferBlue,
                  width: 2,
                ),
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
