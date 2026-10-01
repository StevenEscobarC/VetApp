import 'package:go_router/go_router.dart';

import 'screens/agenda_screen.dart';

/// Root route for the Agenda tab. Later plans add child `GoRoute`s here in
/// the order `nueva` (04-05), then `:id` with its children (04-06): static
/// child segments MUST precede `:id` so `/agenda/nueva` never matches it
/// (same rule as `clientes_routes.dart`).
final GoRoute agendaRoute = GoRoute(
  path: '/agenda',
  builder: (_, _) => const AgendaScreen(),
  routes: [],
);
