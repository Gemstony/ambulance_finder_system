import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/request_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import '../../utils/colors.dart';

class RequestAmbulance extends StatefulWidget {
  const RequestAmbulance({Key? key}) : super(key: key);

  @override
  State<RequestAmbulance> createState() => _RequestAmbulanceState();
}

class _RequestAmbulanceState extends State<RequestAmbulance> {
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();
  
  String _selectedEmergencyType = 'accident';
  String _selectedSeverity = 'high';
  bool _isLoading = false;
  
  final List<Map<String, dynamic>> _emergencyTypes = [
    {'value': 'accident', 'label': '🚗 Accident', 'icon': Icons.car_crash},
    {'value': 'heart_attack', 'label': '❤️ Heart Attack', 'icon': Icons.favorite},
    {'value': 'stroke', 'label': '🧠 Stroke', 'icon': Icons.psychology},
    {'value': 'pregnancy', 'label': '👶 Pregnancy', 'icon': Icons.child_care},
    {'value': 'burn', 'label': '🔥 Burns', 'icon': Icons.local_fire_department},
    {'value': 'fall', 'label': '🦵 Fall Injury', 'icon': Icons.accessibility_new},
    {'value': 'other', 'label': '📝 Other', 'icon': Icons.medical_services},
  ];
  
  final List<Map<String, dynamic>> _severityLevels = [
    {'value': 'low', 'label': 'Low', 'color': Colors.green},
    {'value': 'medium', 'label': 'Medium', 'color': Colors.orange},
    {'value': 'high', 'label': 'High', 'color': Colors.deepOrange},
    {'value': 'critical', 'label': 'Critical', 'color': Colors.red},
  ];

  Future<void> _submitRequest() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final requestProvider = Provider.of<RequestProvider>(context, listen: false);
    
    final userData = authProvider.currentUserData;
    final location = locationProvider.currentLocation;
    
    if (userData == null || location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get your location. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    final requestId = await requestProvider.createEmergencyRequest(
      patientId: userData.uid,
      patientName: userData.fullName,
      patientPhone: userData.phone,
      latitude: location.latitude,
      longitude: location.longitude,
      notes: _notesController.text.isEmpty ? _selectedEmergencyType : _notesController.text,
    );
    
    setState(() => _isLoading = false);
    
    if (requestId != null && mounted) {
      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Request Sent!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('An ambulance has been dispatched to your location.'),
              SizedBox(height: 8),
              Text('You can track the ambulance in real-time.'),
            ],
          ),
          actions: [
            CustomButton(
              text: 'Track Ambulance',
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to home
                // Navigate to tracking screen
              },
            ),
          ],
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(requestProvider.errorMessage ?? 'Failed to submit request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Ambulance'),
        backgroundColor: AppColors.darkRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.veryLightGreen, AppColors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📍 Your Location',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: AppColors.darkRed, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              locationProvider.hasLocation
                                  ? locationProvider.formattedCurrentLocation
                                  : 'Getting location...',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ambulance will be sent to this address',
                        style: TextStyle(fontSize: 12, color: AppColors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Emergency Type
              const Text(
                '🚨 Type of Emergency',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                height: 120,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _emergencyTypes.length,
                  itemBuilder: (context, index) {
                    final type = _emergencyTypes[index];
                    final isSelected = _selectedEmergencyType == type['value'];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedEmergencyType = type['value']),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.lightRed : Colors.white,
                          border: Border.all(
                            color: isSelected ? AppColors.darkRed : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              type['icon'],
                              color: isSelected ? AppColors.darkRed : AppColors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              type['label'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppColors.darkRed : AppColors.darkGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Severity Level
              const Text(
                '⚠️ Severity Level',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: _severityLevels.map((level) {
                  final isSelected = _selectedSeverity == level['value'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSeverity = level['value']),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? level['color'] : Colors.white,
                          border: Border.all(color: level['color'], width: isSelected ? 2 : 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            level['label'],
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : level['color'],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 20),
              
              // Symptoms
              CustomTextField(
                controller: _symptomsController,
                label: 'Symptoms',
                hint: 'Describe symptoms (e.g., chest pain, difficulty breathing)',
                prefixIcon: Icons.sick,
              ),
              
              const SizedBox(height: 16),
              
              // Additional Notes
              CustomTextField(
                controller: _notesController,
                label: 'Additional Notes',
                hint: 'Any other important information',
                prefixIcon: Icons.note_add,
              ),
              
              const SizedBox(height: 24),
              
              // Warning Message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightRed.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightRed),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: AppColors.darkRed),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Only request an ambulance for genuine emergencies. False alarms will be reported.',
                        style: TextStyle(fontSize: 12, color: AppColors.darkRed),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Submit Button
              CustomButton(
                text: '🚑 SEND EMERGENCY REQUEST',
                onPressed: _submitRequest,
                isLoading: _isLoading,
                isEmergency: true,
                height: 55,
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}