import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageFor(error));
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(name.trim());
      final user = credential.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'name': name.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageFor(error));
    } on FirebaseException catch (error) {
      throw AuthServiceException(
        'A conta foi criada, mas não foi possível salvar o perfil: ${error.message ?? 'tente novamente.'}',
      );
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageFor(error));
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageFor(error));
    }
  }

  String _messageFor(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado. Faça login ou use outro e-mail.';
      case 'weak-password':
        return 'A senha é muito fraca. Use pelo menos 6 caracteres.';
      case 'invalid-credential':
      case 'wrong-password':
        return 'E-mail ou senha incorretos. Confira os dados e tente novamente.';
      case 'user-not-found':
        return 'Este e-mail não tem conta cadastrada. Toque em "Cadastre-se" para criar uma.';
      case 'invalid-email':
        return 'Informe um endereço de e-mail válido.';
      case 'user-disabled':
        return 'Esta conta foi desativada. Entre em contato com o suporte.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns instantes e tente novamente.';
      case 'network-request-failed':
        return 'Sem conexão com a internet. Verifique sua rede e tente novamente.';
      case 'operation-not-allowed':
        return 'O login por e-mail e senha não está habilitado no Firebase.';
      default:
        return 'Não foi possível concluir a operação. Tente novamente.';
    }
  }
}

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
