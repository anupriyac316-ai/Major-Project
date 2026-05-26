from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import credentials, messaging, firestore

app = Flask(__name__)

# ── Firebase init ─────────────────────────────────────────────────
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# ─────────────────────────────────────────────────────────────────
#  HELPER: Send a single FCM message
# ─────────────────────────────────────────────────────────────────
def send_fcm(token: str, title: str, body: str, data: dict = None, image: str = None):
    """Send one FCM push to a single device token."""
    if not token:
        return None

    notification = messaging.Notification(title=title, body=body, image=image)

    msg = messaging.Message(
        notification=notification,
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                sound="default",
                channel_id="casc_channel",
            ),
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(sound="default"),
            ),
        ),
        data=data or {},
        token=token,
    )

    try:
        response = messaging.send(msg)
        print(f"[FCM] Sent → {response}")
        return response
    except Exception as e:
        print(f"[FCM ERROR] {e}")
        return None


def send_fcm_multicast(tokens: list, title: str, body: str, data: dict = None):
    """Send one FCM push to multiple device tokens at once."""
    if not tokens:
        return None

    notification = messaging.Notification(title=title, body=body)

    msg = messaging.MulticastMessage(
        notification=notification,
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                sound="default",
                channel_id="casc_channel",
            ),
        ),
        data=data or {},
        tokens=tokens,
    )

    try:
        response = messaging.send_each_for_multicast(msg)
        print(f"[FCM MULTICAST] success={response.success_count} fail={response.failure_count}")
        return response
    except Exception as e:
        print(f"[FCM MULTICAST ERROR] {e}")
        return None


def get_token(uid: str) -> str:
    """Fetch a user's FCM token from Firestore users/{uid}.fcmToken"""
    try:
        doc = db.collection("users").document(uid).get()
        if doc.exists:
            return doc.to_dict().get("fcmToken", "")
    except Exception as e:
        print(f"[TOKEN ERROR] uid={uid} → {e}")
    return ""


def get_tokens(uids: list) -> list:
    """Fetch FCM tokens for a list of uids, skip empty ones."""
    tokens = []
    for uid in uids:
        t = get_token(uid)
        if t:
            tokens.append(t)
    return tokens



# ─────────────────────────────────────────────────────────────────
#  1. STAFF UPLOADS STUDY MATERIAL
#     Called by: staff app after uploading to staff_uploads/{docId}
#
#  Flow:
#   staff uploads material → app calls this endpoint →
#   we find all students in that degree+department →
#   send push to each student + store in notifications/students/messages
#
#  Payload (POST JSON):
#   {
#     "staffId":      "uid of staff who uploaded",
#     "staffName":    "Dr. Ravi",
#     "degree":       "B.Sc",
#     "department":   "Computer Science",
#     "subject":      "AI",
#     "materialType": "Study Material",
#     "uploadDocId":  "OA8zT83eATlY1QB8yneF"   ← staff_uploads doc id
#   }
# ─────────────────────────────────────────────────────────────────
@app.route("/notify_material_upload", methods=["POST"])
def notify_material_upload():
    data         = request.json
    staff_name   = data.get("staffName",    "Staff")
    degree       = data.get("degree",       "")
    department   = data.get("department",   "")
    subject      = data.get("subject",      "")
    material_type= data.get("materialType", "Study Material")
    upload_doc_id= data.get("uploadDocId",  "")

    title = f"New {material_type} Added"
    body  = f"{staff_name} uploaded {material_type} for {subject} ({degree} {department})"

    # ── Find all students in this degree + department ─────────────
    student_uids = []
    try:
        classes = db.collection("Student_Of_College") \
            .where("course",     "==", degree) \
            .where("department", "==", department) \
            .stream()

        for cls in classes:
            students = cls.reference.collection("students").stream()
            for s in students:
                student_uids.append(s.id)
    except Exception as e:
        print(f"[MATERIAL] Error fetching students: {e}")

    if not student_uids:
        return jsonify({"success": False, "message": "No students found"}), 404

    # ── Send push notifications ───────────────────────────────────
    tokens = get_tokens(student_uids)
    send_fcm_multicast(
        tokens=tokens,
        title=title,
        body=body,
        data={
            "type":        "material_upload",
            "uploadDocId": upload_doc_id,
            "subject":     subject,
            "degree":      degree,
            "department":  department,
        },
    )

    # ── Store notification in Firestore for in-app bell icon ──────
    notif_doc = {
        "type":         "material_upload",
        "title":        title,
        "body":         body,
        "staffName":    staff_name,
        "degree":       degree,
        "department":   department,
        "subject":      subject,
        "materialType": material_type,
        "uploadDocId":  upload_doc_id,
        "sentTo":       student_uids,
        "createdAt":    firestore.SERVER_TIMESTAMP,
        "readBy":       [],
    }
    db.collection("notifications").document("students") \
      .collection("messages").add(notif_doc)

    print(f"[MATERIAL] Notified {len(student_uids)} students")
    return jsonify({"success": True, "notified": len(student_uids)})


