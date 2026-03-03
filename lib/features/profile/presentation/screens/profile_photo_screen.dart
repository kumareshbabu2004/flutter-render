import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';

/// Profile photo upload / avatar selection screen.
class ProfilePhotoScreen extends StatefulWidget {
  const ProfilePhotoScreen({super.key});
  @override
  State<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends State<ProfilePhotoScreen> {
  int _selectedAvatar = 0;
  bool _hasCustomPhoto = false;

  static const _avatarColors = [
    Color(0xFF2137FF), Color(0xFFFF6B35), Color(0xFF4CAF50),
    Color(0xFF9C27B0), Color(0xFFE53935), Color(0xFF1E88E5),
    Color(0xFFFDD835), Color(0xFF795548), Color(0xFF00BCD4),
  ];

  static const _avatarIcons = [
    Icons.person, Icons.sports_basketball, Icons.sports_football,
    Icons.sports_baseball, Icons.sports_soccer, Icons.sports_hockey,
    Icons.emoji_events, Icons.star, Icons.sports_tennis,
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedAvatar();
  }

  Future<void> _loadSavedAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedAvatar = prefs.getInt('avatar_index') ?? 0;
    });
  }

  Future<void> _saveAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('avatar_index', _selectedAvatar);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildCurrentAvatar(),
                      const SizedBox(height: 24),
                      _buildPhotoActions(),
                      const SizedBox(height: 28),
                      _buildAvatarGrid(),
                      const SizedBox(height: 24),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary), onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 4),
          Text('Profile Photo', style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
        ],
      ),
    );
  }

  Widget _buildCurrentAvatar() {
    return Container(
      width: 120, height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [_avatarColors[_selectedAvatar], _avatarColors[_selectedAvatar].withValues(alpha: 0.6)]),
        border: Border.all(color: BmbColors.gold, width: 3),
        boxShadow: [BoxShadow(color: _avatarColors[_selectedAvatar].withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 4)],
      ),
      child: Icon(_avatarIcons[_selectedAvatar], color: Colors.white, size: 52),
    );
  }

  Widget _buildPhotoActions() {
    return Column(
      children: [
        Text('Upload a Photo', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _photoActionBtn(Icons.camera_alt, 'Take Photo', () {
              _showPermissionDialog('Camera');
            }),
            const SizedBox(width: 16),
            _photoActionBtn(Icons.photo_library, 'From Gallery', () {
              _showPermissionDialog('Photos');
            }),
          ],
        ),
      ],
    );
  }

  Widget _photoActionBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BmbColors.borderColor, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: BmbColors.blue, size: 28),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: BmbColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _showPermissionDialog(String type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.security, color: BmbColors.blue, size: 22),
            const SizedBox(width: 8),
            Text('Permission Required', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold)),
          ],
        ),
        content: Text(
          '"Back My Bracket" would like to access your $type.\n\nThis is used to upload your profile photo.',
          style: TextStyle(color: BmbColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Don\'t Allow', style: TextStyle(color: BmbColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _hasCustomPhoto = true);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('$type access granted. Photo upload simulation complete!'),
                backgroundColor: BmbColors.midNavy, behavior: SnackBarBehavior.floating,
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: BmbColors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Or Choose an Avatar', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12),
          itemCount: _avatarColors.length,
          itemBuilder: (context, index) {
            final sel = _selectedAvatar == index && !_hasCustomPhoto;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedAvatar = index;
                _hasCustomPhoto = false;
              }),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [_avatarColors[index], _avatarColors[index].withValues(alpha: 0.6)]),
                  border: Border.all(color: sel ? BmbColors.gold : Colors.transparent, width: 3),
                  boxShadow: sel ? [BoxShadow(color: BmbColors.gold.withValues(alpha: 0.4), blurRadius: 12)] : [],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(_avatarIcons[index], color: Colors.white, size: 32),
                    if (sel)
                      Positioned(
                        bottom: 2, right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: BmbColors.gold, shape: BoxShape.circle),
                          child: const Icon(Icons.check, color: Colors.black, size: 14),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity, height: 50,
      child: ElevatedButton(
        onPressed: _saveAvatar,
        style: ElevatedButton.styleFrom(backgroundColor: BmbColors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: Text('Save Profile Photo', style: TextStyle(fontSize: 16, fontWeight: BmbFontWeights.bold)),
      ),
    );
  }
}
