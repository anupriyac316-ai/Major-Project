# College Management System — Admin Panel 🖥️
A web-based admin panel for managing the complete academic and administrative 
operations of the institution.

> *Empowering Women Through Education*
> — Christopher Arts & Science College For Women

---

## 🌐 About
A centralized web dashboard exclusively for the institution's administrator 
to manage students, staff, timetables, fees, and all academic data in real time.

---

## ✨ Features

### 👨‍💼 Admin Dashboard
- Overview of total students, staff, courses & departments
- Quick access to enrolled students and active staff
- Real-time data sync with Firebase

### 👨‍🎓 Student Management
- Add students individually or via bulk Excel import
- Auto-generate and distribute student login credentials
- Update or delete student records
- Promote students to next academic year

### 👨‍🏫 Staff Management
- Add staff individually or via bulk Excel import
- Assign login credentials to staff members
- Update or remove staff records

### 📅 Timetable Management
- Create and publish timetable templates
- Manage day order (manual & automated rotation)
- Templates used by HOD for department scheduling

### 💰 Fee Management
- Create customized fee structures per semester
- Track payment status (paid / unpaid) per student
- Set fee deadlines
- Send automated fee reminders to students

### 📢 Notification Management
- Broadcast announcements and circulars
- Send updates to all students and staff simultaneously

### 🏫 Course & Department Management
- Add and configure academic courses
- Manage associated departments
- Forms the backbone of all academic data

### 📊 Attendance Monitoring
- Real-time institution-wide attendance dashboard
- View daily attendance submitted by faculty
- Identify absenteeism patterns instantly

### 👤 Profile Management
- Update personal and institutional profile
- Secure admin account reset / handover feature

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Frontend | HTML / CSS / JavaScript |
| Backend | Python |
| Database | Firebase Firestore |
| Authentication | Firebase Auth |
| Storage | Firebase Storage |
| Notifications | Firebase Cloud Messaging |
| Browser | Microsoft Edge / Chrome |
| Platform | Web |

---

## 📂 Project Structure
admin-panel/
├── public/
│   ├── index.html           # Landing & login page
│   ├── dashboard.html       # Admin dashboard
│   ├── students.html        # Student management
│   ├── staff.html           # Staff management
│   ├── timetable.html       # Timetable management
│   ├── fees.html            # Fee management
│   └── notifications.html   # Announcements
├── src/
│   ├── auth/                # Login & authentication
│   ├── firebase/            # Firebase config & services
│   └── modules/             # Feature modules
├── firebase.json
└── README.md

---

## ⚙️ Installation & Setup

### Prerequisites
- Node.js installed
- Firebase CLI installed
- Firebase project configured
- Modern web browser

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/anupriyac316-ai/<your-web-repo-name>.git

# 2. Navigate to project folder
cd <your-web-repo-name>

# 3. Install Firebase CLI (if not installed)
npm install -g firebase-tools

# 4. Login to Firebase
firebase login

# 5. Run locally
firebase serve

# 6. Deploy to Firebase Hosting
firebase deploy
```

---

## 💻 System Requirements

- OS: Windows 10/11
- RAM: 8 GB
- Processor: Intel i3 or above
- Browser: Microsoft Edge / Chrome
- Internet connection (required for Firebase)

---

## 🔮 Future Enhancements
- Advanced analytics & academic reports
- AI-based attendance pattern detection
- Automated bulk fee reminder scheduling
- Role-based multi-admin support
- Export reports as PDF / Excel
- Dark / Light theme toggle

---

## 🏫 College Details

- **Institution:** Christopher Arts & Science College For Women
- **Project Type:** Major Project
- **Academic Year:** 2024–25

---

## 📄 License
This project is developed for academic purposes.
© 2025 College Management System Team. All rights reserved.