# ─────────────────────────────────────────────────────────────────
#  3. LEAVE LETTER STATUS CHANGE  (Approved / Rejected)
#     Called by: staff app when they approve or reject a leave letter
#
#  Flow:
#   staff taps Approve/Reject → app calls this endpoint →
#   we push notification to the student + update overallStatus
#
#  Payload (POST JSON):
#   {
#     "leaveDocId":  "e4pvpKrmHkfhnHsJIAIJ",
#     "studentId":   "PweeYwl8W5dqsRdwz3Cdz2xcPda2",
#     "studentName": "Mary K",
#     "staffId":     "Ikq4FYwiraUf7PI1nfb5DesVbeo1",
#     "staffName":   "Dr. Ravi",
#     "status":      "Approved"    ← or "Rejected"
#   }
# ─────────────────────────────────────────────────────────────────
@app.route("/notify_leave_status", methods=["POST"])
def notify_leave_status():
    data          = request.json
    leave_doc_id  = data.get("leaveDocId",  "")
    student_id    = data.get("studentId",   "")
    student_name  = data.get("studentName", "Student")
    staff_name    = data.get("staffName",   "Staff")
    status        = data.get("status",      "Approved")   # "Approved" | "Rejected"

    if not leave_doc_id or not student_id:
        return jsonify({"success": False, "message": "leaveDocId and studentId required"}), 400

    emoji = "✅" if status == "Approved" else "❌"
    title = f"Leave Letter {status}"
    body  = f"{emoji} Your leave request has been {status.lower()} by {staff_name}."

    # ── Push to student ───────────────────────────────────────────
    token = get_token(student_id)
    send_fcm(
        token=token,
        title=title,
        body=body,
        data={
            "type":         "leave_status",
            "leaveDocId":   leave_doc_id,
            "status":       status,
        },
    )

    # ── Store in-app notification for student ─────────────────────
    notif_doc = {
        "type":        "leave_status",
        "title":       title,
        "body":        body,
        "leaveDocId":  leave_doc_id,
        "studentId":   student_id,
        "studentName": student_name,
        "staffName":   staff_name,
        "status":      status,
        "createdAt":   firestore.SERVER_TIMESTAMP,
        "read":        False,
    }
    db.collection("notifications").document("students") \
      .collection("messages").add(notif_doc)

    print(f"[LEAVE] Notified {student_name} → {status}")
    return jsonify({"success": True, "status": status})


