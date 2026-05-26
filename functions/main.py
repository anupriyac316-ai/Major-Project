import firebase_functions as functions
from firebase_admin import initialize_app, firestore

# Initialize Firebase Admin SDK
initialize_app()
db = firestore.client()

@functions.auth.user().on_create()
def on_user_create(event: functions.auth.UserRecord):
    uid = event.uid
    email = event.email

    # Reference to admin lock
    lock_ref = db.collection("system").document("admin_lock")
    lock_doc = lock_ref.get()

    if not lock_doc.exists:
        # ✅ First user → make admin
        db.collection("users").document(uid).set({
            "email": email,
            "role": "admin",
            "createdAt": firestore.SERVER_TIMESTAMP
        })

        # Create admin lock
        lock_ref.set({
            "locked": True,
            "adminId": uid
        })

        print(f"First admin created: {email}")

    else:
        # ❌ Normal user
        db.collection("users").document(uid).set({
            "email": email,
            "role": "user",
            "createdAt": firestore.SERVER_TIMESTAMP
        })

        print(f"Normal user created: {email}")
