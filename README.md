# 💸 Bills Reimbursement

A full-stack bills reimbursement app where users can **submit and track bill reimbursement requests**. Built with a **Flutter** frontend and a **Spring Boot** REST backend backed by **MySQL**.

---

## 🏗️ Project Structure

```
bills_reimbursement/
├── flutter_application/    # Cross-platform frontend (Dart/Flutter)
└── spring_backend/         # REST API backend (Java/Spring Boot + MySQL)
```

---

## ✨ Features

- 📋 Submit bill reimbursement requests
- 📊 Track status and history of submissions
- 📱 Native Android app + browser-based web app
- 🔗 RESTful API backend powered by Spring Boot
- 🗄️ Persistent storage with MySQL

---

## 🛠️ Tech Stack

| Layer      | Technology              |
|------------|-------------------------|
| Mobile App | Flutter (Dart)          |
| Backend    | Java, Spring Boot       |
| Database   | MySQL                   |

---

## 📋 Prerequisites

### Flutter Frontend
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (>= 3.x recommended)
- Dart SDK (bundled with Flutter)
- Android Studio (for Android emulation/build)
- A browser (for web)

### Spring Backend
- Java 21+
- Maven
- MySQL server running locally or remotely

---

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/aryan-chanana/bills_reimbursement.git
cd bills_reimbursement
```

---

### 2. Set Up the Database

Create a MySQL database and update the credentials in:

```
spring_backend/src/main/resources/application.properties
```

```properties
spring.datasource.url=jdbc:mysql://localhost:3306/bills_reimbursement
spring.datasource.username=your_username
spring.datasource.password=your_password
spring.jpa.hibernate.ddl-auto=update
```

---

### 3. Run the Spring Boot Backend

```bash
cd spring_backend
./mvnw spring-boot:run
```

The API will start on `http://localhost:8080` by default.

---

### 4. Run the Flutter Frontend

First, set the backend base URL in the Flutter app. By default it points to `localhost:8080`.
If the backend is running on a **different machine or IP**, update the base URL before running:

```dart
// flutter_application/lib/services/api_service.dart
static const String baseUrl = "http://<YOUR_SERVER_IP>:8080";
```

> ⚠️ If you skip this step and the backend is not on the same machine, the app will fail to connect.

**Run on Android:**
```bash
cd flutter_application
flutter pub get
flutter run
```

**Run on Web (browser):**
```bash
flutter run -d chrome
```

**Build a release APK:**
```bash
flutter build apk --release (specify API_BASE_URL for telling application the backend destination)
```

---

## 📱 Platform Support

| Platform | Support |
|----------|---------|
| Android  | ✅ Native app |
| Web      | ✅ Browser |
| iOS      | ⚠️ Not supported as a native app — use the web version in Safari and [add to Home Screen](https://support.apple.com/en-us/HT205039) as a PWA |

---

## 📁 Key Directories

```
flutter_application/
├── assets/
│   ├── icon/             # App icons
│   ├── images/           # App images
├── lib/
│   ├── main.dart         # App entry point
│   ├── screens/          # UI screens
│   ├── models/           # Data models
│   └── services/         # Service layer
└── pubspec.yaml          # Flutter dependencies

spring_backend/
├── uploads/              # All bill images uploaded by users
├── src/main/
│   ├── java/             # Controllers, services, repositories, models
│   └── resources/
│       └── application.properties   # DB & server config
└── pom.xml               # Maven dependencies
```

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -m 'Add your feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a Pull Request


## 👤 Author

**Aryan Chanana**
- GitHub: [@aryan-chanana](https://github.com/aryan-chanana)