# ─────────────────────────────────────────────────────────────────
#  4. ADMIN SENDS CUSTOM NOTIFICATION
#     Called by: admin app from notification page
#
#  Flow:
#   admin writes title + body, picks target (students / staff / all)
#   → app calls this endpoint → we push + store in Firestore
#
#  Payload (POST JSON):
#   {
#     "title":   "Exam Schedule Released",
#     "body":    "Check the timetable in the app.",
#     "target":  "students"    ← "students" | "staff" | "all"
#     "degree":      "",       ← optional: filter by degree
#     "department":  "",       ← optional: filter by department
#     "imageUrl": ""           ← optional
#   }
# ─────────────────────────────────────────────────────────────────
@app.route("/admin_notify", methods=["POST"])
def admin_notify():
    data       = request.json
    title      = data.get("title",      "")
    body       = data.get("body",       "")
    target     = data.get("target",     "all")   # students | staff | all
    degree     = data.get("degree",     "")
    department = data.get("department", "")
    image_url  = data.get("imageUrl",   None)

    if not title or not body:
        return jsonify({"success": False, "message": "title and body required"}), 400

    recipient_uids = []

    # ── Collect student UIDs ──────────────────────────────────────
    if target in ("students", "all"):
        try:
            query = db.collection("Student_Of_College")
            if degree:
                query = query.where("course", "==", degree)
            if department:
                query = query.where("department", "==", department)

            for cls in query.stream():
                for s in cls.reference.collection("students").stream():
                    recipient_uids.append(s.id)
        except Exception as e:
            print(f"[ADMIN NOTIFY] Error fetching students: {e}")

    # ── Collect staff UIDs ────────────────────────────────────────
    if target in ("staff", "all"):
        try:
            query = db.collection("staff_of_college")
            if department:
                query = query.where("department", "==", department)

            for dept in query.stream():
                for s in dept.reference.collection("staff").stream():
                    if s.id not in recipient_uids:
                        recipient_uids.append(s.id)
        except Exception as e:
            print(f"[ADMIN NOTIFY] Error fetching staff: {e}")

    if not recipient_uids:
        return jsonify({"success": False, "message": "No recipients found"}), 404

    # ── Send push ─────────────────────────────────────────────────
    tokens = get_tokens(recipient_uids)
    send_fcm_multicast(
        tokens=tokens,
        title=title,
        body=body,
        data={
            "type":  "admin_notification",
            "target": target,
        },
    )

    # ── Store in Firestore ────────────────────────────────────────
    collection = "students" if target == "students" else "staff" if target == "staff" else "students"
    notif_doc = {
        "type":       "admin_notification",
        "title":      title,
        "body":       body,
        "target":     target,
        "degree":     degree,
        "department": department,
        "imageUrl":   image_url,
        "sentTo":     recipient_uids,
        "createdAt":  firestore.SERVER_TIMESTAMP,
        "readBy":     [],
    }
    db.collection("notifications").document(collection) \
      .collection("messages").add(notif_doc)

    # also store in staff messages if target == "all"
    if target == "all":
        db.collection("notifications").document("staff") \
          .collection("messages").add(notif_doc)

    print(f"[ADMIN NOTIFY] Sent to {len(recipient_uids)} recipients")
    return jsonify({"success": True, "notified": len(recipient_uids)})


