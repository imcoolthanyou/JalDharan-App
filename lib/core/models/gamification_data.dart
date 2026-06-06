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

  static final UserProfile _instance = UserProfile(
    name: 'You',
    rank: 'GUARDIAN',
    totalPoints: 0,
    level: 1,
    levelProgress: 0,
    badge: 'Me',
    position: 12,
  );

  static UserProfile mockCurrentUser() => _instance;
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
      // REPLACE
      DailyTask(
        id: 1,
        title: 'Check Pump Valves',
        description:
        'Check if any water valve near the pump is leaking. Take a photo as proof.',
        titleKey: 'task_1_title',
        descKey: 'task_1_desc',
        points: 100,
      ),
      DailyTask(
        id: 2,
        title: 'Check Water Level',
        description:
        'Go to the nearest well, measure how deep the water is, and write it down.',
        titleKey: 'task_2_title',
        descKey: 'task_2_desc',
        points: 75,
      ),
      DailyTask(
        id: 3,
        title: 'Test Water Quality',
        description:
        'Collect a water sample and check if it is clean. Good water means healthy crops!',
        titleKey: 'task_3_title',
        descKey: 'task_3_desc',
        points: 150,
      ),
      DailyTask(
        id: 4,
        title: 'Check Irrigation Pipes',
        description:
        'Walk through your fields and look for any pipe cracks or leaks. Report what you find.',
        titleKey: 'task_4_title',
        descKey: 'task_4_desc',
        points: 80,
      ),
      DailyTask(
        id: 5,
        title: 'Fill Daily Report',
        description:
        'Write down how the system worked today and any problems you noticed. Earn points daily!',
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
