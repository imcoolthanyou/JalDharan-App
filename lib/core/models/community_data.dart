class CommunityMember {
  final String name;
  final String location;
  final int points;
  final String initials;
  final bool isAdmin;
  final double latitude;
  final double longitude;
  final double waterDepth; // in meters
  final double waterScore; // 0-100

  CommunityMember({
    required this.name,
    required this.location,
    required this.points,
    required this.initials,
    this.isAdmin = false,
    required this.latitude,
    required this.longitude,
    required this.waterDepth,
    required this.waterScore,
  });

  static List<CommunityMember> mockMembers() {
    return [
      CommunityMember(
        name: 'Rampur Village Council',
        location: 'Rampur, Haryana',
        points: 5200,
        initials: 'RV',
        isAdmin: true,
        latitude: 29.1234,
        longitude: 77.5678,
        waterDepth: 35.2,
        waterScore: 85,
      ),
      CommunityMember(
        name: 'Farmer\'s Association',
        location: 'Punjab',
        points: 4800,
        initials: 'FA',
        latitude: 31.5497,
        longitude: 74.3436,
        waterDepth: 28.5,
        waterScore: 72,
      ),
      CommunityMember(
        name: 'Water Conservation Org',
        location: 'Delhi NCR',
        points: 4500,
        initials: 'WC',
        latitude: 28.7041,
        longitude: 77.1025,
        waterDepth: 42.1,
        waterScore: 90,
      ),
      CommunityMember(
        name: 'Youth Green Group',
        location: 'Uttar Pradesh',
        points: 3800,
        initials: 'YG',
        latitude: 27.1767,
        longitude: 78.0081,
        waterDepth: 25.8,
        waterScore: 68,
      ),
      CommunityMember(
        name: 'Agricultural Board',
        location: 'Haryana',
        points: 3600,
        initials: 'AB',
        latitude: 29.5673,
        longitude: 76.8089,
        waterDepth: 31.4,
        waterScore: 78,
      ),
    ];
  }
}

class KnowledgeArticle {
  final int id;
  final String title;
  final String description;
  final String titleKey;
  final String descKey;
  final String category;
  final String categoryKey;
  final String imageUrl;
  final int readTime;
  final bool isFavorite;

  KnowledgeArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.titleKey,
    required this.descKey,
    required this.category,
    required this.categoryKey,
    required this.imageUrl,
    required this.readTime,
    this.isFavorite = false,
  });

  static List<KnowledgeArticle> mockArticles() {
    return [
      KnowledgeArticle(
        id: 1,
        title: 'Groundwater Recharge Techniques',
        description:
            'Learn effective methods to recharge groundwater and improve water availability in your region.',
        titleKey: 'article_1_title',
        descKey: 'article_1_desc',
        category: 'Water Management',
        categoryKey: 'cat_water_management',
        imageUrl:
            'https://5.imimg.com/data5/SELLER/Default/2021/11/AC/XG/GV/2793594/img-20160710-113917.jpg',
        readTime: 8,
      ),
      KnowledgeArticle(
        id: 2,
        title: 'Rainwater Harvesting Systems',
        description:
            'Complete guide to designing and implementing rainwater harvesting systems for agricultural use.',
        titleKey: 'article_2_title',
        descKey: 'article_2_desc',
        category: 'Harvesting',
        categoryKey: 'cat_harvesting',
        imageUrl:
            'https://5.imimg.com/data5/SELLER/Default/2023/10/354350364/SL/UP/OO/2402236/rain-water-percolation-tank.jpeg',
        readTime: 12,
      ),
      KnowledgeArticle(
        id: 3,
        title: 'Water Quality Testing at Home',
        description:
            'Simple methods to test water quality and understand what different measurements mean.',
        titleKey: 'article_3_title',
        descKey: 'article_3_desc',
        category: 'Quality',
        categoryKey: 'cat_quality',
        imageUrl:
            'https://live.staticflickr.com/8508/8423016623_ff645c3908_b.jpg',
        readTime: 6,
      ),
      KnowledgeArticle(
        id: 4,
        title: 'Sustainable Irrigation Practices',
        description:
            'Optimize irrigation to reduce water wastage while maintaining crop productivity.',
        titleKey: 'article_4_title',
        descKey: 'article_4_desc',
        category: 'Irrigation',
        categoryKey: 'cat_irrigation',
        imageUrl:
            'https://40800710.delivery.rocketcdn.me/wp-content/uploads/2018/11/above-ground-vs-underground-water-storage-tanks-the-pros-and-cons-image-01.jpg',
        readTime: 10,
      ),
      KnowledgeArticle(
        id: 5,
        title: 'Soil Moisture Management',
        description:
            'Understand soil moisture levels and their impact on crop growth and water conservation.',
        titleKey: 'article_5_title',
        descKey: 'article_5_desc',
        category: 'Soil',
        categoryKey: 'cat_soil',
        imageUrl:
            'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSPieiBHwD0MOTYjImx5K66biJuhp2FiRtWpw&s',
        readTime: 7,
      ),
      KnowledgeArticle(
        id: 6,
        title: 'Seasonal Water Planning Guide',
        description:
            'Plan water usage for different seasons and prepare for water scarcity periods.',
        titleKey: 'article_6_title',
        descKey: 'article_6_desc',
        category: 'Planning',
        categoryKey: 'cat_planning',
        imageUrl:
            'https://www.tirupatifence.com/uploaded-files/category/images/thumbs/Gabion-Box-thumbs-500X500.jpg',
        readTime: 9,
      ),
    ];
  }
}

class AppSetting {
  final String title;
  final String subtitle;
  final String icon;
  final bool value;
  final Function(bool)? onChanged;

  AppSetting({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    this.onChanged,
  });
}