# ─────────────────────────────────────────────────────────────────
#  5. FEES REMINDER PUSH
#     Called by: admin app from NotifyStudentsPage when tapping
#                "Send Reminder" on a student
#
#  Flow:
#   admin triggers send → app already writes to feesnotify collection →
#   app ALSO calls this endpoint → we send the FCM push to the student
#
#  Payload (POST JSON):
#   {
#     "studentId":   "PweeYwl8W5dqsRdwz3Cdz2xcPda2",
#     "studentName": "Mary K",
#     "semester":    "sem1",
#     "year":        "2026",
#     "daysRemaining": 3,
#     "deadline":    "14/3/2026",
#     "feesNotifyDocId": "PweeYwl8W5dqsRdwz3Cdz2xcPda2_sem1_2026"
#   }
# ─────────────────────────────────────────────────────────────────
@app.route("/notify_fees_reminder", methods=["POST"])
def notify_fees_reminder():
    data              = request.json
    student_id        = data.get("studentId",       "")
    student_name      = data.get("studentName",     "Student")
    semester          = data.get("semester",        "")
    year              = data.get("year",            "")
    days_remaining    = data.get("daysRemaining",   0)
    deadline          = data.get("deadline",        "")
    fees_notify_doc_id= data.get("feesNotifyDocId", "")

    if not student_id:
        return jsonify({"success": False, "message": "studentId required"}), 400

    # Build message matching what your Dart code already writes to Firestore
    if days_remaining < 0:
        title = "⚠️ Overdue Fees Reminder"
        body  = (f"Dear {student_name}, your {semester} fees was due on "
                 f"{deadline}. Please pay immediately to avoid late fees.")
    elif days_remaining <= 3:
        title = "🚨 Urgent Fees Reminder"
        body  = (f"Dear {student_name}, your {semester} fees is due in "
                 f"{days_remaining} day(s) ({deadline}). Please pay soon.")
    else:
        title = "📢 Fees Reminder"
        body  = (f"Dear {student_name}, please pay your {semester} fees "
                 f"before {deadline}. {days_remaining} days remaining.")

    token = get_token(student_id)
    if not token:
        return jsonify({"success": False, "message": "No FCM token for student"}), 404

    send_fcm(
        token=token,
        title=title,
        body=body,
        data={
            "type":            "fees_reminder",
            "semester":        semester,
            "year":            year,
            "daysRemaining":   str(days_remaining),
            "feesNotifyDocId": fees_notify_doc_id,
        },
    )

    print(f"[FEES] Reminded {student_name} → {semester} {year} ({days_remaining}d)")
    return jsonify({"success": True, "student": student_name})


# ─────────────────────────────────────────────────────────────────
#  6. FEES REMINDER — SEND ALL  (batch version)
#     Called by: admin sendReminderToAll() in NotifyStudentsPage
#
#  Payload (POST JSON):
#   {
#     "reminders": [
#       {
#         "studentId":   "uid1",
#         "studentName": "Mary K",
#         "semester":    "sem1",
#         "year":        "2026",
#         "daysRemaining": 3,
#         "deadline":    "14/3/2026",
#         "feesNotifyDocId": "uid1_sem1_2026"
#       },
#       ...
#     ]
#   }
# ─────────────────────────────────────────────────────────────────
@app.route("/notify_fees_reminder_all", methods=["POST"])
def notify_fees_reminder_all():
    data      = request.json
    reminders = data.get("reminders", [])

    if not reminders:
        return jsonify({"success": False, "message": "No reminders provided"}), 400

    success_count = 0
    fail_count    = 0

    for r in reminders:
        student_id     = r.get("studentId",     "")
        student_name   = r.get("studentName",   "Student")
        semester       = r.get("semester",      "")
        year           = r.get("year",          "")
        days_remaining = r.get("daysRemaining", 0)
        deadline       = r.get("deadline",      "")
        doc_id         = r.get("feesNotifyDocId","")

        if not student_id:
            fail_count += 1
            continue

        if days_remaining < 0:
            title = "⚠️ Overdue Fees Reminder"
            body  = (f"Dear {student_name}, your {semester} fees was due on "
                     f"{deadline}. Please pay immediately.")
        elif days_remaining <= 3:
            title = "🚨 Urgent Fees Reminder"
            body  = (f"URGENT: Dear {student_name}, your {semester} fees is "
                     f"due in {days_remaining} day(s) ({deadline}).")
        else:
            title = "📢 Fees Reminder"
            body  = (f"Dear {student_name}, pay your {semester} fees before "
                     f"{deadline}. {days_remaining} days left.")

        token = get_token(student_id)
        result = send_fcm(
            token=token,
            title=title,
            body=body,
            data={
                "type":            "fees_reminder",
                "semester":        semester,
                "year":            year,
                "daysRemaining":   str(days_remaining),
                "feesNotifyDocId": doc_id,
            },
        )
        if result:
            success_count += 1
        else:
            fail_count += 1

    print(f"[FEES ALL] success={success_count} fail={fail_count}")
    return jsonify({
        "success":      True,
        "sent":         success_count,
        "failed":       fail_count,
        "total":        len(reminders),
    })


# ─────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)