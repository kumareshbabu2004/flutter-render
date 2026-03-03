import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/dashboard/data/models/user_profile.dart';
import 'package:bmb_mobile/features/favorites/data/services/favorite_teams_service.dart';
import 'package:bmb_mobile/features/favorites/presentation/screens/favorite_teams_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});
  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _displayNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _streetController = TextEditingController();
  final _zipController = TextEditingController();
  String? _selectedState;
  String _email = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _email = prefs.getString('user_email') ?? '';
      _displayNameController.text =
          prefs.getString('user_display_name') ?? '';
      _cityController.text = prefs.getString('user_city') ?? '';
      _streetController.text = prefs.getString('user_street') ?? '';
      _zipController.text = prefs.getString('user_zip') ?? '';
      _selectedState = prefs.getString('user_state');
    });
  }

  Future<void> _saveProfile() async {
    if (_displayNameController.text.trim().isEmpty) {
      _showSnack('Display name is required');
      return;
    }
    if (_selectedState == null) {
      _showSnack('State is required');
      return;
    }
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'user_display_name', _displayNameController.text.trim());
    await prefs.setString('user_state', _selectedState!);
    await prefs.setString('user_city', _cityController.text.trim());
    if (_streetController.text.isNotEmpty) {
      await prefs.setString('user_street', _streetController.text.trim());
    }
    if (_zipController.text.isNotEmpty) {
      await prefs.setString('user_zip', _zipController.text.trim());
    }
    if (!mounted) return;
    setState(() => _saving = false);
    _showSnack('Profile updated successfully!');
    Navigator.pop(context, true); // return true to signal refresh
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: BmbColors.midNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: BmbColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text('Account Settings',
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 20,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay')),
                  ],
                ),
                const SizedBox(height: 24),

                // Email (read-only)
                Text('Email',
                    style: TextStyle(
                        color: BmbColors.textSecondary,
                        fontSize: 13,
                        fontWeight: BmbFontWeights.semiBold)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BmbColors.borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email,
                          color: BmbColors.textTertiary, size: 18),
                      const SizedBox(width: 10),
                      Text(_email,
                          style: TextStyle(
                              color: BmbColors.textTertiary, fontSize: 14)),
                      const Spacer(),
                      const Icon(Icons.lock,
                          color: BmbColors.textTertiary, size: 14),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Display Name
                _buildLabel('Display Name *'),
                const SizedBox(height: 6),
                _buildField(_displayNameController, Icons.person),
                const SizedBox(height: 20),

                // Street
                _buildLabel('Street Address'),
                const SizedBox(height: 6),
                _buildField(_streetController, Icons.home),
                const SizedBox(height: 20),

                // City
                _buildLabel('City'),
                const SizedBox(height: 6),
                _buildField(_cityController, Icons.location_city),
                const SizedBox(height: 20),

                // State dropdown
                _buildLabel('State *'),
                const SizedBox(height: 6),
                _buildStateDropdown(),
                const SizedBox(height: 20),

                // Zip
                _buildLabel('ZIP Code'),
                const SizedBox(height: 6),
                _buildField(_zipController, Icons.pin,
                    keyboard: TextInputType.number),
                const SizedBox(height: 32),

                // ─── MY FAVORITES ─────────────────────────────
                _buildFavoritesSection(),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BmbColors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text('Save Changes',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: BmbFontWeights.bold)),
                  ),
                ),
                const SizedBox(height: 24),

                // Danger zone
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BmbColors.errorRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: BmbColors.errorRed.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Danger Zone',
                          style: TextStyle(
                              color: BmbColors.errorRed,
                              fontSize: 14,
                              fontWeight: BmbFontWeights.bold)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _showSnack(
                              'Password changes will be available in a future update. Stay tuned!'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: BmbColors.errorRed,
                            side: BorderSide(
                                color: BmbColors.errorRed
                                    .withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Change Password'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _showSnack(
                              'Account deletion will be available in a future update. Contact support@backmybracket.com for assistance.'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: BmbColors.errorRed,
                            side: BorderSide(
                                color: BmbColors.errorRed
                                    .withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Delete Account'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesSection() {
    final favService = FavoriteTeamsService();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.gold.withValues(alpha: 0.08),
          BmbColors.gold.withValues(alpha: 0.03),
        ]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: BmbColors.gold, size: 20),
              const SizedBox(width: 8),
              Text('My Favorites',
                  style: TextStyle(
                      color: BmbColors.gold,
                      fontSize: 16,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
            ],
          ),
          const SizedBox(height: 6),
          Text('Follow your favorite teams and athletes to get personalized score alerts, injury updates, and news.',
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, height: 1.4)),
          const SizedBox(height: 12),
          // Toggle for favorite alerts
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: BmbColors.cardDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BmbColors.borderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_active, color: BmbColors.gold, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Favorite Team Notifications',
                          style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.semiBold)),
                      Text('Wins, losses, injuries, breaking news',
                          style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                    ],
                  ),
                ),
                FutureBuilder(
                  future: favService.init().then((_) => favService.alertsEnabled),
                  builder: (context, snapshot) {
                    final enabled = snapshot.data ?? true;
                    return Switch(
                      value: enabled,
                      onChanged: (v) async {
                        await favService.init();
                        await favService.setAlertsEnabled(v);
                        setState(() {});
                      },
                      activeTrackColor: BmbColors.gold.withValues(alpha: 0.5),
                      thumbColor: WidgetStatePropertyAll(enabled ? BmbColors.gold : BmbColors.textTertiary),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Open Favorites screen button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoriteTeamsScreen()));
              },
              icon: Icon(Icons.edit, size: 16, color: BmbColors.gold),
              label: Text('Manage Favorite Teams & Athletes',
                  style: TextStyle(color: BmbColors.gold, fontSize: 13, fontWeight: BmbFontWeights.semiBold)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: BmbColors.gold.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: TextStyle(
            color: BmbColors.textSecondary,
            fontSize: 13,
            fontWeight: BmbFontWeights.semiBold));
  }

  Widget _buildField(TextEditingController ctrl, IconData icon,
      {TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: TextStyle(color: BmbColors.textPrimary),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: BmbColors.textSecondary),
        filled: true,
        fillColor: BmbColors.cardDark,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: BmbColors.borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: BmbColors.borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: BmbColors.blue)),
      ),
    );
  }

  Widget _buildStateDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: BmbColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _selectedState != null
                ? BmbColors.blue
                : BmbColors.borderColor),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedState,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.location_on,
              color: BmbColors.textSecondary),
          border: InputBorder.none,
        ),
        dropdownColor: BmbColors.midNavy,
        style: TextStyle(color: BmbColors.textPrimary, fontSize: 14),
        icon: const Icon(Icons.keyboard_arrow_down,
            color: BmbColors.textSecondary),
        items: UserProfile.usStates.map((abbr) {
          final name = UserProfile.stateNames[abbr] ?? abbr;
          return DropdownMenuItem(
            value: abbr,
            child: Text('$abbr - $name',
                style: TextStyle(
                    color: BmbColors.textPrimary, fontSize: 14)),
          );
        }).toList(),
        onChanged: (val) => setState(() => _selectedState = val),
        menuMaxHeight: 300,
      ),
    );
  }
}
