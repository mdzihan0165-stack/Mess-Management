# 📱 Smart Mess Management System

A comprehensive, user-friendly mobile and web application built with **Flutter** and **Google Firebase** to simplify daily mess operations, meal tracking, expense management, member coordination, and automated PDF reporting.

---

## 🚀 Features

* **Real-time Meal Tracking:** Keep track of daily meals (Lunch & Dinner) for every member seamlessly.
* **Bazaar & Expense Management (with Date & Time):** Accurately record daily market costs with specific date, time, and purchased item notes.
* **Bazaar History & Logs:** View complete chronological logs of all bazaar transactions per member and across the whole mess.
* **Dynamic Meal Rate Calculation:** Automatically computes the live meal rate based on total mess costs and total meals:
  $$\text{Meal Rate} = \frac{\text{Total Mess Bazaar}}{\text{Total Mess Meals}}$$
* **Automated PDF Report Generation:**
  - **Month-End PDF Report:** Download an official A4 statement when closing the month.
  - **Day-by-Day Meal Matrix:** Detailed tabular breakdown showing which members had meals on which specific dates.
  - **Bazaar Transaction Log:** Full list of all market expenses with exact dates and times.
  - **Live Statement PDF:** Download running statements at any point during the month.
* **Manager Transfer & Month Closing:** Easily assign or transfer manager roles among members while archiving past monthly statements.
* **In-App Notice & Chat System:** Stay updated with important announcements and communicate with mess members in real-time.
* **Authentication & Security:** Secure login system using Mess Code and Email to protect user and financial data.

---

## 🛠️ Tech Stack

* **Framework:** Flutter (Dart 3)
* **Backend / Database:** Google Firebase (Cloud Firestore, Firebase Core)
* **Reporting & PDF:** `package:pdf`, `package:printing`
* **Local Storage / Session:** `shared_preferences`

---

## ⚙️ Getting Started (For Developers)

To run this project locally on your machine, follow these steps:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/mdzihan0165-stack/Mess-Management.git
   cd Mess-Management
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on Chrome (Web):**
   ```bash
   flutter run -d chrome
   ```

4. **Build for Web:**
   ```bash
   flutter build web
   ```
