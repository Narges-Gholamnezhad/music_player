// lib/music_shop_screen.dart
import 'package:flutter/material.dart';
import 'music_shop_category_list_screen.dart';

class CategoryModel {
  final String name;
  final IconData icon;
  final Color color;

  const CategoryModel(
      {required this.name, required this.icon, required this.color});
}

class MusicShopScreen extends StatefulWidget {
  const MusicShopScreen({super.key});

  @override
  State<MusicShopScreen> createState() => _MusicShopScreenState();
}

class _MusicShopScreenState extends State<MusicShopScreen> {
  // REPLACE your old _categories list with this new one.

  final List<CategoryModel> _categories = [
    CategoryModel(
        name: 'Latest Hits',
        icon: Icons.whatshot_outlined,
        color: Colors.deepOrangeAccent[200]!),
    CategoryModel(
        name: 'Persian',
        icon: Icons.music_note,
        color: Colors.greenAccent[400]!),
    CategoryModel(
        name: 'International',
        icon: Icons.public,
        color: Colors.lightBlueAccent[200]!),
    CategoryModel(
        name: 'Pop Stars',
        icon: Icons.star_outline,
        color: Colors.purpleAccent[100]!),
    CategoryModel(
        name: 'Rock Anthems', // This will be empty, which is okay
        icon: Icons.music_video_outlined,
        color: Colors.redAccent[100]!),
    CategoryModel(
        name: 'Local', // This will be empty, which is okay
        icon: Icons.spa_outlined,
        color: Colors.tealAccent[200]!),
  ];

  @override
  Widget build(BuildContext context) {
    print("MusicShopScreen: build called");

    return _buildCategoriesGrid(context);
  }

  Widget _buildCategoriesGrid(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color cardBackgroundColor =
        theme.cardTheme.color ?? colorScheme.surface;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 1.2,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final Color iconAndAccentColor = category.color;

          return InkWell(
            onTap: () {
              print(
                  'Tapped on category: ${category.name}. Navigating to MusicShopCategoryListScreen.');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MusicShopCategoryListScreen(categoryName: category.name),
                ),
              );
            },
            borderRadius: BorderRadius.circular(
                theme.cardTheme.shape is RoundedRectangleBorder
                    ? ((theme.cardTheme.shape as RoundedRectangleBorder)
                            .borderRadius as BorderRadius)
                        .resolve(Directionality.of(context))
                        .topLeft
                        .x
                    : 12.0),
            splashColor: iconAndAccentColor.withOpacity(0.2),
            highlightColor: iconAndAccentColor.withOpacity(0.1),
            child: Card(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(category.icon, size: 48.0, color: iconAndAccentColor),
                  const SizedBox(height: 12.0),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      category.name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
