class UserProfile {
  final String name;
  final String rank;
  int totalPoints;
  int level;
  int levelProgress; // percentage to next level
  final String badge;
  final int position; // ranking position

  UserProfile({
    required this.name,
    required this.rank,
    required this.totalPoints,
    required this.level,
    required this.levelProgress,
    required this.badge,
    required this.position,
  });

  static UserProfile mockCurrentUser() {
    return UserProfile(
      name: 'You',
      rank: 'GUARDIAN',
      totalPoints: 1250,
      level: 5,
      levelProgress: 85,
      badge: 'Me',
      position: 12,
    );
  }
}

class DailyTask {
  final int id;
  final String title;
  final String description;
  final String titleKey;
  final String descKey;
  final int points;
  final String? imageUrl;
  bool isAccepted;
  String? proofPath;
  bool isCompleted;

  DailyTask({
    required this.id,
    required this.title,
    required this.description,
    required this.titleKey,
    required this.descKey,
    required this.points,
    this.imageUrl,
    this.isAccepted = false,
    this.proofPath,
    this.isCompleted = false,
  });

  static List<DailyTask> mockDailyTasks() {
    return [
      DailyTask(
        id: 1,
        title: 'Check pump valves for leaks',
        description:
            'Inspect the main distribution valves in Field #4 to ensure zero wastage.',
        titleKey: 'task_1_title',
        descKey: 'task_1_desc',
        points: 100,
      ),
      DailyTask(
        id: 2,
        title: 'Monitor water level readings',
        description:
            'Check the groundwater depth at monitoring well #2 and record the measurement.',
        titleKey: 'task_2_title',
        descKey: 'task_2_desc',
        points: 75,
      ),
      DailyTask(
        id: 3,
        title: 'Test water quality',
        description:
            'Collect water samples and test pH, TDS, and turbidity levels.',
        titleKey: 'task_3_title',
        descKey: 'task_3_desc',
        points: 150,
      ),
      DailyTask(
        id: 4,
        title: 'Inspect irrigation pipes',
        description:
            'Walk through Field #1-3 to check for any visible leaks or damage in irrigation lines.',
        titleKey: 'task_4_title',
        descKey: 'task_4_desc',
        points: 80,
      ),
      DailyTask(
        id: 5,
        title: 'Record maintenance log',
        description:
            'Update the daily maintenance log with current system status and any issues found.',
        titleKey: 'task_5_title',
        descKey: 'task_5_desc',
        points: 50,
      ),
    ];
  }
}

class RankingUser {
  int position;
  final String name;
  int points;
  final String initials;
  final bool isCurrentUser;
  final String? status; // 'Top 10%' etc

  RankingUser({
    required this.position,
    required this.name,
    required this.points,
    required this.initials,
    this.isCurrentUser = false,
    this.status,
  });

  static List<RankingUser> mockRankings() {
    return [
      RankingUser(
        position: 1,
        name: 'Rampur Village',
        points: 5240,
        initials: 'RV',
      ),
      RankingUser(
        position: 12,
        name: 'You',
        points: 1250,
        initials: 'Me',
        isCurrentUser: true,
        status: 'Top 10%',
      ),
      RankingUser(
        position: 13,
        name: 'Kishan Lal',
        points: 1120,
        initials: 'KL',
      ),
    ];
  }
}
