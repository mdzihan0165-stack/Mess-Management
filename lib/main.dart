
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'pdf_generator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MessManagementApp());
}

bool isAdminLoggedIn = false;
String globalMessName = "";
String globalMessCode = "";
String globalMessDocId = "";
String globalUserEmail = "";

class MessManagementApp extends StatelessWidget {
  const MessManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mess Management System',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0f0c29),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}

// 3D Dynamic Background Decoration Helper
BoxDecoration dynamic3DBackground() {
  return const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToAuthCheck();
  }

  Future<void> _navigateToAuthCheck() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthCheckScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: dynamic3DBackground(),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                child: Icon(Icons.restaurant_menu, size: 60, color: Color(0xFF1B5E20)),
              ),
              SizedBox(height: 20),
              Text(
                'Meal Management',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(height: 30),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  bool isLoading = true;
  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    bool localIsLoggedIn = prefs.getBool('is_logged_in') ?? false;
    isAdminLoggedIn = prefs.getBool('is_admin') ?? false;
    globalMessName = prefs.getString('mess_name') ?? "";
    globalMessCode = prefs.getString('mess_code') ?? "";
    globalMessDocId = prefs.getString('mess_doc_id') ?? "";
    globalUserEmail = prefs.getString('user_email') ?? "";

    setState(() {
      isLoggedIn = localIsLoggedIn;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0f0c29),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Loading...', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ),
      );
    }
    return isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}

// Universal Login Screen (Without Password - Only Mess Code & Email)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  String errorMessage = "";
  bool isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _loginUser() async {
    String code = _codeController.text.trim();
    String email = _emailController.text.trim();

    if (code.isEmpty || email.isEmpty) {
      setState(() => errorMessage = "সব ফিল্ড পূরণ করুন!");
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      var querySnapshot = await FirebaseFirestore.instance
          .collection('messes')
          .where('mess_code', isEqualTo: code)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          errorMessage = "ভুল মেস কোড!";
          isLoading = false;
        });
        return;
      }

      var doc = querySnapshot.docs.first;
      List members = doc['members'] ?? [];
      bool emailFound = false;
      bool isManagerUser = false;

      for (var m in members) {
        if ((m['email'] ?? "").toString().toLowerCase() == email.toLowerCase()) {
          emailFound = true;
          if (m['is_manager'] == true) {
            isManagerUser = true;
          }
          break;
        }
      }

      if (!emailFound) {
        setState(() {
          errorMessage = "লগইন বাতিল: এই ইমেইলটি এই মেসের মেম্বার তালিকায় নেই!";
          isLoading = false;
        });
        return;
      }

      globalMessDocId = doc.id;
      globalMessName = doc['mess_name'] ?? "";
      globalMessCode = code;
      globalUserEmail = email;
      isAdminLoggedIn = isManagerUser;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('is_admin', isAdminLoggedIn);
      await prefs.setString('mess_name', globalMessName);
      await prefs.setString('mess_code', globalMessCode);
      await prefs.setString('mess_doc_id', globalMessDocId);
      await prefs.setString('user_email', globalUserEmail);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      setState(() {
        errorMessage = "ত্রুটি: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: dynamic3DBackground(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Card(
                  elevation: 12,
                  color: Colors.white.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.restaurant_menu, size: 40, color: Color(0xFF1B5E20)),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Mess Login',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 25),
                        TextField(
                          controller: _codeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Mess Code',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white12,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white12,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(errorMessage, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ),
                        const SizedBox(height: 10),
                        isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 52),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _loginUser,
                                child: const Text('Login', style: TextStyle(fontSize: 18)),
                              ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen())),
                          child: const Text('Create New Mess (Sign Up as Manager)', style: TextStyle(color: Colors.amber)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Signup Screen (Manager Signup with Mess Name)
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => SignupScreenState();
}

class SignupScreenState extends State<SignupScreen> {
  final TextEditingController _messController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  
  String _errorMessage = "";
  bool _isLoading = false;

