import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCDb3h17Muv8IIPJUk9IlTa6zrZGR_Rj9Y",
      authDomain: "bogo-sos-app.firebaseapp.com",
      projectId: "bogo-sos-app",
      storageBucket: "bogo-sos-app.firebasestorage.app",
      messagingSenderId: "699795773134",
      appId: "1:699795773134:web:3f3e15077b9a64d4aa229f",
    ),
  );

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => const SosApp(),
    ),
  );
}

class SosApp extends StatelessWidget {
  const SosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      debugShowCheckedModeBanner: false,
      title: 'Bogo City SOS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const CitizenHomeScreen(),
    );
  }
}

// ==========================================
// 1. CITIZEN SIDE (MOBILE APP)
// ==========================================
class CitizenHomeScreen extends StatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  State<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends State<CitizenHomeScreen> {
  bool _isCountingDown = false;
  bool _isSosActive = false;
  int _countdown = 3;
  Timer? _timer;
  String _selectedEmergencyType = '';

  final List<String> commandCenterNumbers = ['0995-614-6128', '0961-780-3213'];
  final List<String> policeNumbers = ['(032)-383-9628', '0905-600-2028', '0921-236-5637'];
  final List<String> fireNumbers = ['(032)-324 3501', '0917-127-9158', '0923-724-8662'];

