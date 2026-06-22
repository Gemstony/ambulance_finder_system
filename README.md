🚑 Real-Time Ambulance Finder System








A cross-platform mobile application that connects patients in need of emergency medical assistance with the nearest available ambulance in real-time.

The system leverages Flutter, Firebase, OpenStreetMap, and OSRM Routing to provide fast emergency response, live ambulance tracking, and efficient dispatch management.

📖 Table of Contents
Overview
Problem Statement
Key Features
Technology Stack
System Architecture
Screenshots
Installation & Setup
Firebase Configuration
Usage Guide
Project Structure
Contributing
License
Acknowledgements
🚨 Overview

The Real-Time Ambulance Finder System is designed to improve emergency healthcare response by replacing traditional phone-based ambulance requests with a digital, location-aware platform.

The application enables:

Instant ambulance requests.
Automatic patient location detection.
Real-time ambulance tracking.
Smart driver assignment.
Live driver monitoring.
Efficient dispatch management.
👥 User Roles
Role	Responsibilities
Patient	Request ambulances, track arrival, and confirm trip completion
Driver	Accept requests, navigate to patients, and update trip status
Admin	Manage drivers, monitor operations, and reassign requests
⚠️ Problem Statement

In many regions, emergency medical services still rely heavily on phone calls and manual dispatching, leading to:

Delayed response times.
Inaccurate location descriptions.
Communication challenges.
Lack of transparency for patients.
Inefficient ambulance allocation.

This system addresses these challenges through:

✅ Real-time location sharing

✅ Automated ambulance dispatching

✅ Live ambulance tracking

✅ Centralized emergency management

✨ Key Features
👤 Patient Features
One-tap ambulance request.
Automatic GPS location detection.
Emergency type selection.
Severity level selection.
Real-time ambulance tracking.
Driver information display.
Distance and ETA monitoring.
Request cancellation.
Request history management.
🚗 Driver Features
Online/Offline availability status.
Receive nearby emergency requests.
Accept or reject requests.
Turn-by-turn navigation.
Patient location tracking.
Arrival confirmation.
Trip history management.
👨‍💼 Admin Features
Driver management.
Driver activation/deactivation.
Online status monitoring.
Manual request assignment.
Reassignment of rejected requests.
Live driver location monitoring.
Emergency request tracking.
Operational dashboard.
🗺️ Mapping & Navigation
OpenStreetMap
Free map tiles.
No API key required.
Reliable global coverage.
OSRM Routing
Road-based navigation.
Accurate distance calculation.
ETA estimation.
Route optimization.
Fallback System

If OSRM becomes unavailable, the system automatically uses straight-line distance calculations.

⚡ Real-Time Backend Features
Firebase Firestore
Real-time database updates.
Live request synchronization.
Driver location updates.
Firebase Authentication
Secure Email/Password login.
Role-based access control.
Notifications
Local notifications.
Optional Firebase Cloud Messaging (FCM).
🧰 Technology Stack
Category	Technology
Frontend	Flutter (Dart)
Backend	Firebase Firestore
Authentication	Firebase Auth
Mapping	OpenStreetMap
Routing	OSRM
Location Services	Geolocator
State Management	Provider
Notifications	flutter_local_notifications
Networking	HTTP Package
Version Control	Git & GitHub
🧩 System Architecture
┌──────────────────────────────────────────────┐
│                 Mobile App                   │
├──────────────────────────────────────────────┤
│  Patient  │  Driver  │  Admin Dashboard      │
└──────────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────┐
│             Flutter Providers                │
│ Auth • Location • Requests • Tracking        │
└──────────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────┐
│                 Firebase                     │
├──────────────────────────────────────────────┤
│ Firestore │ Authentication │ Notifications   │
└──────────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────┐
│            External Services                 │
├──────────────────────────────────────────────┤
│ OpenStreetMap │ OSRM Routing Engine          │
└──────────────────────────────────────────────┘
📱 Screenshots

Replace the placeholders below with actual screenshots from your application.

Patient Home	Request Ambulance	Tracking Map

	
	
Driver Home	Navigation Screen	Admin Dashboard

	
	
🚀 Installation & Setup
Prerequisites

Before getting started, ensure you have:

Flutter SDK (v3.16+)
Android Studio or VS Code
Android/iOS Emulator or Physical Device
Firebase Project
Clone Repository
git clone https://github.com/your-username/ambulance-finder-system.git

cd ambulance-finder-system
Install Dependencies
flutter pub get
Configure Firebase
Step 1: Create Firebase Project

Enable:

Authentication (Email/Password)
Cloud Firestore
Step 2: Download Firebase Configuration Files
Android
android/app/google-services.json
iOS
ios/Runner/GoogleService-Info.plist
Step 3: Generate Firebase Options
flutterfire configure

This generates:

lib/firebase_options.dart
Configure Firestore Indexes

The application uses complex Firestore queries.

If Firebase requests an index:

Open the generated link.
Create the index.
Wait for indexing to complete.
Run Application
flutter run

No API keys are required for OpenStreetMap or OSRM.

🔐 Firebase Configuration
Firestore Security Rules
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    // Add project security rules here

  }
}
Firestore Data Model
Users Collection
users/{uid}

Stores:

Role
Name
Phone
Online Status
Active Status
Requests Collection
requests/{requestId}

Stores:

Emergency Type
Patient Location
Driver Assignment
Status
Timestamps
Driver Locations
drivers_location/{driverId}

Stores:

Latitude
Longitude
Last Update Time
Rejected Drivers
requests/{requestId}/rejected_drivers/{driverId}

Tracks drivers who rejected specific requests.

🗺️ Usage Guide
Patient Workflow
Register/Login.
Tap Request Ambulance Now.
Select emergency type and severity.
Submit request.
Track ambulance in real-time.
Confirm arrival after pickup.
Driver Workflow
Login.
Go Online.
Receive incoming requests.
Accept request.
Navigate to patient.
Mark arrival.
Complete trip.
Admin Workflow
Drivers Tab
View all drivers.
Activate/Deactivate drivers.
Toggle online status.
Pending Requests Tab
View pending requests.
Assign drivers manually.
Rejected Requests Tab
Reassign rejected requests.
Requests History Tab
View all emergency requests.
📁 Project Structure
lib/
│
├── models/
│   ├── user_model.dart
│   ├── request_model.dart
│
├── providers/
│   ├── auth_provider.dart
│   ├── request_provider.dart
│
├── screens/
│   ├── auth/
│   ├── patient/
│   ├── driver/
│   └── admin/
│
├── services/
│   ├── firestore_service.dart
│   ├── location_service.dart
│   ├── osrm_service.dart
│
├── utils/
│
├── widgets/
│
└── main.dart
🤝 Contributing

Contributions are welcome.

Steps
# Fork Repository

# Create Feature Branch
git checkout -b feature/your-feature

# Commit Changes
git commit -m "Add new feature"

# Push Changes
git push origin feature/your-feature

Then open a Pull Request.

📄 License

This project is licensed under the MIT License.

See the LICENSE file for additional details.

🙏 Acknowledgements

Special thanks to:

OpenStreetMap Community
OSRM Project
Flutter Team
Firebase Team
Contributors and Testers