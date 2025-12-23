import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../widgets/custom_drawer.dart';
import '../auth/login_page.dart';
import 'home_page.dart';
import 'favorites_page.dart';
import 'tip_selection_page.dart';
import 'settings_page.dart';
import 'dart:async';
import 'history_page.dart';
import 'catalog_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const primaryColor = Color(0xFF15325A);
  static const backgroundColor = Color(0xFFF5F7FA);
  static const accentColor = Color(0xFF4CAF50);

  late final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  String _userName = '';
  String _userEmail = '';
  String _userLocation = 'Carregando...';
  String? _userAvatarUrl;
  File? _selectedImage;
  bool _isLoadingUser = false;
  bool _isEditing = false;
  bool _isLoadingLocation = false;
  bool _isUploadingImage = false;
  bool _showPasswordSection = false;
  bool _isChangingPassword = false;

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingUser = false);
      return;
    }

    if (mounted) setState(() => _isLoadingUser = true);

    try {
      final response = await supabase
          .from('users')
          .select('name, email, avatar_url, location')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _userName =
            response?['name'] ?? _extractNameFromEmail(user.email) ?? 'Usuário';
        _userEmail = response?['email'] ?? user.email ?? '';
        _userAvatarUrl = response?['avatar_url'];
        _userLocation = response?['location'] ?? 'Localização não definida';
      });

      _updateControllers();

      if (_userLocation == 'Localização não definida') {
        await _getCurrentLocation();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userName = _extractNameFromEmail(user.email) ?? 'Usuário';
        _userEmail = user.email ?? '';
        _userLocation = 'Erro ao carregar';
      });
      _updateControllers();
    } finally {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  String? _extractNameFromEmail(String? email) {
    if (email == null || email.isEmpty) return null;
    return email.split('@').first;
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    setState(() {
      _isLoadingLocation = true;
      _userLocation = 'Obtendo localização...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _userLocation = 'Serviço de localização desativado');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _userLocation = 'Permissão de localização negada');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _userLocation = 'Permissão permanentemente negada');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      await setLocaleIdentifier('pt_BR');

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String location = '';
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        if (place.subAdministrativeArea != null &&
            place.subAdministrativeArea!.isNotEmpty) {
          location = place.subAdministrativeArea!;
        }

        if (location.isEmpty &&
            place.locality != null &&
            place.locality!.isNotEmpty) {
          location = place.locality!;
        }

        if (location.isEmpty &&
            place.subLocality != null &&
            place.subLocality!.isNotEmpty) {
          location = place.subLocality!;
        }

        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          if (location.isNotEmpty) {
            location += ' - ${place.administrativeArea!}';
          } else {
            location = place.administrativeArea!;
          }
        }

        if (location.isEmpty &&
            place.country != null &&
            place.country!.isNotEmpty) {
          location = place.country!;
        }

        if (location.isEmpty) {
          location =
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        }
      } else {
        location =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      final user = supabase.auth.currentUser;
      if (user != null && location.isNotEmpty) {
        try {
          await supabase
              .from('users')
              .update({'location': location}).eq('id', user.id);
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _userLocation = location);
        _locationController.text = location;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _userLocation = 'Não foi possível obter localização');
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _refreshLocation() async {
    await _getCurrentLocation();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tirar foto'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Escolher da galeria'),
                onTap: () {
                  Navigator.pop(context);
                  _chooseFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 800,
    );

    if (image != null && mounted) {
      await _processImage(image);
    }
  }

  Future<void> _chooseFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );

    if (image != null && mounted) {
      await _processImage(image);
    }
  }

  Future<void> _processImage(XFile imageFile) async {
    setState(() {
      _selectedImage = File(imageFile.path);
    });
    await _uploadImage();
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final fileExtension = _selectedImage!.path.split('.').last;
      final fileName =
          'avatar_${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      await supabase.storage.from('avatars').upload(fileName, _selectedImage!);

      final avatarUrl = supabase.storage.from('avatars').getPublicUrl(fileName);

      await supabase
          .from('users')
          .update({'avatar_url': avatarUrl}).eq('id', user.id);

      if (mounted) {
        setState(() => _userAvatarUrl = avatarUrl);
        _showSuccessSnackBar('Foto atualizada com sucesso!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao atualizar foto');
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _updateControllers() {
    _nameController.text = _userName;
    _emailController.text = _userEmail;
    _locationController.text = _userLocation;
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoadingUser = true);

    try {
      final updates = {
        'name': _nameController.text.trim(),
      };

      await supabase.from('users').update(updates).eq('id', user.id).select();

      if (!mounted) return;

      setState(() {
        _userName = _nameController.text.trim();
        _isEditing = false;
        _isLoadingUser = false;
      });

      _showSuccessSnackBar('Perfil atualizado com sucesso!');
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoadingUser = false);
      _showErrorSnackBar('Erro ao atualizar perfil');
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isChangingPassword = true);

    try {
      final currentPassword = _currentPasswordController.text.trim();
      final newPassword = _newPasswordController.text.trim();

      try {
        await supabase.auth.signInWithPassword(
          email: _userEmail,
          password: currentPassword,
        );
      } catch (e) {
        if (e.toString().contains('Invalid login credentials')) {
          throw Exception('Senha atual incorreta');
        }
        rethrow;
      }

      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (!mounted) return;

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      setState(() {
        _showPasswordSection = false;
        _isChangingPassword = false;
      });

      _showSuccessSnackBar('Senha alterada com sucesso!');
    } catch (e) {
      if (!mounted) return;

      setState(() => _isChangingPassword = false);

      String errorMessage = 'Erro ao alterar senha';
      if (e.toString().contains('Senha atual incorreta')) {
        errorMessage = 'Senha atual incorreta';
      } else if (e.toString().contains('Password should')) {
        errorMessage = 'A nova senha não atende aos requisitos de segurança';
      } else if (e.toString().contains('weak_password')) {
        errorMessage = 'A nova senha é muito fraca';
      }

      _showErrorSnackBar(errorMessage);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      _showPasswordSection = false;
      if (!_isEditing) {
        _updateControllers();
      }
    });
  }

  void _togglePasswordSection() {
    setState(() {
      _showPasswordSection = !_showPasswordSection;
      if (!_showPasswordSection) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _passwordFormKey.currentState?.reset();
      }
    });
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Saída'),
        content: const Text('Tem certeza que deseja sair do aplicativo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performLogout();
            },
            child: const Text(
              'Sair',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Erro ao sair');
    }
  }

  Widget _buildProfileHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: _buildCardDecoration(),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isEditing ? _pickImage : null,
            child: Stack(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(45),
                    border: Border.all(
                        color: primaryColor.withValues(alpha: 0.3), width: 2),
                    image: _userAvatarUrl != null || _selectedImage != null
                        ? DecorationImage(
                            image: _selectedImage != null
                                ? FileImage(_selectedImage!)
                                : NetworkImage(_userAvatarUrl!)
                                    as ImageProvider,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _userAvatarUrl == null && _selectedImage == null
                      ? Center(
                          child: Text(
                            _userName.isNotEmpty
                                ? _userName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        )
                      : null,
                ),
                if (_isEditing)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (_isUploadingImage)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(45),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _userEmail,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _userLocation,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isLoadingLocation)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1,
                          color: primaryColor,
                        ),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: primaryColor,
                      ),
                      onPressed: _isLoadingLocation ? null : _refreshLocation,
                      tooltip: 'Atualizar localização',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _toggleEditMode,
            icon: Icon(
              _isEditing ? Icons.close_rounded : Icons.edit_rounded,
              color: _isEditing ? Colors.red : primaryColor,
              size: 24,
            ),
            tooltip: _isEditing ? 'Cancelar edição' : 'Editar perfil',
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.info_outline_rounded,
            title: 'Informações do Perfil',
          ),
          const SizedBox(height: 16),
          if (_isEditing) _buildEditForm() else _buildInfoDisplay(),
        ],
      ),
    );
  }

  Widget _buildPasswordChangeCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _togglePasswordSection,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(
                  icon: Icons.lock_outline_rounded,
                  title: 'Alterar Senha',
                ),
                Icon(
                  _showPasswordSection
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: primaryColor,
                ),
              ],
            ),
          ),
          if (_showPasswordSection) ...[
            const SizedBox(height: 16),
            const Text(
              'Para alterar sua senha, primeiro confirme sua senha atual e depois digite a nova senha!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            _buildPasswordForm(),
          ],
        ],
      ),
    );
  }

  Widget _buildPasswordForm() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        children: [
          _buildPasswordField(
            label: 'Senha Atual',
            controller: _currentPasswordController,
            showPassword: _showCurrentPassword,
            onToggleVisibility: () {
              setState(() => _showCurrentPassword = !_showCurrentPassword);
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor, informe sua senha atual';
              }
              if (value.length < 6) {
                return 'A senha deve ter pelo menos 6 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildPasswordField(
            label: 'Nova Senha',
            controller: _newPasswordController,
            showPassword: _showNewPassword,
            onToggleVisibility: () {
              setState(() => _showNewPassword = !_showNewPassword);
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor, informe a nova senha';
              }
              if (value.length < 6) {
                return 'A senha deve ter pelo menos 6 caracteres';
              }
              if (value == _currentPasswordController.text) {
                return 'A nova senha deve ser diferente da atual';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildPasswordField(
            label: 'Confirmar Nova Senha',
            controller: _confirmPasswordController,
            showPassword: _showConfirmPassword,
            onToggleVisibility: () {
              setState(() => _showConfirmPassword = !_showConfirmPassword);
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor, confirme a nova senha';
              }
              if (value != _newPasswordController.text) {
                return 'As senhas não coincidem';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildPasswordButton(),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool showPassword,
    required VoidCallback onToggleVisibility,
    required String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !showPassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_rounded, color: primaryColor),
        suffixIcon: IconButton(
          icon: Icon(
            showPassword
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            color: primaryColor.withValues(alpha: 0.7),
          ),
          onPressed: onToggleVisibility,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: const Color.fromARGB(255, 0, 64, 255), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      style: const TextStyle(fontSize: 15),
      validator: validator,
    );
  }

  Widget _buildPasswordButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isChangingPassword ? null : _changePassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 0, 64, 255),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _isChangingPassword
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.lock_reset_rounded),
        label: Text(
          _isChangingPassword ? 'ALTERANDO SENHA...' : 'ALTERAR SENHA',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildEditableField(
            label: 'Nome Completo',
            icon: Icons.person_rounded,
            controller: _nameController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor, informe seu nome';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildEditableField(
            label: 'Email',
            icon: Icons.email_rounded,
            controller: _emailController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor, informe seu email';
              }
              if (!value.contains('@')) {
                return 'Email inválido';
              }
              return null;
            },
            enabled: false,
          ),
          const SizedBox(height: 20),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildInfoDisplay() {
    return Column(
      children: [
        _buildInfoItem(
          icon: Icons.person_rounded,
          label: 'Nome',
          value: _userName,
        ),
        const SizedBox(height: 12),
        _buildInfoItem(
          icon: Icons.email_rounded,
          label: 'Email',
          value: _userEmail,
        ),
        const SizedBox(height: 12),
        _buildInfoItem(
          icon: Icons.location_on_rounded,
          label: 'Localização',
          value: _userLocation,
          isLoading: _isLoadingLocation,
        ),
      ],
    );
  }

  Widget _buildEditableField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade200,
      ),
      style: TextStyle(
        fontSize: 15,
        color: enabled ? Colors.black : Colors.grey.shade600,
      ),
      validator: validator,
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    if (isLoading)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: primaryColor,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoadingUser ? null : _updateProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _isLoadingUser
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save_rounded),
        label: Text(
          _isLoadingUser ? 'SALVANDO...' : 'SALVAR ALTERAÇÕES',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF15325A),
          ),
        ),
      ],
    );
  }

  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'Meu Perfil',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save_rounded),
              onPressed: _updateProfile,
              tooltip: 'Salvar alterações',
            ),
        ],
      ),
      drawer: CustomDrawer(
        currentRoute: '/profile',
        userName: _userName,
        userAvatarUrl: _userAvatarUrl,
        isLoadingUser: _isLoadingUser,
        onHomeTap: () => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        ),
        onTipsTap: () => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const TipSelectionPage()),
          (route) => false,
        ),
        onFavoritesTap: () => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const FavoritesPage()),
          (route) => false,
        ),
        onCatalogTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CatalogPage()),
          );
        },
        onHistoryTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HistoryPage()),
          );
        },
        onSettingsTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsPage()),
        ),
        onLogoutTap: () => _showLogoutDialog(context),
      ),
      body: Container(
        color: backgroundColor,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileHeader(),
                _buildProfileInfoCard(),
                _buildPasswordChangeCard(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