  Future<void> _makePhoneCall(String phoneNumber) async {
    final String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable GPS / Location Services.')),
        );
      }
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _sendSosToFirebase(String type) async {
    String coordsText = "Location Unavailable";
    Position? position = await _getCurrentLocation();

    if (position != null) {
      coordsText = "${position.latitude},${position.longitude}";
    }

    try {
      await FirebaseFirestore.instance.collection('emergency_alerts').add({
        'citizenName': 'Juan Dela Cruz',
        'citizenPhone': '0917-123-4567',
        'emergencyType': type,
        'coordinates': coordsText,
        'status': 'PENDING',
        'responderUnit': '',
        'responderCoords': '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error sending SOS: $e');
    }

    if (type == 'CRIME') {
      _makePhoneCall(policeNumbers[0]);
    } else if (type == 'FIRE') {
      _makePhoneCall(fireNumbers[0]);
    } else {
      _makePhoneCall(commandCenterNumbers[0]);
    }
  }

  void _startSosSequence(String type) {
    setState(() {
      _selectedEmergencyType = type;
      _isCountingDown = true;
      _countdown = 3;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          _timer?.cancel();
          _isCountingDown = false;
          _isSosActive = true;
          _sendSosToFirebase(_selectedEmergencyType);
        }
      });
    });
  }

  void _cancelSos() {
    _timer?.cancel();
    setState(() {
      _isCountingDown = false;
      _isSosActive = false;
      _countdown = 3;
      _selectedEmergencyType = '';
    });
  }

  // DEVELOPER CREDITS DIALOG
  void _showDeveloperInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.code, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('System Developer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.redAccent,
                child: Icon(Icons.person, size: 36, color: Colors.white),
              ),
              SizedBox(height: 12),
              Text(
                'DEVELOPED BY:',
                style: TextStyle(fontSize: 11, color: Colors.white54, letterSpacing: 1.2),
              ),
              SizedBox(height: 4),
              Text(
                'L. PURAL',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.yellowAccent),
              ),
              SizedBox(height: 12),
              Text(
                'This Emergency Response System was designed and developed for the public safety and welfare of Bogo City.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // LOGIN DIALOG WITH SUPER ADMIN PIN CHECK
  void _showAdminLoginDialog() {
    final TextEditingController pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Row(
            children: const [
              Icon(Icons.lock, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Admin Access PIN', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter Access PIN Code:', style: TextStyle(fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 12),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter PIN Code',
                ),
              ),
              const SizedBox(height: 4),
              const Text('• Standard Admin: 911911\n• Super Admin (Delete Rights): 777777', style: TextStyle(fontSize: 10, color: Colors.white38)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                final inputPin = pinController.text.trim();
                
                // STANDARD ADMIN
                if (inputPin == '911911' || inputPin == '1234') {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminDashboardScreen(isSuperAdmin: false)),
                  );
                } 
                // SUPER ADMIN (DELETE PRIVILEGES)
                else if (inputPin == '777777' || inputPin == '888888') {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminDashboardScreen(isSuperAdmin: true)),
                  );
                } 
                else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid PIN Code!')),
                  );
                }
              },
              child: const Text('LOGIN'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isSosActive ? Colors.red.shade900 : const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('BOGO CITY SOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white54),
            tooltip: 'Developer Info',
            onPressed: _showDeveloperInfoDialog,
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings, color: Colors.white30),
            tooltip: 'Admin Portal',
            onPressed: _showAdminLoginDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(
              _isSosActive
                  ? 'ALERT SENT: $_selectedEmergencyType!\nDialing responders...'
                  : _isCountingDown
                      ? 'SENDING $_selectedEmergencyType ALERT IN $_countdown...'
                      : 'SELECT EMERGENCY TYPE BELOW',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _isSosActive ? Colors.yellow : Colors.white70,
              ),
            ),
            const SizedBox(height: 15),
            if (_isCountingDown || _isSosActive) ...[
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isSosActive ? Colors.yellow : Colors.orange,
                  ),
                  child: Center(
                    child: _isCountingDown
                        ? Text('$_countdown', style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.black))
                        : Text(_selectedEmergencyType, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                onPressed: _cancelSos,
                icon: const Icon(Icons.cancel, color: Colors.red),
                label: const Text('CANCEL ALERT', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildSosTypeButton(
                      title: 'CRIME / PULIS',
                      icon: Icons.local_police,
                      color: Colors.blue.shade700,
                      onTap: () => _startSosSequence('CRIME'),
                    ),
                    const SizedBox(height: 10),
                    _buildSosTypeButton(
                      title: 'DISGRASYA / RESCUE',
                      icon: Icons.medical_services,
                      color: Colors.orange.shade800,
                      onTap: () => _startSosSequence('ACCIDENT'),
                    ),
                    const SizedBox(height: 10),
                    _buildSosTypeButton(
                      title: 'SUNOG / FIRE',
                      icon: Icons.local_fire_department,
                      color: Colors.red.shade700,
                      onTap: () => _startSosSequence('FIRE'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 15),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const Text('BOGO CITY HOTLINES', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                      const Divider(color: Colors.white24),
                      _buildHotlineCard(Icons.cell_tower, "COMMAND CENTER", commandCenterNumbers),
                      _buildHotlineCard(Icons.local_police, "POLICE STATION", policeNumbers),
                      _buildHotlineCard(Icons.local_fire_department, "FIRE STATION", fireNumbers),
                      
                      const SizedBox(height: 20),
                      // VISIBLE DEVELOPER CREDIT FOOTER
                      Center(
                        child: Column(
                          children: const [
                            Text(
                              'DEVELOPED BY: L. PURAL',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white38,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Bogo City Emergency Response System',
                              style: TextStyle(fontSize: 9, color: Colors.white24),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSosTypeButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 4,
        ),
        icon: Icon(icon, size: 28),
        label: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildHotlineCard(IconData icon, String title, List<String> numbers) {
    return Card(
      color: const Color(0xFF222222),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: Colors.redAccent),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text(numbers.join('  •  '), style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ),
    );
  }
}

// ==========================================
// 2. ADMIN SIDE (WITH SUPER ADMIN DELETE SUPPORT)
// ==========================================
class AdminDashboardScreen extends StatelessWidget {
  final bool isSuperAdmin;
  const AdminDashboardScreen({super.key, this.isSuperAdmin = false});

  Future<void> _openGoogleMapsRoute(String responderCoords, String victimCoords) async {
    if (victimCoords.isEmpty || victimCoords == "Location Unavailable") return;

    Uri googleMapsUri;
    if (responderCoords.isNotEmpty && responderCoords != "Location Unavailable") {
      googleMapsUri = Uri.parse('https://www.google.com/maps/dir/?api=1&origin=$responderCoords&destination=$victimCoords');
    } else {
      googleMapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$victimCoords');
    }

    if (await canLaunchUrl(googleMapsUri)) {
      await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openCrimeAreaMap(String victimCoords) async {
    if (victimCoords.isEmpty || victimCoords == "Location Unavailable") return;
    final Uri googleMapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$victimCoords');
    if (await canLaunchUrl(googleMapsUri)) {
      await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
    }
  }

  // CONFIRMATION DIALOG BEFORE DELETING FROM FIREBASE
  void _confirmDeleteAlert(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Record?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete this alert record from Firebase?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.delete_forever, size: 16),
            label: const Text('DELETE PERMANENTLY'),
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance.collection('emergency_alerts').doc(docId).delete();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alert record deleted permanently.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSuperAdmin ? 'SUPER ADMIN (DELETE PRIVILEGES)' : 'COMMAND CENTER MONITORING',
                style: TextStyle(
                  fontSize: 13, 
                  fontWeight: FontWeight.bold,
                  color: isSuperAdmin ? Colors.redAccent : Colors.white,
                ),
              ),
              const Text(
                'Developed by: L. PURAL',
                style: TextStyle(fontSize: 10, color: Colors.white38),
              ),
            ],
          ),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.redAccent,
            labelColor: Colors.redAccent,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'ALL ALERTS'),
              Tab(icon: Icon(Icons.local_police), text: 'POLICE'),
              Tab(icon: Icon(Icons.medical_services), text: 'RESCUE'),
              Tab(icon: Icon(Icons.local_fire_department), text: 'FIRE DEPT'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('emergency_alerts')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.red));
            }

            final allDocs = snapshot.data?.docs ?? [];

            return TabBarView(
              children: [
                _buildAlertList(context, allDocs, 'ALL'),
                _buildAlertList(context, allDocs, 'CRIME'),
                _buildAlertList(context, allDocs, 'ACCIDENT'),
                _buildAlertList(context, allDocs, 'FIRE'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAlertList(BuildContext context, List<QueryDocumentSnapshot> allDocs, String filterType) {
    final docs = filterType == 'ALL'
        ? allDocs
        : allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['emergencyType'] ?? '') == filterType;
          }).toList();

    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 70, color: Colors.green),
            const SizedBox(height: 12),
            Text(
              'No active ${filterType == 'ALL' ? '' : filterType} emergency alerts.',
              style: const TextStyle(fontSize: 15, color: Colors.white60),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final docId = docs[index].id;
        final String status = data['status'] ?? 'PENDING';
        final String type = data['emergencyType'] ?? 'GENERAL';
        final String victimCoords = data['coordinates'] ?? 'Location Unavailable';
        final String responderUnit = data['responderUnit'] ?? '';
        final String responderCoords = data['responderCoords'] ?? '';

        Color typeBgColor = Colors.red;
        IconData typeIcon = Icons.warning;
        if (type == 'CRIME') {
          typeBgColor = Colors.blue.shade700;
          typeIcon = Icons.local_police;
        } else if (type == 'ACCIDENT') {
          typeBgColor = Colors.orange.shade800;
          typeIcon = Icons.medical_services;
        } else if (type == 'FIRE') {
          typeBgColor = Colors.red.shade800;
          typeIcon = Icons.local_fire_department;
        }

        Color statusBgColor = Colors.red;
        IconData statusIcon = Icons.error_outline;
        if (status == 'RESPONDING') {
          statusBgColor = Colors.orange.shade900;
          statusIcon = Icons.local_shipping;
        } else if (status == 'RESOLVED') {
          statusBgColor = Colors.green.shade800;
          statusIcon = Icons.check_circle;
        }

        return Card(
          color: status == 'RESOLVED' 
              ? const Color(0xFF131C2E).withOpacity(0.6) 
              : const Color(0xFF1E293B),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: status == 'PENDING' 
                  ? Colors.red 
                  : status == 'RESPONDING' 
                      ? Colors.orange 
                      : Colors.green.shade600,
              width: status == 'PENDING' ? 2.5 : 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER BADGES
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: typeBgColor, borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'STATUS: $status',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // CITIZEN & INCIDENT AREA DETAILS
                Text('Citizen: ${data['citizenName'] ?? 'Unknown'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Phone: ${data['citizenPhone'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                
                // INCIDENT / CRIME AREA GPS
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.yellowAccent.shade700.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place, color: Colors.yellowAccent, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('INCIDENT / CRIME AREA GPS:', style: TextStyle(fontSize: 10, color: Colors.white60, fontWeight: FontWeight.bold)),
                            Text(victimCoords, style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'View Area in Map',
                        icon: const Icon(Icons.open_in_new, color: Colors.yellowAccent, size: 18),
                        onPressed: () => _openCrimeAreaMap(victimCoords),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 20),

                // LIVE TRACKER ROUTE BOX (DISPLAYS ONLY IF STATUS == 'RESPONDING')
                if (status == 'RESPONDING') ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade700, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.navigation, color: Colors.orangeAccent, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'RESPONDER: ${responderUnit.isEmpty ? 'Unit Assigned' : responderUnit}', 
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Responder GPS: ${responderCoords.isEmpty ? "Updating..." : responderCoords}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(height: 8),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade800,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.map, size: 16),
                            label: const Text('TRACK LIVE ROUTE (GOOGLE MAPS)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => _openGoogleMapsRoute(responderCoords, victimCoords),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ACTION BUTTONS
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (status == 'PENDING')
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.black),
                          icon: const Icon(Icons.local_shipping, size: 14),
                          label: const Text('DISPATCH RESPONDER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            Position? currentPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                            String rCoords = currentPos != null ? "${currentPos.latitude},${currentPos.longitude}" : "11.0520,124.0050";

                            String unitName = type == 'CRIME'
                                ? 'PATROL CAR 01'
                                : type == 'FIRE'
                                    ? 'FIRE ENGINE 01'
                                    : 'RESCUE AMBULANCE 01';

                            FirebaseFirestore.instance.collection('emergency_alerts').doc(docId).update({
                              'status': 'RESPONDING',
                              'responderUnit': unitName,
                              'responderCoords': rCoords,
                            });
                          },
                        ),

                      if (status != 'RESOLVED')
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text('MARK AS RESOLVED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            FirebaseFirestore.instance.collection('emergency_alerts').doc(docId).update({
                              'status': 'RESOLVED',
                            });
                          },
                        ),

                      // SUPER ADMIN DELETE BUTTON (VISIBLE ONLY TO SUPER ADMIN)
                      if (isSuperAdmin)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, foregroundColor: Colors.white),
                          icon: const Icon(Icons.delete_forever, size: 14),
                          label: const Text('DELETE RECORD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _confirmDeleteAlert(context, docId),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}