import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/buttons/app_button.dart';
import '../../core/widgets/cards/app_card.dart';
import '../../core/widgets/inputs/app_text_field.dart';
import '../../core/widgets/status/app_status_chip.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.pets_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'VetApp',
                  style: textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Tu consultorio veterinario en el bolsillo',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const AppTextField(
                  label: 'Correo electrónico',
                  hintText: 'dra.ramirez@correo.com',
                ),
                const SizedBox(height: AppSpacing.md),
                const AppTextField(
                  label: 'Contraseña',
                  hintText: '••••••••',
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(label: 'Iniciar sesión', onPressed: onLogin),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onLogin,
                    icon: const Icon(Icons.g_mobiledata_rounded),
                    label: const Text('Continuar con Google'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: Text(
                    'No tienes cuenta? Regístrate',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    PatientsScreen(),
    AgendaScreen(),
    HistoryScreen(),
    BillingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final navigation = NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) =>
          setState(() => _selectedIndex = index),
      labelType: NavigationRailLabelType.all,
      backgroundColor: Theme.of(context).colorScheme.surface,
      leading: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.lg),
        child: Icon(Icons.pets_rounded, color: AppColors.primary, size: 30),
      ),
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.home_rounded), label: Text('Inicio')),
        NavigationRailDestination(icon: Icon(Icons.pets_rounded), label: Text('Pacientes')),
        NavigationRailDestination(icon: Icon(Icons.calendar_month_rounded), label: Text('Agenda')),
        NavigationRailDestination(icon: Icon(Icons.article_rounded), label: Text('Historial')),
        NavigationRailDestination(icon: Icon(Icons.receipt_long_rounded), label: Text('Cobros')),
      ],
    );

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop) navigation,
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: IndexedStack(index: _selectedIndex, children: _pages),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.pets_rounded),
            label: 'Pacientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_rounded),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Cobros',
          ),
        ],
          ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = [
      _SummaryCard(
        title: 'Citas hoy',
        value: '08',
        subtitle: '+3 respecto al día anterior',
        color: AppColors.primary,
        icon: Icons.calendar_today_rounded,
      ),
      _SummaryCard(
        title: 'Vacunas',
        value: '04',
        subtitle: 'pendientes esta semana',
        color: AppColors.success,
        icon: Icons.vaccines_rounded,
      ),
    ];

    final actions = [
      _ActionTile(
        icon: Icons.pets_rounded,
        label: 'Pacientes',
        color: AppColors.primary,
        destination: const PatientsScreen(),
      ),
      _ActionTile(
        icon: Icons.calendar_month_rounded,
        label: 'Agenda',
        color: AppColors.success,
        destination: const AgendaScreen(),
      ),
      _ActionTile(
        icon: Icons.medical_services_rounded,
        label: 'Historia',
        color: AppColors.warning,
        destination: const HistoryScreen(),
      ),
      _ActionTile(
        icon: Icons.vaccines_rounded,
        label: 'Vacunas',
        color: AppColors.secondary,
        destination: const VaccinationScreen(),
      ),
      _ActionTile(
        icon: Icons.inventory_2_rounded,
        label: 'Inventario',
        color: AppColors.primary,
        destination: const InventoryScreen(),
      ),
      _ActionTile(
        icon: Icons.receipt_long_rounded,
        label: 'Facturas',
        color: AppColors.accent,
        destination: const BillingScreen(),
      ),
    ];

    final appointments = [
      _AppointmentCard(
        name: 'Firulais',
        subtitle: 'Consulta general',
        time: 'Hoy · 4:30 PM',
        status: AppStatus.confirmed,
      ),
      _AppointmentCard(
        name: 'Michi',
        subtitle: 'Vacunación',
        time: 'Mañana · 10:00 AM',
        status: AppStatus.pending,
      ),
      _AppointmentCard(
        name: 'Luna',
        subtitle: 'Control postoperatorio',
        time: 'Miércoles · 2:15 PM',
        status: AppStatus.completed,
      ),
    ];

    final patients = [
      _PatientRow(
        name: 'Firulais',
        species: 'Perro · Labrador',
        note: 'Sin novedades',
        avatar: 'F',
      ),
      _PatientRow(
        name: 'Michi',
        species: 'Gato · Mestizo',
        note: 'Vacuna anual',
        avatar: 'M',
      ),
      _PatientRow(
        name: 'Luna',
        species: 'Perro · Beagle',
        note: 'Chequeo general',
        avatar: 'L',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.secondary,
              child: Icon(
                Icons.pets_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VetApp',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Clínica y cuidado',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Icon(Icons.notifications_none_rounded),
          ),
        ],
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Text(
            'Buenos días, Dra. López',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Aquí tienes el resumen de tu jornada',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.35,
            children: cards,
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Próximas citas',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('Ver todo')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: appointments.length,
              separatorBuilder: (_, index) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) => SizedBox(
                width: 260,
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.secondary,
                            child: const Icon(
                              Icons.pets_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              appointments[index].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 96),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: AppStatusChip(
                                status: appointments[index].status,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        appointments[index].subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: AppColors.mutedForeground,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              appointments[index].time,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.colorScheme.outline),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text('Ver detalle'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Acciones rápidas',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: actions.map((action) {
              return SizedBox(
                width: 155,
                child: GestureDetector(
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => action.destination)),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: action.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(action.icon, color: action.color),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          action.label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pacientes activos',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('Todos')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...patients.map(
            (patient) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.secondary,
                      child: Text(
                        patient.avatar,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            patient.species,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            patient.note,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PatientsScreen extends StatelessWidget {
  const PatientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final patients = [
      _PatientCard(
        name: 'Firulais',
        species: 'Perro',
        age: '4 años',
        status: 'Salud estable',
      ),
      _PatientCard(
        name: 'Michi',
        species: 'Gato',
        age: '2 años',
        status: 'Vacuna anual',
      ),
      _PatientCard(
        name: 'Luna',
        species: 'Perro',
        age: '6 años',
        status: 'Control de seguimiento',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pacientes'),
        actions: const [Icon(Icons.search_rounded)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SizedBox(height: AppSpacing.sm),
          ...patients.map(
            (patient) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.secondary,
                      child: Text(
                        patient.name[0],
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${patient.species} · ${patient.age}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            patient.status,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Agregar paciente', onPressed: () {}),
        ],
      ),
    );
  }
}

class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final events = [
      _AgendaItem(
        title: 'Consulta general',
        patient: 'Firulais',
        time: '09:00',
      ),
      _AgendaItem(title: 'Vacunación', patient: 'Michi', time: '10:30'),
      _AgendaItem(
        title: 'Control postoperatorio',
        patient: 'Luna',
        time: '14:15',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Agenda')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Junio 2026',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                      .map(
                        (label) => Text(
                          label,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 1; i <= 30; i++)
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == 12 || i == 18 || i == 23
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$i',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Citas de hoy',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          ...events.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.patient,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      event.time,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final timeline = [
      _TimelineItem(
        date: '15 May',
        title: 'Consulta general',
        description: 'Evaluación general y signos vitales',
      ),
      _TimelineItem(
        date: '21 Apr',
        title: 'Vacunación',
        description: 'Antirrábica y vacuna anual aplicadas',
      ),
      _TimelineItem(
        date: '08 Mar',
        title: 'Control de peso',
        description: 'Revisión de dieta y rutina diaria',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Historia clínica')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Firulais',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Perro · Labrador · 4 años',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ...timeline.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(width: 2, height: 80, color: AppColors.border),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.date,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: AppColors.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VaccinationScreen extends StatelessWidget {
  const VaccinationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carné de vacunación')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.vaccines_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Carnet digital',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Firulais',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text('Perro · Labrador · 4 años'),
                const SizedBox(height: AppSpacing.md),
                _VaccinePill(label: 'Antirrábica', due: 'Vence: 12/09/2026'),
                const SizedBox(height: AppSpacing.sm),
                _VaccinePill(label: 'Polivalente', due: 'Vence: 10/08/2026'),
                const SizedBox(height: AppSpacing.lg),
                AppButton(label: 'Compartir carné', onPressed: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _InventoryItem(
        name: 'Antibiótico',
        stock: '18 unidades',
        status: 'Stock bajo',
      ),
      _InventoryItem(
        name: 'Desparasitante',
        stock: '35 unidades',
        status: 'Normal',
      ),
      _InventoryItem(name: 'Vacunas', stock: '9 unidades', status: 'Bajo'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.medication_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.stock,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    AppStatusChip(
                      status: item.status == 'Normal'
                          ? AppStatus.completed
                          : AppStatus.pending,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final invoices = [
      _InvoiceItem(number: 'FAC-1048', client: 'Ana Gómez', total: '\$185.000'),
      _InvoiceItem(number: 'FAC-1049', client: 'Luis Pérez', total: '\$92.000'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Facturación')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingresos del mes',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '\$2.480.000',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ...invoices.map(
            (invoice) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.number,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            invoice.client,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      invoice.total,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Generar factura', onPressed: () {}),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              Icon(Icons.arrow_upward_rounded, color: color, size: 18),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.destination,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Widget destination;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => destination)),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentCard {
  const _AppointmentCard({
    required this.name,
    required this.subtitle,
    required this.time,
    required this.status,
  });

  final String name;
  final String subtitle;
  final String time;
  final AppStatus status;
}

class _PatientRow {
  const _PatientRow({
    required this.name,
    required this.species,
    required this.note,
    required this.avatar,
  });

  final String name;
  final String species;
  final String note;
  final String avatar;
}

class _PatientCard {
  const _PatientCard({
    required this.name,
    required this.species,
    required this.age,
    required this.status,
  });

  final String name;
  final String species;
  final String age;
  final String status;
}

class _AgendaItem {
  const _AgendaItem({
    required this.title,
    required this.patient,
    required this.time,
  });

  final String title;
  final String patient;
  final String time;
}

class _TimelineItem {
  const _TimelineItem({
    required this.date,
    required this.title,
    required this.description,
  });

  final String date;
  final String title;
  final String description;
}

class _InventoryItem {
  const _InventoryItem({
    required this.name,
    required this.stock,
    required this.status,
  });

  final String name;
  final String stock;
  final String status;
}

class _InvoiceItem {
  const _InvoiceItem({
    required this.number,
    required this.client,
    required this.total,
  });

  final String number;
  final String client;
  final String total;
}

class _VaccinePill extends StatelessWidget {
  const _VaccinePill({required this.label, required this.due});

  final String label;
  final String due;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            due,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}
