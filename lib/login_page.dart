import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'task_page.dart'; 
import 'signup_page.dart'; 

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  // 3. Controladores para obter os valores dos campos de texto
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth =
      FirebaseAuth.instance; // Instância do Firebase Auth
  bool _isLoading = false; // Para mostrar um indicador de carregamento

  // 4. Função assíncrona para lidar com o login
  Future<void> _login() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true; // Ativa o indicador de carregamento
    });

    try {
      // Tenta fazer o login com o Firebase
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Se o login for bem-sucedido, navega para a HomePage
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TaskPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Trata os erros de login e mostra uma mensagem
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'Nenhum usuário encontrado para este e-mail.';
          break;
        case 'wrong-password':
          message = 'Senha incorreta. Tente novamente.';
          break;
        case 'invalid-email':
          message = 'O formato do e-mail é inválido.';
          break;
        default:
          message = 'Ocorreu um erro. Verifique suas credenciais.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      // Garante que o indicador de carregamento seja desativado
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // --- FIM DA LÓGICA ADICIONADA ---

  // Função para iniciar o processo de redefinição de senha
  Future<void> _resetPassword(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por favor, insira seu e-mail."),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Método do Firebase para enviar o e-mail de redefinição
      await _auth.sendPasswordResetEmail(email: email.trim());

      // Feedback de sucesso para o usuário
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Link para redefinição de senha enviado para o seu e-mail!",
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = "Ocorreu um erro. Tente novamente.";
      if (e.code == 'user-not-found') {
        message = "Nenhum usuário encontrado para este e-mail.";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      Navigator.of(context).pop(); // Fecha a caixa de diálogo
    }
  }

  // Função para mostrar a caixa de diálogo de redefinição de senha
  void _showPasswordResetDialog() {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text("Redefinir Senha"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Digite seu e-mail para receber um link de redefinição.",
              ),
              const SizedBox(height: 15),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "E-mail",
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(), // Botão para cancelar
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                // Chama a função de redefinição com o e-mail digitado
                _resetPassword(emailController.text);
              },
              child: const Text("Enviar"),
            ),
          ],
        );
      },
    );
  }

  bool _obscurePassword = true;
  String _selectedLanguage = "Português";

  @override
  void dispose() {
    // 5. Limpa os controladores quando o widget for descartado
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3A47D5), Color(0xFF00C9FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Image.asset('assets/logo.png', height: 80),
                    const SizedBox(height: 15),

                    const Text(
                      "Login",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Use a conta abaixo para fazer login",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 20),

                    // Email
                    TextField(
                      controller: _emailController, // 6. Conecta o controlador
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined),
                        labelText: "Email",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Senha
                    TextField(
                      controller:
                          _passwordController, // 7. Conecta o controlador
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        labelText: "Senha",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botão Logar
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onPressed: _isLoading
                          ? null
                          : _login, // 8. Chama a função _login
                      child: _isLoading
                          ? const SizedBox(
                              // Mostra um círculo de progresso
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Logar",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                    ),

                    const SizedBox(height: 10),
                    // Esqueceu senha
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : _showPasswordResetDialog, // Chama a função da caixa de diálogo
                      child: const Text("Esqueceu sua senha?"),
                    ),
                    const SizedBox(height: 10),
                    // Botão cadastrar
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        // Navega para a tela de cadastro
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text("Cadastrar"),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.language, size: 20),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _selectedLanguage,
                          items: ["Português", "Inglês", "Espanhol"]
                              .map(
                                (lang) => DropdownMenuItem(
                                  value: lang,
                                  child: Text(lang),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedLanguage = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}