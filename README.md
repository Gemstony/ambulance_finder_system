🚑 Real-Time Ambulance Finder System
https://img.shields.io/badge/Flutter-3.16+-02569B?style=flat&logo=flutter&logoColor=white
https://img.shields.io/badge/Firebase-10.7+-FFCA28?style=flat&logo=firebase&logoColor=black
https://img.shields.io/badge/OpenStreetMap-7EBE3D?style=flat&logo=openstreetmap&logoColor=white
https://img.shields.io/badge/License-MIT-green.svg

A cross‑platform mobile application that connects patients in need of emergency care with the nearest available ambulance in real time.

📖 Table of Contents
Overview

Problem Statement

Features

Tech Stack

Architecture

Screenshots

Installation & Setup

Firebase Configuration

Usage Guide

Project Structure

Contributing

License

Acknowledgements

🚨 Overview
Real-Time Ambulance Finder System is a complete mobile solution designed to reduce emergency response times in Tanzania. It replaces manual phone‑based requests with a digital, location‑aware platform that instantly dispatches the nearest ambulance.

The system consists of three user roles:

Patients – request an ambulance, track arrival in real time, and confirm when the ambulance arrives.

Drivers – accept/reject requests, navigate to the patient using turn‑by‑turn road directions, and update trip status.

Admins – manage drivers, monitor live locations, and reassign rejected requests.

⚠️ Problem Statement
In many regions, emergency medical services rely heavily on phone calls, leading to:

Delayed response due to inaccurate location descriptions.

Miscommunication between patients, dispatchers, and drivers.

No transparency – patients cannot track ambulance arrival.

Manual dispatching that is error‑prone and slow.

This application addresses these pain points by automating location sharing, dispatching, and tracking, while providing a clear and intuitive interface for all users.

✨ Features
👤 Patient
Request an ambulance with one tap (auto‑detects location).

Choose emergency type (accident, heart attack, stroke, etc.) and severity.

Real‑time tracking of the dispatched ambulance on a map.

View driver name, phone number, distance, and ETA.

Cancel active request.

View request history with status.

🚗 Driver
Toggle online/offline status.

Receive live incoming requests (filtered to avoid repeated rejections).

Accept or reject requests.

Navigate to patient using road‑based directions (OSRM routing).

Mark arrival; patient then confirms.

Trip history – view completed trips with patient details.

👨‍💼 Admin
Full driver management – view online/offline status, activate/deactivate, toggle online.

View all pending requests and manually assign a driver.

See requests that drivers have rejected and reassign them.

Monitor active drivers’ live locations.

View all requests with current status.

🗺️ Mapping & Navigation
OpenStreetMap powered map tiles (free, no API key).

OSRM (Open Source Routing Machine) for road‑based driving directions and accurate distance/ETA.

Straight‑line fallback when OSRM is unavailable.

⚙️ Backend & Real‑Time
Firebase Firestore as primary database – real‑time updates.

Firebase Authentication for secure login (email/password).

Cloud Functions (optional) for push notifications – can be replaced with local notifications.

🧰 Tech Stack
Category	Technology
Frontend	Flutter (Dart) – cross‑platform mobile app
Backend	Firebase Firestore, Firebase Auth
Mapping	OpenStreetMap (tiles) + OSRM (routing)
Location	Geolocator plugin
State Management	Provider
Notifications	flutter_local_notifications (FCM optional)
HTTP Client	http package for OSRM API calls
Version Control	Git & GitHub
🧩 Architecture
text
┌─────────────────────────────────────────────────────────────┐
│                         Mobile App                         │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐          │
│  │  Patient   │  │  Driver    │  │  Admin     │          │
│  │   Screen   │  │   Screen   │  │   Panel    │          │
│  └────────────┘  └────────────┘  └────────────┘          │
│       │                │                │                  │
│       ▼                ▼                ▼                  │
│  ┌─────────────────────────────────────────────────┐      │
│  │             Flutter Providers                  │      │
│  │  (Auth, Location, Request, etc.)              │      │
│  └─────────────────────────────────────────────────┘      │
│       │                │                │                  │
└───────┼────────────────┼────────────────┼──────────────────┘
        │                │                │
        ▼                ▼                ▼
