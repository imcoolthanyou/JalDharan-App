import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Add url_launcher
import '../../../core/models/community_data.dart';
import '../../../core/theme/app_colors.dart';

class KnowledgeHubScreen extends StatefulWidget {
  const KnowledgeHubScreen({Key? key}) : super(key: key);

  @override
  State<KnowledgeHubScreen> createState() => _KnowledgeHubScreenState();
}

class _KnowledgeHubScreenState extends State<KnowledgeHubScreen> {
  late List<KnowledgeArticle> _articles;
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Water Management',
    'Harvesting',
    'Quality',
    'Irrigation',
    'Soil',
    'Planning',
  ];

  @override
  void initState() {
    super.initState();
    _articles = KnowledgeArticle.mockArticles();
  }

  List<KnowledgeArticle> _getFilteredArticles() {
    if (_selectedCategory == 'All') {
      return _articles;
    }
    return _articles
        .where((article) => article.category == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredArticles = _getFilteredArticles();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Knowledge Hub',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Learn & Grow',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Explore expert guides on water management, farming, and conservation.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mediumGrey,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // Category Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                      backgroundColor: Colors.white,
                      selectedColor: AppColors.deepAquiferBlue,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.mediumGrey,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.deepAquiferBlue
                            : AppColors.mediumGrey.withOpacity(0.3),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Articles List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: filteredArticles.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.article_outlined,
                              size: 48,
                              color: AppColors.mediumGrey.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No articles found',
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
                        filteredArticles.length,
                        (index) => Padding(
                          padding: EdgeInsets.only(
                            bottom: index < filteredArticles.length - 1
                                ? 16
                                : 32,
                          ),
                          child: _buildArticleCard(filteredArticles[index]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleCard(KnowledgeArticle article) {
    return GestureDetector(
      onTap: () {
        _launchRandomPdf(context, article.title);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Article Image
              Container(
                width: double.infinity,
                height: 180,
                color: AppColors.lightGrey,
                child: Stack(
                  children: [
                    Image.network(
                      article.imageUrl,
                      fit: BoxFit.fill,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.fieldGreen.withOpacity(0.2),
                          child: Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 48,
                              color: AppColors.fieldGreen.withOpacity(0.5),
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: AppColors.lightGrey,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              color: AppColors.deepAquiferBlue,
                            ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _articles[_articles.indexOf(
                              article,
                            )] = KnowledgeArticle(
                              id: article.id,
                              title: article.title,
                              description: article.description,
                              category: article.category,
                              imageUrl: article.imageUrl,
                              readTime: article.readTime,
                              isFavorite: !article.isFavorite,
                            );
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(
                            article.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_outline,
                            color: article.isFavorite
                                ? AppColors.criticalRed
                                : AppColors.mediumGrey,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Article Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.deepAquiferBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            article.category,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.deepAquiferBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${article.readTime} min read',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mediumGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkGrey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.description,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mediumGrey,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchRandomPdf(BuildContext context, String title) async {
    final List<String> pdfUrls = [
      'https://cgwb.gov.in/cgwbpnm/public/uploads/documents/168613326251844776file.pdf',
      'https://ndpublisher.in/admin/issues/IJAEBv13n3c.pdf',
    ];

    final random = Random();
    final urlString = pdfUrls[random.nextInt(pdfUrls.length)];
    final uri = Uri.parse(urlString);

    try {
      // Try external application first (best for PDFs)
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        // Fallback to platform default (let OS decide)
        if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
          throw 'Could not launch $urlString';
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open PDF: $e'),
            backgroundColor: AppColors.criticalRed,
          ),
        );
      }
    }
  }
}
