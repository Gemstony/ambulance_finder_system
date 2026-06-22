# 🚑 Real-Time Ambulance Finder System

A cross-platform Flutter application that connects patients in need of emergency medical assistance with the nearest available ambulance in real-time.

The system uses Flutter, Firebase, OpenStreetMap, and OSRM routing to deliver fast emergency requests, live ambulance tracking, and efficient dispatch management.

---

## 📖 Table of Contents

1. [Overview](#overview)
2. [Problem Statement](#problem-statement)
3. [Features](#features)
4. [Technology Stack](#technology-stack)
5. [Architecture](#architecture)
6. [Screenshots](#screenshots)
7. [Installation](#installation)
8. [Firebase Configuration](#firebase-configuration)
9. [Usage Guide](#usage-guide)
10. [Project Structure](#project-structure)
11. [Contributing](#contributing)
12. [License](#license)
13. [Acknowledgements](#acknowledgements)

---

## 🚨 Overview

The Real-Time Ambulance Finder System improves emergency healthcare response by replacing manual phone dispatch with a location-aware digital platform.

It supports three user roles:

- **Patient**: request ambulances, share location, and track arrival.
- **Driver**: accept requests, navigate to patients, and update trip status.
- **Admin**: monitor operations, manage drivers, and assign requests.

---

## ⚠️ Problem Statement

Traditional ambulance services often depend on phone-based dispatch, which can cause:

- delayed response times
- inaccurate patient location information
- poor communication between stakeholders
- low transparency for patients and families
- inefficient ambulance allocation

This app addresses these issues with:

- real-time location sharing
- automated driver assignment
- live ambulance tracking
- centralized emergency management

---

## ✨ Features

### Patient Features

- One-tap ambulance request
- Automatic GPS location detection
- Emergency type selection
- Severity level selection
- Real-time ambulance tracking
- Driver information display
- Distance and ETA updates
- Request cancellation
- Request history review

### Driver Features

- Online / Offline availability
- Receive nearby emergency requests
- Accept or reject requests
- Navigate to patient location
- Track patient pickup and drop-off
- Arrival confirmation
- Trip history

### Admin Features

- Driver management
- Activate / deactivate drivers
- Monitor online status
- Manual request assignment
- Reassign rejected requests
- View active and pending requests
- Live driver location monitoring

### Backend & Navigation

- Firebase Firestore for real-time updates
- Firebase Authentication for secure sign-in
- OpenStreetMap for map display
- OSRM routing for navigation and ETA
- Local notifications for updates
- HTTP package for network requests

---

## 🧰 Technology Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase Firestore
- **Authentication**: Firebase Auth
- **Mapping**: OpenStreetMap
- **Routing**: OSRM / fallback straight-line distance
- **Location**: Geolocator
- **State Management**: Provider
- **Notifications**: flutter_local_notifications
- **Networking**: http
- **Version Control**: Git & GitHub

Dependencies included in this project:

- `cupertino_icons`
- `excel`
- `share_plus`
- `path_provider`
- `flutter_map`
- `latlong2`
- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_database`
- `firebase_messaging`
- `google_maps_flutter`
- `geolocator`
- `geocoding`
- `flutter_polyline_points`
- `provider`
- `url_launcher`
- `http`
- `flutter_local_notifications`

---

## 🧩 Architecture

The app is built as a Flutter mobile application with separate user flows for patients, drivers, and admins.

- Mobile App UI uses Flutter widgets and screens.
- Providers manage auth, location, requests, and tracking state.
- Firebase handles authentication, Firestore data, and real-time updates.
- External services provide map tiles, routing, and navigation.

---

## 📱 Screenshots

> Replace these placeholders with real screenshots from your app.

| Patient Home | Request Ambulance | Tracking Map |
| --- | --- | --- |
| ![Patient Home](screenshots/patient_home.png) | ![Request Ambulance](screenshots/request_ambulance.png) | ![Tracking Map](screenshots/tracking_map.png) |

| Driver Home | Navigation Screen | Admin Dashboard |
| --- | --- | --- |
| ![Driver Home](screenshots/driver_home.png) | ![Navigation Screen](screenshots/navigation_screen.png) | ![Admin Dashboard](screenshots/admin_dashboard.png) |

---

## 🚀 Installation

### Prerequisites

- Flutter SDK
- Android Studio or VS Code
- Android/iOS emulator or device
- Firebase project

### Setup

```bash
git clone https://github.com/your-username/ambulance-finder-system.git
cd ambulance-finder-system
flutter pub get
```

---

## 🔐 Firebase Configuration

### 1. Create a Firebase Project

Enable the following services:

- Authentication (Email/Password)
- Cloud Firestore
- Firebase Database (if used)
- Firebase Messaging (optional)

### 2. Add Firebase Configuration Files

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

### 3. Generate Firebase Options

```bash
flutterfire configure
```

This generates `lib/firebase_options.dart`.

### 4. Firestore Indexes

If Firebase requires indexes for your queries, follow the generated link and create the necessary indexes.

---

## 🗺️ Usage Guide

### Patient Flow

1. Register or log in.
2. Open the request screen.
3. Select emergency type and severity.
4. Submit the request.
5. Track the ambulance in real-time.
6. Confirm pickup and completion.

### Driver Flow

1. Log in.
2. Set availability to online.
3. Accept incoming emergency requests.
4. Navigate to the patient's location.
5. Mark arrival and complete the trip.

### Admin Flow

1. Open the admin dashboard.
2. View drivers and assign requests.
3. Activate or deactivate drivers.
4. Reassign rejected or pending requests.
5. Monitor ongoing operations.

---

## 📁 Project Structure

```
lib/
├── models/
│   ├── user_model.dart
│   ├── request_model.dart
├── providers/
│   ├── auth_provider.dart
│   ├── request_provider.dart
├── screens/
│   ├── auth/
│   ├── patient/
│   ├── driver/
│   └── admin/
├── services/
│   ├── firestore_service.dart
│   ├── location_service.dart
│   ├── osrm_service.dart
├── utils/
├── widgets/
└── main.dart
```

---

## 🤝 Contributing

Contributions are welcome! Please fork the repository, create a feature branch, and submit a pull request.

1. Fork the repo
2. Create a branch: `git checkout -b feature/your-feature`
3. Commit your changes
4. Push to your fork
5. Open a pull request

---

## 📄 License

This project is currently private and not published to `pub.dev`.

---

## 🙏 Acknowledgements

- Flutter team
- Firebase
- OpenStreetMap
- OSRM
- Provider package
- flutter_local_notifications
