import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/utils.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _socialNameController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _docController = TextEditingController();
  String _selectedCountry = 'BR';

  @override
  void initState() {
    super.initState();
    _nameController.text = UserSession.fullName;
    _socialNameController.text = UserSession.socialName;
    _whatsappController.text = UserSession.whatsapp;
    _docController.text = UserSession.document;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _socialNameController.dispose();
    _whatsappController.dispose();
    _docController.dispose();
    super.dispose();
  }

  void _saveRegistration() {
    if (_nameController.text.trim().isEmpty ||
        _whatsappController.text.trim().isEmpty ||
        _docController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, preencha todos os campos obrigatórios.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      UserSession.fullName = _nameController.text.trim();
      UserSession.socialName = _socialNameController.text.trim();
      UserSession.whatsapp = _whatsappController.text.trim();
      UserSession.document = _docController.text.trim();
      UserSession.isRegistered = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cadastro concluído com sucesso!'),
        backgroundColor: AppColors.accentGreen,
      ),
    );

    Navigator.pop(context, true);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          hintStyle: const TextStyle(color: AppColors.borderLight),
          prefixIcon: Icon(icon, color: AppColors.primaryGold),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Cadastro de Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textMain, size: 20),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                const Text(
                  'Identificação na Fronteira',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textMain),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Preencha seus dados para entrega ágil no Brasil ou Paraguai.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),

                // Seleção de País
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCountry = 'BR'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedCountry == 'BR' ? AppColors.lightGold : AppColors.surfaceWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedCountry == 'BR' ? AppColors.primaryGold : AppColors.borderLight,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '🇧🇷 Brasil (CPF)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _selectedCountry == 'BR' ? AppColors.darkGold : AppColors.textMain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCountry = 'PY'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedCountry == 'PY' ? AppColors.lightGold : AppColors.surfaceWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedCountry == 'PY' ? AppColors.primaryGold : AppColors.borderLight,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '🇵🇾 Paraguay (C.I.)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _selectedCountry == 'PY' ? AppColors.darkGold : AppColors.textMain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  controller: _nameController,
                  label: AppStrings.get('name', UserSession.language),
                  hint: 'Ex: Heber Martins',
                  icon: Icons.person_rounded,
                ),
                _buildTextField(
                  controller: _socialNameController,
                  label: AppStrings.get('social_name', UserSession.language),
                  hint: 'Como prefere ser chamado (opcional)',
                  icon: Icons.badge_rounded,
                ),
                _buildTextField(
                  controller: _whatsappController,
                  label: AppStrings.get('whatsapp', UserSession.language),
                  hint: 'Ex: +55 67 99999-9999',
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                ),
                _buildTextField(
                  controller: _docController,
                  label: _selectedCountry == 'BR'
                      ? AppStrings.get('doc_br', UserSession.language)
                      : AppStrings.get('doc_py', UserSession.language),
                  hint: _selectedCountry == 'BR' ? '000.000.000-00' : 'Nº de Cédula',
                  icon: Icons.assignment_ind_rounded,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _saveRegistration,
                  child: const Text('Salvar e Continuar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}