┌─────────────────────────────────────────────────────────────┐
│                         Firebase                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐│
│  │  Firestore  │  │   Auth      │  │  (optional FCM)     ││
│  │  (Requests, │  │  (Email/    │  │  for push notif.    ││
│  │   Users,    │  │   Password) │  └─────────────────────┘│
│  │   Locations)│  └─────────────┘                         │
│  └─────────────┘                                          │
└─────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│                    External Services                        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  OpenStreetMap Tile Server (free tiles)            │   │
│  │  OSRM Public API (http://router.project-osrm.org) │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
📱 Screenshots
Placeholder – add actual images from your app here.

Patient Home	Request Ambulance	Tracking Map
https://screenshots/patient_home.png	https://screenshots/request.png	https://screenshots/tracking.png
Driver Home	Navigation Screen	Admin Panel
https://screenshots/driver_home.png	https://screenshots/navigation.png	https://screenshots/admin.png
🚀 Installation & Setup
Prerequisites
Flutter SDK (version 3.16 or later)

Android Studio or VS Code with Flutter extensions

An Android or iOS device/emulator

A Firebase project (free tier works)

Steps
Clone the repository

bash
git clone https://github.com/your-username/ambulance-finder-system.git
cd ambulance-finder-system
Install dependencies

bash
flutter pub get
Configure Firebase

Create a Firebase project and enable Authentication (Email/Password) and Firestore.

Download the google-services.json (Android) and/or GoogleService-Info.plist (iOS) and place them in the correct folders.

Add your Firebase config to lib/firebase_options.dart (using the flutterfire CLI or manually).

Enable required Firestore indexes

The app uses queries with orderBy and where clauses (e.g., pending requests by timestamp).

Run the app; if you see an error about a missing index, click the link in the console to create it automatically in Firebase Console.

Run the app

bash
flutter run
Note: No API keys are required for OpenStreetMap tiles or the OSRM routing service – they are free to use.

🔐 Firebase Configuration
Firestore Security Rules
To protect your data, set up the following rules (adjust as needed). See firestore.rules in the repository.

javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ... rules as provided in the project
  }
}
Firestore Data Model (Simplified)
users/{uid} – user profile (role, name, phone, isOnline, isActive, etc.)

requests/{requestId} – emergency requests with status, location, driver assignment, timestamps.

drivers_location/{driverId} – real‑time driver location (lat/lng, lastUpdate).

requests/{requestId}/rejected_drivers/{driverId} – tracks which drivers rejected a request.

🗺️ Usage Guide
For Patients
Open the app and log in (or sign up as a patient).

On the home screen, tap “REQUEST AMBULANCE NOW”.

Fill in emergency type, severity, and optional notes.

Submit – your request is sent to all online drivers.

Wait for a driver to accept; then track the ambulance on the map.

When the ambulance arrives, tap “Confirm Ambulance Arrival” to complete the trip.

For Drivers
Log in as a driver.

Toggle your Online status to start receiving requests.

Incoming requests appear on the home screen and in the notification badge.

Accept a request – you’re redirected to the navigation screen.

The map shows the patient’s location; follow the route.

When you arrive, tap “Arrived at Patient”. The patient will confirm.

After confirmation, the trip is marked as completed.

For Admins
Log in as an admin.

The admin panel shows tabs:

Drivers – view all drivers, toggle online/offline, activate/deactivate.

Pending – see all pending requests and assign a driver manually.

Rejected – requests rejected by drivers; reassign them.

All Requests – complete history.

Admin can also see live driver locations on a map.

📁 Project Structure
text
lib/
├── models/                 # Data models (User, Request, Ambulance, etc.)
├── providers/              # State management (Auth, Location, Request)
├── screens/
│   ├── auth/               # Login / Register screens
│   ├── patient/            # Patient Home, Request, Tracking
│   ├── driver/             # Driver Home, Incoming Requests, Navigation
│   └── admin/              # Admin dashboard (LiveTracking)
├── services/               # Backend services (Firestore, GPS, OSRM, Map)
├── utils/                  # Constants, colors, helpers
├── widgets/                # Reusable UI components (buttons, text fields)
└── main.dart               # App entry point
🤝 Contributing
Contributions are welcome! To contribute:

Fork the repository.

Create a feature branch: git checkout -b feature/your-feature.

Commit your changes: git commit -m 'Add some feature'.

Push to the branch: git push origin feature/your-feature.

Open a Pull Request.

Please ensure your code follows the existing style and includes appropriate comments.

📄 License
This project is licensed under the MIT License – see the LICENSE file for details.

🙏 Acknowledgements
OpenStreetMap for providing free map tiles.

OSRM for the open‑source routing engine.

Flutter and Firebase teams for their excellent tools.

All contributors and testers who helped shape this project.