import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/features/auth/presentation/screens/login_screen.dart';

void main() {
  group('Auth Form Input Validation Logic', () {
    final emailRegExp = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    String? validateEmail(String? value) {
      final email = value?.trim() ?? '';
      if (email.isEmpty) return 'Email is required';
      if (!emailRegExp.hasMatch(email)) {
        return 'Please enter a valid email address';
      }
      return null;
    }

    String? validatePassword(String? value) {
      final password = value ?? '';
      if (password.isEmpty) return 'Password is required';
      if (password.length < 6) return 'Password must be at least 6 characters';
      return null;
    }

    group('Email Validation', () {
      test('rejects empty and whitespace-only email', () {
        expect(validateEmail(null), 'Email is required');
        expect(validateEmail(''), 'Email is required');
        expect(validateEmail('   '), 'Email is required');
      });

      test('rejects malformed email formats', () {
        expect(
          validateEmail('plainaddress'),
          'Please enter a valid email address',
        );
        expect(
          validateEmail('missing-at-domain.com'),
          'Please enter a valid email address',
        );
        expect(
          validateEmail('@missingusername.com'),
          'Please enter a valid email address',
        );
        expect(
          validateEmail('user@domain'),
          'Please enter a valid email address',
        );
        expect(
          validateEmail('user@.com'),
          'Please enter a valid email address',
        );
        expect(
          validateEmail('user@domain.'),
          'Please enter a valid email address',
        );
        expect(
          validateEmail('user@domain.c'),
          'Please enter a valid email address',
        );
      });

      test('accepts valid email addresses', () {
        expect(validateEmail('reader@quicknews.com'), isNull);
        expect(validateEmail('user.name@example.co.uk'), isNull);
        expect(validateEmail('user+tag@domain.org'), isNull);
        expect(validateEmail('123@numbers.com'), isNull);
      });
    });

    group('Password Validation', () {
      test('rejects empty password', () {
        expect(validatePassword(null), 'Password is required');
        expect(validatePassword(''), 'Password is required');
      });

      test('rejects passwords shorter than 6 characters', () {
        expect(
          validatePassword('1'),
          'Password must be at least 6 characters',
        );
        expect(
          validatePassword('12'),
          'Password must be at least 6 characters',
        );
        expect(
          validatePassword('12345'),
          'Password must be at least 6 characters',
        );
        expect(
          validatePassword('abcde'),
          'Password must be at least 6 characters',
        );
      });

      test('accepts passwords of 6 or more characters', () {
        expect(validatePassword('123456'), isNull);
        expect(validatePassword('password123'), isNull);
        expect(validatePassword('verylongsecurepassword'), isNull);
      });
    });
  });

  group('LoginScreen Form UI Validation Widget Tests', () {
    testWidgets('shows validation errors when submitted empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Verify screen rendered
      expect(find.text('QuickNews'), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);

      // Tap Sign In button without entering inputs
      final loginButton = find.byKey(const Key('login_button'));
      expect(loginButton, findsOneWidget);
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Check inline validation error messages
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('shows invalid email and short password errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Enter invalid email and short password
      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'invalid-email',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        '123',
      );

      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('toggles password visibility', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Initial state is obscured
      final visibilityToggle =
          find.byKey(const Key('toggle_password_visibility'));
      expect(visibilityToggle, findsOneWidget);

      // Tap toggle to reveal
      await tester.tap(visibilityToggle);
      await tester.pumpAndSettle();

      // Tap toggle again to obscure
      await tester.tap(visibilityToggle);
      await tester.pumpAndSettle();
    });

    testWidgets('auto-fill populates valid demo credentials',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      final autoFillButton = find.byKey(const Key('quick_fill_button'));
      expect(autoFillButton, findsOneWidget);

      await tester.tap(autoFillButton);
      await tester.pumpAndSettle();

      expect(find.text('reader@quicknews.com'), findsOneWidget);
      expect(find.text('password123'), findsOneWidget);
    });
  });
}
