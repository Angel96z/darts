import 'package:flutter/material.dart';

class TrainingFeedbackData {
  final int? focus;
  final int? stress;
  final int? energia;
  final int? fiducia;
  final int? distrazioni;
  final String? commento;

  const TrainingFeedbackData({
    this.focus,
    this.stress,
    this.energia,
    this.fiducia,
    this.distrazioni,
    this.commento,
  });
}

class TrainingFeedbackScreen extends StatefulWidget {
  const TrainingFeedbackScreen({super.key});

  @override
  State<TrainingFeedbackScreen> createState() => _TrainingFeedbackScreenState();
}

class _TrainingFeedbackScreenState extends State<TrainingFeedbackScreen> {
  int? _focus;
  int? _stress;
  int? _energia;
  int? _fiducia;
  int? _distrazioni;
  final TextEditingController _commentoController = TextEditingController();

  @override
  void dispose() {
    _commentoController.dispose();
    super.dispose();
  }

  Widget _scoreField(String label, int? value, ValueChanged<int?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DropdownButton<int?>(
            value: value,
            hint: const Text('—'),
            items: const [
              DropdownMenuItem<int?>(value: null, child: Text('—')),
              DropdownMenuItem(value: 1, child: Text('1')),
              DropdownMenuItem(value: 2, child: Text('2')),
              DropdownMenuItem(value: 3, child: Text('3')),
              DropdownMenuItem(value: 4, child: Text('4')),
              DropdownMenuItem(value: 5, child: Text('5')),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _submit() {
    Navigator.pop(
      context,
      TrainingFeedbackData(
        focus: _focus,
        stress: _stress,
        energia: _energia,
        fiducia: _fiducia,
        distrazioni: _distrazioni,
        commento: _commentoController.text.trim().isEmpty
            ? null
            : _commentoController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback sessione')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Valutazioni (opzionale)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _scoreField('Focus', _focus, (v) => setState(() => _focus = v)),
          _scoreField('Stress', _stress, (v) => setState(() => _stress = v)),
          _scoreField('Energia fisica', _energia, (v) => setState(() => _energia = v)),
          _scoreField('Fiducia', _fiducia, (v) => setState(() => _fiducia = v)),
          _scoreField('Distrazioni', _distrazioni, (v) => setState(() => _distrazioni = v)),
          const SizedBox(height: 8),
          TextField(
            controller: _commentoController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Commento',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }
}
