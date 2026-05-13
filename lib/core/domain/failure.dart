/// File: failure.dart
/// TARGET: Tipizzazione errori per tutta l'applicazione
/// LOGIC GOAL: Unificare la gestione errori con classi tipizzate
/// REACTION: UI mostra messaggi specifici basati sul tipo di Failure
/// ERROR STRATEGY: Ogni Failure ha messaggio utente e dettaglio tecnico opzionale

import 'package:flutter/foundation.dart';

@immutable
abstract class Failure {
  final String message;
  final String? technicalDetails;

  const Failure({required this.message, this.technicalDetails});

  @override
  String toString() => 'Failure: $message${technicalDetails != null ? ' ($technicalDetails)' : ''}';
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'Connessione assente', super.technicalDetails});
}

class ServerFailure extends Failure {
  const ServerFailure({super.message = 'Errore del server', super.technicalDetails});
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.technicalDetails});
}

class ProfileNotFoundFailure extends Failure {
  const ProfileNotFoundFailure({super.message = 'Profilo non trovato', super.technicalDetails});
}

class ProfileSaveFailure extends Failure {
  const ProfileSaveFailure({super.message = 'Errore salvataggio profilo', super.technicalDetails});
}

class EmailUpdateFailure extends Failure {
  const EmailUpdateFailure({super.message = 'Errore cambio email', super.technicalDetails});
}

class PasswordUpdateFailure extends Failure {
  const PasswordUpdateFailure({super.message = 'Errore cambio password', super.technicalDetails});
}

class AccountDeleteFailure extends Failure {
  const AccountDeleteFailure({super.message = 'Errore eliminazione account', super.technicalDetails});
}

class StatsResetFailure extends Failure {
  const StatsResetFailure({super.message = 'Errore reset statistiche', super.technicalDetails});
}

class DataExportFailure extends Failure {
  const DataExportFailure({super.message = 'Errore esportazione dati', super.technicalDetails});
}