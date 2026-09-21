import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChildProfile {
  const ChildProfile({required this.id, required this.name, this.avatarKey});

  final String id;
  final String name;
  final String? avatarKey;

  factory ChildProfile.fromDocument(
      QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    return ChildProfile(
      id: document.id,
      name: data['name'] as String? ?? 'Anak',
      avatarKey: data['avatarKey'] as String?,
    );
  }
}

class PurchaseEntitlement {
  const PurchaseEntitlement({required this.productId, required this.active});

  final String productId;
  final bool active;

  factory PurchaseEntitlement.fromDocument(
      QueryDocumentSnapshot<Map<String, dynamic>> document) {
    return PurchaseEntitlement(
      productId: document.id,
      active: document.data()['active'] == true,
    );
  }
}

class ParentAccountService {
  ParentAccountService._();

  static final instance = ParentAccountService._();

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  User? get currentUser => auth.currentUser;
  Stream<User?> get authChanges => auth.authStateChanges();
  Future<void>? _googleInitialization;

  Future<UserCredential> createAccount({
    required String email,
    required String password,
    required String childName,
    required SharedPreferences prefs,
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName('Orang Tua');
    try {
      await credential.user?.sendEmailVerification();
    } catch (error) {
      debugPrint('Verification email could not be sent yet: $error');
    }
    await _syncAfterAuthentication(childName: childName, prefs: prefs);
    return credential;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
    required String childName,
    required SharedPreferences prefs,
  }) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _syncAfterAuthentication(childName: childName, prefs: prefs);
    return credential;
  }

  Future<UserCredential> signInWithGoogle({
    required String childName,
    required SharedPreferences prefs,
  }) async {
    late final UserCredential credential;
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      credential = await auth.signInWithPopup(provider);
    } else {
      _googleInitialization ??= GoogleSignIn.instance.initialize();
      await _googleInitialization;
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final googleCredential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      credential = await auth.signInWithCredential(googleCredential);
    }
    await _syncAfterAuthentication(childName: childName, prefs: prefs);
    return credential;
  }

  Future<void> _syncAfterAuthentication({
    required String childName,
    required SharedPreferences prefs,
  }) async {
    try {
      await ensureParentAndSync(childName: childName, prefs: prefs);
    } catch (error) {
      // Authentication has already succeeded. A temporary Firestore/rules
      // problem must not make the UI claim that sign-in failed.
      debugPrint('Account authenticated; cloud sync will retry later: $error');
    }
  }

  Future<void> sendPasswordReset(String email) =>
      auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() async {
    await auth.signOut();
    if (!kIsWeb && _googleInitialization != null) {
      await GoogleSignIn.instance.signOut();
    }
  }

  Future<void> ensureParentAndSync({
    required String childName,
    required SharedPreferences prefs,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final parent = firestore.collection('parents').doc(user.uid);
    final primary = parent.collection('children').doc('primary');

    await firestore.runTransaction((transaction) async {
      final parentSnapshot = await transaction.get(parent);
      final childSnapshot = await transaction.get(primary);
      if (!parentSnapshot.exists) {
        transaction.set(parent, {
          'displayName': user.displayName ?? 'Orang Tua',
          'email': user.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(parent, {
          'displayName': user.displayName ?? 'Orang Tua',
          'email': user.email ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!childSnapshot.exists) {
        transaction.set(primary, {
          'name': childName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    await prefs.setString(
        'active_child_id', prefs.getString('active_child_id') ?? 'primary');
    await syncLocalProgress(prefs);
  }

  Stream<List<ChildProfile>> children() {
    final user = currentUser;
    if (user == null) return Stream.value(const []);
    return firestore
        .collection('parents')
        .doc(user.uid)
        .collection('children')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(ChildProfile.fromDocument)
            .toList(growable: false));
  }

  Future<ChildProfile> addChild(String name) async {
    final user = currentUser;
    if (user == null) throw StateError('Parent account is not signed in.');
    final document = firestore
        .collection('parents')
        .doc(user.uid)
        .collection('children')
        .doc();
    await document.set({
      'name': name.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ChildProfile(id: document.id, name: name.trim());
  }

  Stream<List<PurchaseEntitlement>> entitlements() {
    final user = currentUser;
    if (user == null) return Stream.value(const []);
    return firestore
        .collection('parents')
        .doc(user.uid)
        .collection('entitlements')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(PurchaseEntitlement.fromDocument)
            .toList(growable: false));
  }

  Future<bool> hasActiveEntitlement() async {
    final user = currentUser;
    if (user == null) return false;
    final snapshot = await firestore
        .collection('parents')
        .doc(user.uid)
        .collection('entitlements')
        .where('active', isEqualTo: true)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> syncLocalProgress(SharedPreferences prefs) async {
    final user = currentUser;
    if (user == null) return;
    final childId = prefs.getString('active_child_id') ?? 'primary';
    final progress = firestore
        .collection('parents')
        .doc(user.uid)
        .collection('children')
        .doc(childId)
        .collection('progress');
    final batch = firestore.batch();
    var writes = 0;
    final scopedPrefix = 'read_${childId}_';
    for (final key in prefs.getKeys()) {
      if (prefs.getBool(key) != true) continue;
      String? storyId;
      if (key.startsWith(scopedPrefix)) {
        storyId = key.substring(scopedPrefix.length);
      } else if (childId == 'primary' &&
          key.startsWith('read_') &&
          !key.substring(5).contains('_')) {
        storyId = key.substring(5);
        await prefs.setBool('$scopedPrefix$storyId', true);
      }
      if (storyId == null || storyId.isEmpty) continue;
      batch.set(
          progress.doc(storyId),
          {
            'completed': true,
            'lastPage': 0,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
      writes++;
    }
    if (writes > 0) await batch.commit();
    await pullCloudProgress(prefs);
  }

  Future<void> pullCloudProgress(SharedPreferences prefs) async {
    final user = currentUser;
    if (user == null) return;
    final childId = prefs.getString('active_child_id') ?? 'primary';
    final snapshot = await firestore
        .collection('parents')
        .doc(user.uid)
        .collection('children')
        .doc(childId)
        .collection('progress')
        .get();
    for (final document in snapshot.docs) {
      if (document.data()['completed'] == true) {
        await prefs.setBool('read_${childId}_${document.id}', true);
      }
    }
  }

  Future<void> markStoryRead(
      String storyId, SharedPreferences prefs, int lastPage) async {
    final user = currentUser;
    if (user == null) return;
    final childId = prefs.getString('active_child_id') ?? 'primary';
    await firestore
        .collection('parents')
        .doc(user.uid)
        .collection('children')
        .doc(childId)
        .collection('progress')
        .doc(storyId)
        .set({
      'completed': true,
      'lastPage': lastPage,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