  void _validateAndSignup() async {
    String mess = _messController.text.trim();
    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String whatsapp = _whatsappController.text.trim();

    if (mess.isEmpty || name.isEmpty || email.isEmpty || whatsapp.isEmpty) {
      setState(() => _errorMessage = "সব ফিল্ড পূরণ করুন!");
      return;
    }

    setState(() => _isLoading = true);
    int randomNum = Random().nextInt(900000) + 100000;
    String code = randomNum.toString();

    try {
      var docRef = await FirebaseFirestore.instance.collection('messes').add({
        'mess_name': mess,
        'mess_code': code,
        'notice': 'স্বাগতম নতুন মেসে!',
        'duty_list': [],
        'chat_list': [],
        'monthly_history': [],
        'members': [
          {
            'name': name,
            'email': email,
            'whatsapp': whatsapp,
            'is_manager': true,
            'is_removed': false,
            'bazaar': 0.0,
            'bazaar_entries': [],
            'dailyMeals': {},
          }
        ]
      });

      globalMessDocId = docRef.id;
      globalMessName = mess;
      globalMessCode = code;
      globalUserEmail = email;
      isAdminLoggedIn = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('is_admin', true);
      await prefs.setString('mess_name', globalMessName);
      await prefs.setString('mess_code', globalMessCode);
      await prefs.setString('mess_doc_id', globalMessDocId);
      await prefs.setString('user_email', globalUserEmail);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _errorMessage = "ত্রুটি: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manager Sign Up'), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: Container(
        decoration: dynamic3DBackground(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Card(
                  elevation: 6,
                  color: Colors.white.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Register Mess', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 20),
                        TextField(controller: _messController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Mess Name', labelStyle: TextStyle(color: Colors.white70))),
                        const SizedBox(height: 12),
                        TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Manager Name', labelStyle: TextStyle(color: Colors.white70))),
                        const SizedBox(height: 12),
                        TextField(controller: _emailController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: Colors.white70))),
                        const SizedBox(height: 12),
                        TextField(controller: _whatsappController, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp', labelStyle: TextStyle(color: Colors.white70))),
                        const SizedBox(height: 10),
                        if (_errorMessage.isNotEmpty)
                          Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
                                onPressed: _validateAndSignup,
                                child: const Text('Create Mess', style: TextStyle(fontSize: 18)),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('messes').doc(globalMessDocId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(backgroundColor: Color(0xFF0f0c29), body: Center(child: CircularProgressIndicator(color: Colors.white)));
        }
        var messData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        List members = messData['members'] ?? [];
        
        for (var m in members) {
          if ((m['email'] ?? "").toString().toLowerCase() == globalUserEmail.toLowerCase()) {
            if (m['is_manager'] == true) {
              isAdminLoggedIn = true;
            } else {
              isAdminLoggedIn = false;
            }
          }
        }

        String notice = messData['notice'] ?? '';
        List chatList = messData['chat_list'] ?? [];
        List historyList = messData['monthly_history'] ?? [];

        return MainDashboard(
          members: members,
          notice: notice,
          chatList: chatList,
          historyList: historyList,
        );
      },
    );
  }
}

class MainDashboard extends StatefulWidget {
  final List members;
  final String notice;
  final List chatList;
  final List historyList;

  const MainDashboard({super.key, required this.members, required this.notice, required this.chatList, required this.historyList});

  @override
  State<MainDashboard> createState() => MainDashboardState();
}

class MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      MealEntryTab(members: widget.members),
      CalculationTab(members: widget.members),
      NoticeChatTab(notice: widget.notice, chatList: widget.chatList, members: widget.members),
      ProfileTab(historyList: widget.historyList, members: widget.members),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.greenAccent,
        unselectedItemColor: Colors.white60,
        backgroundColor: const Color(0xFF1a1a2e),
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Meals'),
          BottomNavigationBarItem(icon: Icon(Icons.calculate), label: 'Calculation'),
          BottomNavigationBarItem(icon: Icon(Icons.forum), label: 'Notice & Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class MealEntryTab extends StatefulWidget {
  final List members;
  const MealEntryTab({super.key, required this.members});

  @override
  State<MealEntryTab> createState() => MealEntryTabState();
}

class MealEntryTabState extends State<MealEntryTab> {
  String selectedDate = DateTime.now().toIso8601String().split('T')[0];

  Future<void> _updateFirestoreMembers(List updatedMembers) async {
    await FirebaseFirestore.instance.collection('messes').doc(globalMessDocId).update({
      'members': updatedMembers,
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(selectedDate) ?? DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => selectedDate = picked.toIso8601String().split('T')[0]);
    }
  }

