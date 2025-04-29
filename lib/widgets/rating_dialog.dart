import 'package:flutter/material.dart';

class RatingDialog extends StatefulWidget {
  final Function(double rating, String feedback) onSubmitted;

  const RatingDialog({
    Key? key,
    required this.onSubmitted,
  }) : super(key: key);

  @override
  _RatingDialogState createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double _rating = 3.0;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate Your Experience'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'How would you rate your session with this therapist?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 36,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1.0;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 16),
            Text(
              _getRatingText(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getRatingColor(),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                labelText: 'Share your feedback (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  setState(() {
                    _isSubmitting = true;
                  });
                  widget.onSubmitted(_rating, _feedbackController.text.trim());
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('SUBMIT'),
        ),
      ],
    );
  }

  String _getRatingText() {
    if (_rating <= 1) return 'Very Dissatisfied';
    if (_rating <= 2) return 'Dissatisfied';
    if (_rating <= 3) return 'Neutral';
    if (_rating <= 4) return 'Satisfied';
    return 'Very Satisfied';
  }

  Color _getRatingColor() {
    if (_rating <= 1) return Colors.red;
    if (_rating <= 2) return Colors.orange;
    if (_rating <= 3) return Colors.amber;
    if (_rating <= 4) return Colors.lightGreen;
    return Colors.green;
  }
} 