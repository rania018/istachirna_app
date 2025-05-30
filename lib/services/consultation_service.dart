import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/consultation.dart';

class ConsultationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'consultations';

  // Create a new consultation
  Future<Consultation> createConsultation(Consultation consultation) async {
    try {
      final docRef = await _firestore.collection(_collection).add(consultation.toMap());
      return consultation;
    } catch (e) {
      rethrow;
    }
  }

  // Get user's consultations
  Stream<List<Consultation>> getUserConsultations(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Consultation.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }

  // Get consultation by ID
  Future<Consultation?> getConsultation(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return Consultation.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Add message to consultation
  Future<void> addMessage(String consultationId, Message message) async {
    try {
      await _firestore.collection(_collection).doc(consultationId).update({
        'messages': FieldValue.arrayUnion([message.toMap()])
      });
    } catch (e) {
      rethrow;
    }
  }

  // Update consultation status
  Future<void> updateStatus(String consultationId, String status) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(consultationId)
          .update({'status': status});
    } catch (e) {
      rethrow;
    }
  }

  // Assign consultant to consultation
  Future<void> assignConsultant(
      String consultationId, String consultantId) async {
    try {
      await _firestore.collection(_collection).doc(consultationId).update({
        'consultantId': consultantId,
        'status': 'in_progress',
      });
    } catch (e) {
      rethrow;
    }
  }
} 