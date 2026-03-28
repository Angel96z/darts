class FunctionsDataSource {
  const FunctionsDataSource();

  Future<void> applyCommand(Map<String, dynamic> command) async {
    // Command validation + application are expected server-side.
  }

  Future<void> finalizeMatch(Map<String, dynamic> payload) async {
    // Match finalization + stats persistence are expected server-side.
  }
}
