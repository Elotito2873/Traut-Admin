import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traut_admin/app.dart';
import 'package:traut_admin/presentation/controllers/auth_controller.dart';
import 'package:traut_admin/presentation/pages/auth/login_page.dart';
import 'package:traut_admin/presentation/pages/fleet/fleet_page.dart';

class _SignedOutAuthController extends AuthController {
  @override
  AuthViewState build() => const AuthViewState(stage: AuthStage.signedOut);
}

void main() {
  testWidgets('una ruta administrativa manual redirige al acceso', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_SignedOutAuthController.new),
        ],
        child: const TrautAdminApp(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(LoginPage));
    GoRouter.of(context).go('/fleet');
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(FleetPage), findsNothing);
  });
}
