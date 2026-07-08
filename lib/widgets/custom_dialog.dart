import 'package:flutter/material.dart';
import 'app_colors.dart';

enum CustomDialogType { success, error, info }

class CustomDialog extends StatelessWidget {
  final String title;
  final String message;
  final CustomDialogType type;
  final VoidCallback? onConfirm;

  const CustomDialog({
    super.key,
    required this.title,
    required this.message,
    required this.type,
    this.onConfirm,
  });

  static void show({
    required BuildContext context,
    required String title,
    required String message,
    required CustomDialogType type,
    VoidCallback? onConfirm,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeInOutBack);
        return ScaleTransition(
          scale: curve,
          child: Align(
            alignment: Alignment.center,
            child: CustomDialog(
              title: title,
              message: message,
              type: type,
              onConfirm: onConfirm,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    IconData iconData;
    Color buttonColor;

    switch (type) {
      case CustomDialogType.success:
        iconColor = Colors.green.shade600;
        iconData = Icons.check_circle_rounded;
        buttonColor = AppColors.primaryBlue;
        break;
      case CustomDialogType.error:
        iconColor = Colors.red.shade600;
        iconData = Icons.error_rounded;
        buttonColor = AppColors.primaryBlue;
        break;
      case CustomDialogType.info:
        iconColor = Colors.blue.shade600;
        iconData = Icons.info_rounded;
        buttonColor = AppColors.primaryBlue;
        break;
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      elevation: 16,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10.0,
              offset: const Offset(0.0, 10.0),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // To make the card compact
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: iconColor,
                size: 54.0,
              ),
            ),
            const SizedBox(height: 20.0),
            Text(
              title,
              style: TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
                decoration: TextDecoration.none,
                fontFamily: 'Roboto',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12.0),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14.0,
                color: Colors.black87,
                height: 1.4,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.normal,
                fontFamily: 'Roboto',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24.0),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  elevation: 2,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  if (onConfirm != null) {
                    onConfirm!();
                  }
                },
                child: const Text(
                  'Okay',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