  void _showAddMemberDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController whatsappController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: const Text('Add New Member', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.white70))),
                const SizedBox(height: 8),
                TextField(controller: emailController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Email (Must match login)', labelStyle: TextStyle(color: Colors.white70))),
                const SizedBox(height: 8),
                TextField(controller: whatsappController, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp', labelStyle: TextStyle(color: Colors.white70))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                String name = nameController.text.trim();
                String email = emailController.text.trim();
                String whatsapp = whatsappController.text.trim();
                if (name.isNotEmpty && email.isNotEmpty) {
                  List newMembers = List.from(widget.members);
                  newMembers.add({
                    'name': name,
                    'email': email,
                    'whatsapp': whatsapp,
                    'is_manager': false,
                    'is_removed': false,
                    'bazaar': 0.0,
                    'bazaar_entries': [],
                    'dailyMeals': {},
                  });
                  await _updateFirestoreMembers(newMembers);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List activeMembers = widget.members.where((m) => m['is_removed'] != true).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('$globalMessName (${isAdminLoggedIn ? 'Manager' : 'Member'})'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: dynamic3DBackground(),
        child: Column(
          children: [
            Container(
              color: Colors.black26,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Date: $selectedDate', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Change Date'),
                  ),
                ],
              ),
            ),
            if (isAdminLoggedIn)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  onPressed: () => _showAddMemberDialog(context),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Member'),
                ),
              ),
            Expanded(
              child: activeMembers.isEmpty
                  ? const Center(child: Text('No active members', style: TextStyle(color: Colors.white70)))
                  : ListView.builder(
                      itemCount: activeMembers.length,
                      itemBuilder: (context, index) {
                        final member = activeMembers[index];
                        Map dailyMeals = member['dailyMeals'] ?? {};
                        Map todayMeal = dailyMeals[selectedDate] ?? {'lunch': 0, 'dinner': 0};
                        int l = int.tryParse((todayMeal['lunch'] ?? 0).toString()) ?? 0;
                        int d = int.tryParse((todayMeal['dinner'] ?? 0).toString()) ?? 0;
                        int todayTotalMeals = l + d;

                        return Card(
                          color: Colors.white.withOpacity(0.08),
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.white.withOpacity(0.12), width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Member Name, Email and Today's Total Badge
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              Text(
                                                member['name'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.amber,
                                                ),
                                              ),
                                              if (member['is_manager'] == true)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.amber, width: 0.8),
                                                  ),
                                                  child: const Text(
                                                    'Manager',
                                                    style: TextStyle(
                                                      color: Colors.amber,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if ((member['email'] ?? '').toString().isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Email: ${member['email']}',
                                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Total Meals Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.greenAccent.withOpacity(0.6), width: 1),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('Total', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                          Text(
                                            '$todayTotalMeals',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(color: Colors.white24, height: 16),
                                // Responsive Lunch and Dinner controls
                                Row(
                                  children: [
                                    // Lunch Box
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Lunch',
                                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                                            ),
                                            if (isAdminLoggedIn)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: l > 0
                                                          ? () async {
                                                              todayMeal['lunch'] = l - 1;
                                                              dailyMeals[selectedDate] = todayMeal;
                                                              member['dailyMeals'] = dailyMeals;
                                                              await _updateFirestoreMembers(widget.members);
                                                            }
                                                          : null,
                                                      borderRadius: BorderRadius.circular(14),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(3.0),
                                                        child: Icon(
                                                          Icons.remove_circle_outline,
                                                          size: 22,
                                                          color: l > 0 ? Colors.redAccent : Colors.white24,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                                    child: Text(
                                                      '$l',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () async {
                                                        todayMeal['lunch'] = l + 1;
                                                        dailyMeals[selectedDate] = todayMeal;
                                                        member['dailyMeals'] = dailyMeals;
                                                        await _updateFirestoreMembers(widget.members);
                                                      },
                                                      borderRadius: BorderRadius.circular(14),
                                                      child: const Padding(
                                                        padding: EdgeInsets.all(3.0),
                                                        child: Icon(
                                                          Icons.add_circle_outline,
                                                          size: 22,
                                                          color: Colors.greenAccent,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            else
                                              Text(
                                                '$l',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Dinner Box
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Dinner',
                                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                                            ),
                                            if (isAdminLoggedIn)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: d > 0
                                                          ? () async {
                                                              todayMeal['dinner'] = d - 1;
                                                              dailyMeals[selectedDate] = todayMeal;
                                                              member['dailyMeals'] = dailyMeals;
                                                              await _updateFirestoreMembers(widget.members);
                                                            }
                                                          : null,
                                                      borderRadius: BorderRadius.circular(14),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(3.0),
                                                        child: Icon(
                                                          Icons.remove_circle_outline,
                                                          size: 22,
                                                          color: d > 0 ? Colors.redAccent : Colors.white24,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                                    child: Text(
                                                      '$d',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () async {
                                                        todayMeal['dinner'] = d + 1;
                                                        dailyMeals[selectedDate] = todayMeal;
                                                        member['dailyMeals'] = dailyMeals;
                                                        await _updateFirestoreMembers(widget.members);
                                                      },
                                                      borderRadius: BorderRadius.circular(14),
                                                      child: const Padding(
                                                        padding: EdgeInsets.all(3.0),
                                                        child: Icon(
                                                          Icons.add_circle_outline,
                                                          size: 22,
                                                          color: Colors.greenAccent,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            else
                                              Text(
                                                '$d',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class CalculationTab extends StatefulWidget {
  final List members;
  const CalculationTab({super.key, required this.members});

  @override
  State<CalculationTab> createState() => CalculationTabState();
}

class CalculationTabState extends State<CalculationTab> {
  Future<void> _updateFirestoreMembers(List updatedMembers) async {
    await FirebaseFirestore.instance.collection('messes').doc(globalMessDocId).update({
      'members': updatedMembers,
    });
  }

  void _showAddBazaarDialog(int index) {
    final member = widget.members[index];
    final TextEditingController amountController = TextEditingController();
    final TextEditingController noteController = TextEditingController();

    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
            String formattedTime = selectedTime.format(context);

            return AlertDialog(
              backgroundColor: const Color(0xFF1a1a2e),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.shopping_cart, color: Colors.greenAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Add Bazaar for ${member['name']}',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: amountController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount (Tk)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.attach_money, color: Colors.greenAccent),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Date Picker
                    InkWell(
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Text('Date: $formattedDate',
                                style: const TextStyle(color: Colors.white, fontSize: 14)),
                            const Spacer(),
                            const Text('Change',
                                style: TextStyle(color: Colors.greenAccent, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Time Picker
                    InkWell(
                      onTap: () async {
                        TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setDialogState(() => selectedTime = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Text('Time: $formattedTime',
                                style: const TextStyle(color: Colors.white, fontSize: 14)),
                            const Spacer(),
                            const Text('Change',
                                style: TextStyle(color: Colors.greenAccent, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Items / Note (e.g. চাল, মাছ, সবজি)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.notes, color: Colors.amber),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Save Bazaar'),
                  onPressed: () async {
                    double amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (amount > 0) {
                      List updated = List.from(widget.members);
                      double currentBazaar =
                          double.tryParse((updated[index]['bazaar'] ?? 0.0).toString()) ?? 0.0;
                      updated[index]['bazaar'] = currentBazaar + amount;

                      List entries = List.from(updated[index]['bazaar_entries'] ?? []);
                      entries.add({
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                        'date': formattedDate,
                        'time': formattedTime,
                        'amount': amount,
                        'note': noteController.text.trim(),
                        'added_at': DateTime.now().toIso8601String(),
                      });
                      updated[index]['bazaar_entries'] = entries;

                      await _updateFirestoreMembers(updated);
                      if (!dialogCtx.mounted) return;
                      Navigator.pop(dialogCtx);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBazaarHistoryDialog(int index) {
    final member = widget.members[index];
    List entries = List.from(member['bazaar_entries'] ?? []);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double totalMemberBazaar = entries.fold(0.0, (prev, e) {
              return prev + (double.tryParse((e['amount'] ?? 0).toString()) ?? 0.0);
            });

            return AlertDialog(
              backgroundColor: const Color(0xFF1a1a2e),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bazaar Log: ${member['name']}',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: entries.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          'No detailed date-wise entries recorded yet.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: entries.length,
                        itemBuilder: (context, eIdx) {
                          final entry = entries[eIdx];
                          double amt =
                              double.tryParse((entry['amount'] ?? 0).toString()) ?? 0.0;
                          String note = (entry['note'] ?? '').toString();

                          return Card(
                            color: Colors.white12,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.green,
                                radius: 18,
                                child:
                                    Icon(Icons.shopping_bag, size: 18, color: Colors.white),
                              ),
                              title: Text(
                                '${amt.toStringAsFixed(2)} Tk',
                                style: const TextStyle(
                                    color: Colors.greenAccent, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    'Date: ${entry['date']} | Time: ${entry['time']}',
                                    style:
                                        const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                  if (note.isNotEmpty)
                                    Text(
                                      'Items: $note',
                                      style: const TextStyle(
                                          color: Colors.amberAccent, fontSize: 12),
                                    ),
                                ],
                              ),
                              trailing: isAdminLoggedIn
                                  ? IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.redAccent, size: 20),
                                      onPressed: () async {
                                        List updated = List.from(widget.members);
                                        List memberEntries =
                                            List.from(updated[index]['bazaar_entries'] ?? []);
                                        memberEntries.removeAt(eIdx);
                                        updated[index]['bazaar_entries'] = memberEntries;

                                        double newTotal = memberEntries.fold(0.0, (prev, e) {
                                          return prev +
                                              (double.tryParse((e['amount'] ?? 0).toString()) ??
                                                  0.0);
                                        });
                                        updated[index]['bazaar'] = newTotal;

                                        await _updateFirestoreMembers(updated);
                                        setModalState(() {
                                          entries = memberEntries;
                                        });
                                      },
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                if (entries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'Total: ${totalMemberBazaar.toStringAsFixed(2)} Tk',
                      style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Close', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAllMessBazaarDialog(List activeMembers) {
    List<Map<String, dynamic>> allEntries = [];
    for (var m in activeMembers) {
      List entries = m['bazaar_entries'] ?? [];
      for (var e in entries) {
        allEntries.add({
          'member_name': m['name'] ?? 'Member',
          'date': e['date'] ?? '-',
          'time': e['time'] ?? '-',
          'amount': double.tryParse((e['amount'] ?? 0).toString()) ?? 0.0,
          'note': e['note'] ?? '',
        });
      }
    }
    // Sort newest first
    allEntries.sort((a, b) =>
        '${b['date']} ${b['time']}'.compareTo('${a['date']} ${a['time']}'));

    double grandTotal = allEntries.fold(0.0, (total, e) => total + (e['amount'] as double));

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.receipt, color: Colors.amber),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('All Mess Bazaar Expenses',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Bazaar Recorded:',
                          style: TextStyle(color: Colors.white70)),
                      Text('${grandTotal.toStringAsFixed(2)} Tk',
                          style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                allEntries.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text('No bazaar expenses recorded yet.',
                            style: TextStyle(color: Colors.white70)),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 380),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: allEntries.length,
                          itemBuilder: (context, idx) {
                            final item = allEntries[idx];
                            return Card(
                              color: Colors.white12,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.shade800,
                                  child: Text('${idx + 1}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                ),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(item['member_name'],
                                        style: const TextStyle(
                                            color: Colors.amber,
                                            fontWeight: FontWeight.bold)),
                                    Text('${(item['amount'] as double).toStringAsFixed(2)} Tk',
                                        style: const TextStyle(
                                            color: Colors.greenAccent,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text('Date: ${item['date']} | Time: ${item['time']}',
                                        style: const TextStyle(
                                            color: Colors.white70, fontSize: 12)),
                                    if (item['note'].toString().isNotEmpty)
                                      Text('Items: ${item['note']}',
                                          style: const TextStyle(
                                              color: Colors.white60, fontSize: 12)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadLiveStatementPdf(
    BuildContext context,
    double totalBazaar,
    int totalMeals,
    double mealRate,
    List activeMembers,
  ) async {
    List memberSummaries = [];
    for (var m in activeMembers) {
      int mMeals = 0;
      Map daily = m['dailyMeals'] ?? {};
      daily.forEach((k, v) {
        if (v is Map) {
          mMeals += (int.tryParse((v['lunch'] ?? 0).toString()) ?? 0) +
              (int.tryParse((v['dinner'] ?? 0).toString()) ?? 0);
        }
      });
      double mCost = mMeals * mealRate;
      double mBazaar = double.tryParse((m['bazaar'] ?? 0.0).toString()) ?? 0.0;
      double balance = mBazaar - mCost;

      memberSummaries.add({
        'name': m['name'],
        'email': m['email'],
        'whatsapp': m['whatsapp'],
        'meals': mMeals,
        'bazaar': mBazaar,
        'cost': mCost,
        'balance': balance,
        'dailyMeals': Map<String, dynamic>.from(daily),
        'bazaar_entries': List<Map<String, dynamic>>.from(m['bazaar_entries'] ?? []),
      });
    }

    String currentMonthName = DateFormat('MMMM yyyy').format(DateTime.now());

    final pdf = await MessPdfHelper.generateReport(
      messName: globalMessName,
      messCode: globalMessCode,
      month: currentMonthName,
      managerName: isAdminLoggedIn ? 'Manager' : 'Live Statement',
      totalBazaar: totalBazaar,
      totalMeals: totalMeals,
      mealRate: mealRate,
      memberSummaries: memberSummaries,
    );

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.picture_as_pdf, color: Colors.amber),
              SizedBox(width: 8),
              Text('Monthly Statement PDF', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generate and download the complete PDF statement for $currentMonthName with day-by-day meals and bazaar dates/times.',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                ),
                icon: const Icon(Icons.download),
                label: const Text('Download PDF File',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await MessPdfHelper.downloadPdf(
                    document: pdf,
                    filename:
                        '${globalMessName}_Statement_${DateFormat('yyyy_MM_dd').format(DateTime.now())}.pdf',
                    context: dialogCtx,
                  );
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.greenAccent),
                  minimumSize: const Size(double.infinity, 42),
                ),
                icon: const Icon(Icons.print, color: Colors.greenAccent),
                label: const Text('Print / Preview PDF'),
                onPressed: () async {
                  await MessPdfHelper.printOrPreview(
                    document: pdf,
                    filename:
                        '${globalMessName}_Statement_${DateFormat('yyyy_MM_dd').format(DateTime.now())}.pdf',
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List activeMembers = widget.members.where((m) => m['is_removed'] != true).toList();
    double totalMessBazaar = activeMembers.fold(0.0, (total, item) {
      double b = double.tryParse((item['bazaar'] ?? 0.0).toString()) ?? 0.0;
      return total + b;
    });

    int totalMessMeals = 0;
    for (var member in activeMembers) {
      Map dailyMeals = member['dailyMeals'] ?? {};
      dailyMeals.forEach((date, meals) {
        if (meals is Map) {
          totalMessMeals += (int.tryParse((meals['lunch'] ?? 0).toString()) ?? 0) +
              (int.tryParse((meals['dinner'] ?? 0).toString()) ?? 0);
        }
      });
    }

    double mealRate = totalMessMeals > 0 ? (totalMessBazaar / totalMessMeals) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculation & Expenses'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: dynamic3DBackground(),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent, width: 1.5),
              ),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total Mess Bazaar:',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
                    Text('${totalMessBazaar.toStringAsFixed(2)} Tk',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.greenAccent)),
                  ]),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total Mess Meals:',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
                    Text('$totalMessMeals Meals',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ]),
                  const Divider(color: Colors.white24),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Current Meal Rate:',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text('${mealRate.toStringAsFixed(2)} Tk',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber)),
                  ]),
                  const SizedBox(height: 12),
                  // Action buttons for All Bazaar Log and PDF Download
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.receipt_long, size: 16),
                          label: const Text('All Bazaar Log',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                          onPressed: () => _showAllMessBazaarDialog(activeMembers),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.picture_as_pdf, size: 16),
                          label: const Text('Download PDF',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                          onPressed: () => _downloadLiveStatementPdf(
                              context, totalMessBazaar, totalMessMeals, mealRate, activeMembers),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: activeMembers.isEmpty
                  ? const Center(
                      child: Text('No active members',
                          style: TextStyle(color: Colors.white70)))
                  : ListView.builder(
                      itemCount: activeMembers.length,
                      itemBuilder: (context, index) {
                        final member = activeMembers[index];
                        int memberTotalMeals = 0;
                        Map dailyMeals = member['dailyMeals'] ?? {};
                        dailyMeals.forEach((date, meals) {
                          if (meals is Map) {
                            memberTotalMeals +=
                                (int.tryParse((meals['lunch'] ?? 0).toString()) ?? 0) +
                                    (int.tryParse((meals['dinner'] ?? 0).toString()) ?? 0);
                          }
                        });

                        double memberMealCost = memberTotalMeals * mealRate;
                        double memberBazaar =
                            double.tryParse((member['bazaar'] ?? 0.0).toString()) ?? 0.0;
                        double balance = memberBazaar - memberMealCost;

                        List memberEntries = List.from(member['bazaar_entries'] ?? []);
                        int originalIndex = widget.members
                            .indexWhere((m) => m['email'] == member['email']);

                        return Card(
                          color: Colors.white.withOpacity(0.1),
                          margin:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${member['name'] ?? ''} ${member['is_manager'] == true ? '(Manager)' : ''}',
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (memberEntries.isNotEmpty)
                                          IconButton(
                                            tooltip: 'View Bazaar Details',
                                            icon: const Icon(Icons.history,
                                                color: Colors.amberAccent),
                                            onPressed: () => _showBazaarHistoryDialog(
                                                originalIndex),
                                          ),
                                        if (isAdminLoggedIn)
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.greenAccent),
                                            icon: const Icon(Icons.add, size: 16),
                                            onPressed: () => _showAddBazaarDialog(
                                                originalIndex),
                                            label: const Text('Add Bazaar'),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(color: Colors.white24),
                                Text('Total Meals: $memberTotalMeals',
                                    style: const TextStyle(color: Colors.white70)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        'Bazaar Given: ${memberBazaar.toStringAsFixed(2)} Tk',
                                        style: const TextStyle(color: Colors.white70)),
                                    if (memberEntries.isNotEmpty)
                                      Flexible(
                                        child: InkWell(
                                          onTap: () => _showBazaarHistoryDialog(originalIndex),
                                          child: Text(
                                            '(${memberEntries.length} entries - View)',
                                            style: const TextStyle(
                                              color: Colors.amber,
                                              fontSize: 11,
                                              decoration: TextDecoration.underline,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Text('Meal Cost: ${memberMealCost.toStringAsFixed(2)} Tk',
                                    style: const TextStyle(color: Colors.white70)),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Balance (Due/Return):',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white)),
                                    Text(
                                      '${balance >= 0 ? '+' : ''}${balance.toStringAsFixed(2)} Tk',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: balance >= 0
                                            ? Colors.greenAccent
                                            : Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class NoticeChatTab extends StatefulWidget {
  final String notice;
  final List chatList;
  final List members;

  const NoticeChatTab({super.key, required this.notice, required this.chatList, required this.members});

  @override
  State<NoticeChatTab> createState() => NoticeChatTabState();
}

class NoticeChatTabState extends State<NoticeChatTab> {
  final TextEditingController _noticeController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();

  void _updateNotice() async {
    await FirebaseFirestore.instance.collection('messes').doc(globalMessDocId).update({
      'notice': _noticeController.text.trim(),
    });
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _sendChatMessage() async {
    if (_chatController.text.trim().isEmpty) return;
    String senderName = "Member";
    for (var m in widget.members) {
      if ((m['email'] ?? "").toString().toLowerCase() == globalUserEmail.toLowerCase()) {
        senderName = m['name'] ?? "Member";
        if (m['is_manager'] == true) senderName += " (Manager)";
      }
    }

    List updatedChat = List.from(widget.chatList);
    updatedChat.add({
      'sender': senderName,
      'message': _chatController.text.trim(),
      'time': TimeOfDay.now().format(context),
    });

    await FirebaseFirestore.instance.collection('messes').doc(globalMessDocId).update({
      'chat_list': updatedChat,
    });
    _chatController.clear();
  }

  void _showEditNoticeDialog() {
    _noticeController.text = widget.notice;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Edit Bazaar Notice', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: TextField(
            controller: _noticeController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Write notice here...', hintStyle: TextStyle(color: Colors.white54)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: _updateNotice, child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notice & Messenger Chat'), backgroundColor: Colors.green.shade800, foregroundColor: Colors.white),
      body: Container(
        decoration: dynamic3DBackground(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
                elevation: 4,
                color: Colors.amber.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('📌 Manager Notice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                          if (isAdminLoggedIn)
                            IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: _showEditNoticeDialog),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(widget.notice.isEmpty ? 'No notice available' : widget.notice, style: const TextStyle(fontSize: 15, color: Colors.black54)),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(color: Colors.white24),
            const Text('Messenger Group Chat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            Expanded(
              child: widget.chatList.isEmpty
                  ? const Center(child: Text('No messages yet. Start chatting!', style: TextStyle(color: Colors.white70)))
                  : ListView.builder(
                      itemCount: widget.chatList.length,
                      itemBuilder: (context, index) {
                        var chat = widget.chatList[index];
                        return Card(
                          color: Colors.white.withOpacity(0.1),
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            title: Text(chat['sender'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 13)),
                            subtitle: Text(chat['message'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15)),
                            trailing: Text(chat['time'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black38,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.greenAccent),
                    onPressed: _sendChatMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTab extends StatefulWidget {
  final List historyList;
  final List members;

  const ProfileTab({super.key, required this.historyList, required this.members});

  @override
  ProfileTabState createState() => ProfileTabState();
}

class ProfileTabState extends State<ProfileTab> {
  Future<void> _downloadCurrentMonthReport(BuildContext context) async {
    List activeMembers = widget.members.where((m) => m['is_removed'] != true).toList();
    double totalBazaar = activeMembers.fold(
        0.0,
        (total, m) =>
            total + (double.tryParse((m['bazaar'] ?? 0.0).toString()) ?? 0.0));

    int totalMeals = 0;
    for (var m in activeMembers) {
      Map daily = m['dailyMeals'] ?? {};
      daily.forEach((k, v) {
        if (v is Map) {
          totalMeals += (int.tryParse((v['lunch'] ?? 0).toString()) ?? 0) +
              (int.tryParse((v['dinner'] ?? 0).toString()) ?? 0);
        }
      });
    }
    double mealRate = totalMeals > 0 ? totalBazaar / totalMeals : 0.0;

    List memberSummaries = [];
    for (var m in activeMembers) {
      int mMeals = 0;
      Map daily = m['dailyMeals'] ?? {};
      daily.forEach((k, v) {
        if (v is Map) {
          mMeals += (int.tryParse((v['lunch'] ?? 0).toString()) ?? 0) +
              (int.tryParse((v['dinner'] ?? 0).toString()) ?? 0);
        }
      });
      double mCost = mMeals * mealRate;
      double mBazaar = double.tryParse((m['bazaar'] ?? 0.0).toString()) ?? 0.0;
      double balance = mBazaar - mCost;

      memberSummaries.add({
        'name': m['name'],
        'email': m['email'],
        'whatsapp': m['whatsapp'],
        'meals': mMeals,
        'bazaar': mBazaar,
        'cost': mCost,
        'balance': balance,
        'dailyMeals': Map<String, dynamic>.from(daily),
        'bazaar_entries': List<Map<String, dynamic>>.from(m['bazaar_entries'] ?? []),
      });
    }

    String currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());
    final pdf = await MessPdfHelper.generateReport(
      messName: globalMessName,
      messCode: globalMessCode,
      month: currentMonth,
      managerName: isAdminLoggedIn ? 'Manager' : 'Statement',
      totalBazaar: totalBazaar,
      totalMeals: totalMeals,
      mealRate: mealRate,
      memberSummaries: memberSummaries,
    );

    if (!context.mounted) return;
    await MessPdfHelper.downloadPdf(
      document: pdf,
      filename:
          '${globalMessName}_Statement_${DateFormat('yyyy_MM_dd').format(DateTime.now())}.pdf',
      context: context,
    );
  }

  void _showChangeManagerDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Change Manager & Close Month',
              style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.members.length,
              itemBuilder: (context, index) {
                final member = widget.members[index];
                bool isAlreadyManager = member['is_manager'] ?? false;
                return ListTile(
                  title: Text(member['name'] ?? '',
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(member['email'] ?? '',
                      style: const TextStyle(color: Colors.white70)),
                  trailing: isAlreadyManager
                      ? const Text('Manager',
                          style: TextStyle(color: Colors.greenAccent))
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white),
                          onPressed: () async {
                            List activeMembers = widget.members
                                .where((m) => m['is_removed'] != true)
                                .toList();
                            double totalBazaar = activeMembers.fold(
                                0.0,
                                (total, m) =>
                                    total +
                                    (double.tryParse((m['bazaar'] ?? 0.0).toString()) ??
                                        0.0));

                            int totalMeals = 0;
                            for (var m in activeMembers) {
                              Map daily = m['dailyMeals'] ?? {};
                              daily.forEach((k, v) {
                                if (v is Map) {
                                  totalMeals +=
                                      (int.tryParse((v['lunch'] ?? 0).toString()) ?? 0) +
                                          (int.tryParse((v['dinner'] ?? 0).toString()) ??
                                              0);
                                }
                              });
                            }
                            double mealRate =
                                totalMeals > 0 ? totalBazaar / totalMeals : 0.0;

                            List memberSummaries = [];
                            for (var m in activeMembers) {
                              int mMeals = 0;
                              Map daily = m['dailyMeals'] ?? {};
                              daily.forEach((k, v) {
                                if (v is Map) {
                                  mMeals +=
                                      (int.tryParse((v['lunch'] ?? 0).toString()) ??
                                              0) +
                                          (int.tryParse((v['dinner'] ?? 0).toString()) ??
                                              0);
                                }
                              });
                              double mCost = mMeals * mealRate;
                              double mBazaar =
                                  double.tryParse((m['bazaar'] ?? 0.0).toString()) ??
                                      0.0;
                              double balance = mBazaar - mCost;

                              memberSummaries.add({
                                'name': m['name'],
                                'email': m['email'],
                                'whatsapp': m['whatsapp'],
                                'meals': mMeals,
                                'bazaar': mBazaar,
                                'cost': mCost,
                                'balance': balance,
                                'dailyMeals': Map<String, dynamic>.from(daily),
                                'bazaar_entries': List<Map<String, dynamic>>.from(
                                    m['bazaar_entries'] ?? []),
                              });
                            }

                            Map<String, dynamic> historyItem = {
                              'month': DateTime.now().toString().substring(0, 7),
                              'closed_at': DateTime.now().toIso8601String(),
                              'closed_by': globalUserEmail,
                              'total_meals': totalMeals,
                              'total_bazaar': totalBazaar,
                              'meal_rate': mealRate,
                              'member_summaries': memberSummaries,
                            };

                            List updatedHistory = List.from(widget.historyList);
                            updatedHistory.add(historyItem);

                            List updatedMembers = List.from(widget.members);
                            for (var min in updatedMembers) {
                              min['is_manager'] = false;
                              min['bazaar'] = 0.0;
                              min['bazaar_entries'] = [];
                              min['dailyMeals'] = {};
                            }
                            updatedMembers[index]['is_manager'] = true;

                            await FirebaseFirestore.instance
                                .collection('messes')
                                .doc(globalMessDocId)
                                .update({
                              'monthly_history': updatedHistory,
                              'members': updatedMembers,
                            });

                            isAdminLoggedIn = false;
                            if (!dialogCtx.mounted) return;
                            Navigator.pop(dialogCtx);
                            _showPdfDownloadSuccessDialog(historyItem);
                          },
                          child: const Text('Make Manager'),
                        ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel')),
          ],
        );
      },
    );
  }

  void _showPdfDownloadSuccessDialog(Map historyItem) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Month Closed & PDF Ready!',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The month has been closed and accounts reset for the new manager. You can now download the official PDF statement with all day-by-day meals and bazaar history.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
              ),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Download Month-End PDF Report',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                final pdf = await MessPdfHelper.generateReport(
                  messName: globalMessName,
                  messCode: globalMessCode,
                  month: historyItem['month'] ?? 'Month-End',
                  managerName: historyItem['closed_by'] ?? 'Manager',
                  totalBazaar:
                      double.tryParse((historyItem['total_bazaar'] ?? 0).toString()) ??
                          0.0,
                  totalMeals:
                      int.tryParse((historyItem['total_meals'] ?? 0).toString()) ?? 0,
                  mealRate:
                      double.tryParse((historyItem['meal_rate'] ?? 0).toString()) ??
                          0.0,
                  memberSummaries: historyItem['member_summaries'] ?? [],
                );
                if (!dialogCtx.mounted) return;
                await MessPdfHelper.downloadPdf(
                  document: pdf,
                  filename: '${globalMessName}_Report_${historyItem['month']}.pdf',
                  context: dialogCtx,
                );
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.greenAccent),
                minimumSize: const Size(double.infinity, 42),
              ),
              icon: const Icon(Icons.print, color: Colors.greenAccent),
              label: const Text('Preview / Print PDF'),
              onPressed: () async {
                final pdf = await MessPdfHelper.generateReport(
                  messName: globalMessName,
                  messCode: globalMessCode,
                  month: historyItem['month'] ?? 'Month-End',
                  managerName: historyItem['closed_by'] ?? 'Manager',
                  totalBazaar:
                      double.tryParse((historyItem['total_bazaar'] ?? 0).toString()) ??
                          0.0,
                  totalMeals:
                      int.tryParse((historyItem['total_meals'] ?? 0).toString()) ?? 0,
                  mealRate:
                      double.tryParse((historyItem['meal_rate'] ?? 0).toString()) ??
                          0.0,
                  memberSummaries: historyItem['member_summaries'] ?? [],
                );
                await MessPdfHelper.printOrPreview(
                  document: pdf,
                  filename: '${globalMessName}_Report_${historyItem['month']}.pdf',
                );
              },
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!dialogCtx.mounted) return;
              Navigator.pop(dialogCtx);
              Navigator.pushReplacement(
                dialogCtx,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text('OK / Login Again'),
          ),
        ],
      ),
    );
  }

  void _showPreviousHistoryDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Monthly Result PDF / History',
              style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: widget.historyList.isEmpty
                ? const Text('No history found.',
                    style: TextStyle(color: Colors.white70))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.historyList.length,
                    itemBuilder: (context, index) {
                      var history = widget.historyList[index];
                      double tBazaar =
                          double.tryParse((history['total_bazaar'] ?? 0.0).toString()) ??
                              0.0;
                      int tMeals =
                          int.tryParse((history['total_meals'] ?? 0).toString()) ?? 0;
                      double mRate =
                          double.tryParse((history['meal_rate'] ?? 0.0).toString()) ??
                              0.0;
                      List summaries = history['member_summaries'] ?? [];

                      return ExpansionTile(
                        title: Text('Month: ${history['month']}',
                            style: const TextStyle(
                                color: Colors.amber, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            'Bazaar: ${tBazaar.toStringAsFixed(2)} Tk | Meals: $tMeals | Rate: ${mRate.toStringAsFixed(2)} Tk',
                            style: const TextStyle(color: Colors.white70)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber.shade700,
                                        foregroundColor: Colors.white),
                                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                                    label: const Text('Download PDF'),
                                    onPressed: () async {
                                      final pdf = await MessPdfHelper.generateReport(
                                        messName: globalMessName,
                                        messCode: globalMessCode,
                                        month: history['month'] ?? 'Archive',
                                        managerName:
                                            history['closed_by'] ?? 'Manager',
                                        totalBazaar: tBazaar,
                                        totalMeals: tMeals,
                                        mealRate: mRate,
                                        memberSummaries: summaries,
                                      );
                                      if (!dialogCtx.mounted) return;
                                      await MessPdfHelper.downloadPdf(
                                        document: pdf,
                                        filename:
                                            '${globalMessName}_Report_${history['month']}.pdf',
                                        context: dialogCtx,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white30)),
                                  icon: const Icon(Icons.print, size: 18),
                                  label: const Text('Print'),
                                  onPressed: () async {
                                    final pdf = await MessPdfHelper.generateReport(
                                      messName: globalMessName,
                                      messCode: globalMessCode,
                                      month: history['month'] ?? 'Archive',
                                      managerName:
                                          history['closed_by'] ?? 'Manager',
                                      totalBazaar: tBazaar,
                                      totalMeals: tMeals,
                                      mealRate: mRate,
                                      memberSummaries: summaries,
                                    );
                                    await MessPdfHelper.printOrPreview(
                                      document: pdf,
                                      filename:
                                          '${globalMessName}_Report_${history['month']}.pdf',
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          ...summaries.map((m) {
                            double bal =
                                double.tryParse((m['balance'] ?? 0.0).toString()) ?? 0.0;
                            return ListTile(
                              title: Text(m['name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              subtitle: Text(
                                  'Meals: ${m['meals']} | Bazaar: ${m['bazaar']} Tk',
                                  style: const TextStyle(color: Colors.white60)),
                              trailing: Text(
                                '${bal >= 0 ? '+' : ''}${bal.toStringAsFixed(2)} Tk',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: bal >= 0
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Close')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Map currentUser = {};
    for (var m in widget.members) {
      if ((m['email'] ?? "").toString().toLowerCase() ==
          globalUserEmail.toLowerCase()) {
        currentUser = m;
      }
    }

    return Scaffold(
      appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.green.shade800,
          foregroundColor: Colors.white),
      body: Container(
        decoration: dynamic3DBackground(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.green,
                          child: Icon(Icons.person, size: 50, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Text(currentUser['name'] ?? 'User Name',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber)),
                        const SizedBox(height: 4),
                        Text(
                            'Email: ${currentUser['email'] ?? globalUserEmail}',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text(
                            'Mobile/WhatsApp: ${currentUser['whatsapp'] ?? 'N/A'}',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text('Mess Name: $globalMessName',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text('Mess Code: $globalMessCode',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text(
                            'Role: ${isAdminLoggedIn ? "Manager" : "Member"}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.greenAccent)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              foregroundColor: Colors.white),
                          onPressed: () => _downloadCurrentMonthReport(context),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Download Current Month PDF'),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white),
                          onPressed: _showPreviousHistoryDialog,
                          icon: const Icon(Icons.history),
                          label: const Text('Monthly Result PDF / History'),
                        ),
                        const SizedBox(height: 8),
                        if (isAdminLoggedIn)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white),
                            onPressed: _showChangeManagerDialog,
                            icon: const Icon(Icons.swap_horiz),
                            label: const Text('Change Manager & Close Month'),
                          ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white),
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear();
                            if (!context.mounted) return;
                            Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const LoginScreen()));
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}