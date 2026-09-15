import 'package:flutter/material.dart';

import 'data/gateway_api.dart';

const _canvas = Color(0xff0f1118);
const _panel = Color(0xff181b25);
const _panelRaised = Color(0xff202533);
const _line = Color(0xff2c3342);
const _ink = Color(0xfff3f6fc);
const _muted = Color(0xff9ca7ba);
const _signal = Color(0xff64e6c1);
const _warning = Color(0xffffc65a);
const _danger = Color(0xffff7777);

void main() => runApp(const InventoryWebApp());

class InventoryWebApp extends StatefulWidget {
  const InventoryWebApp({super.key});
  @override
  State<InventoryWebApp> createState() => _InventoryWebAppState();
}

class _InventoryWebAppState extends State<InventoryWebApp> {
  String? token;
  final api = GatewayApi();

  Future<void> logout() async {
    final currentToken = token;
    try {
      if (currentToken != null) {
        await api.post('/api/v1/auth/logout', currentToken, {});
      }
    } catch (_) {
      // The local sign-out must still succeed when the gateway is unavailable.
    } finally {
      if (mounted) setState(() => token = null);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Lightbenders Inventory',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _signal,
        onPrimary: _canvas,
        surface: _panel,
        onSurface: _ink,
        error: _danger,
      ),
      scaffoldBackgroundColor: _canvas,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: _canvas,
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -.6,
          color: _ink,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -.2,
          color: _ink,
        ),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: _ink),
        bodyMedium: TextStyle(color: _ink),
        bodySmall: TextStyle(color: _muted),
        labelLarge: TextStyle(fontWeight: FontWeight.w700),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: _line),
        ),
        color: _panel,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: _panelRaised,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _signal, width: 1.5),
        ),
        labelStyle: TextStyle(color: _muted),
        hintStyle: TextStyle(color: _muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _signal,
          foregroundColor: _canvas,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: _line),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: _line, space: 1),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: _panel,
        indicatorColor: Color(0xff24483f),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      useMaterial3: true,
    ),
    home: token == null
        ? LoginPage(api: api, onLogin: (value) => setState(() => token = value))
        : Workstation(api: api, token: token!, onLogout: logout),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.api, required this.onLogin});
  final GatewayApi api;
  final ValueChanged<String> onLogin;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final username = TextEditingController(text: 'Administrator');
  final password = TextEditingController();
  String? error;
  bool loading = false;
  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final body = await widget.api.login(username.text.trim(), password.text);
      widget.onLogin(body['accessToken'] as String);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandMark(),
                    const SizedBox(height: 28),
                    Text(
                      'Sign in to inventory',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Equipment, rentals, and returns — connected to ERPNext.',
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: username,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: true,
                      onSubmitted: (_) => login(),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _InlineNotice(message: error!, color: _danger),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: loading ? null : login,
                      child: Text(loading ? 'Signing in…' : 'Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /*
  Widget _buildScanOut(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan out equipment')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: data,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final customers = snapshot.data!.where((value) => !value.containsKey('_item')).toList();
        return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: ListView(padding: const EdgeInsets.all(24), children: [
          Text('Create rental & scan out', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8), const Text('Choose the client and rental dates, then scan every item leaving the store.'), const SizedBox(height: 24),
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('1 · Rental details', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 12),
            DropdownButtonFormField<String>(initialValue: customer, decoration: const InputDecoration(labelText: 'Client'), items: customers.map((value) => DropdownMenuItem(value: value['name'] as String, child: Text(value['customer_name'] as String? ?? value['name'] as String))).toList(), onChanged: (value) => setState(() => customer = value)),
            const SizedBox(height: 12), Row(children: [Expanded(child: TextField(controller: start, decoration: const InputDecoration(labelText: 'Start date'))), const SizedBox(width: 12), Expanded(child: TextField(controller: end, decoration: const InputDecoration(labelText: 'Return date')))]),
          ]))), const SizedBox(height: 16),
          Card(color: const Color(0xffe4f2ee), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('2 · Scan equipment', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 6), const Text('Keep the cursor here. Your scanner adds each item when it sends Enter.'), const SizedBox(height: 14),
            TextField(controller: outgoingScanner, focusNode: outgoingFocus, autofocus: true, onSubmitted: scanOutgoing, decoration: const InputDecoration(labelText: 'Ready to scan', prefixIcon: Icon(Icons.qr_code_scanner))),
            const SizedBox(height: 12), Text('${outgoingBarcodes.length} item${outgoingBarcodes.length == 1 ? '' : 's'} scanned', style: Theme.of(context).textTheme.titleLarge),
          ]))), const SizedBox(height: 16),
          if (lines.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No equipment scanned yet.')), ...lines.asMap().entries.map((entry) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: const Icon(Icons.inventory_2_outlined), title: Text('${entry.value['item_code']} · ${entry.value['qty']}'), subtitle: Text(entry.value['serial_no'] as String? ?? 'Quantity item'), trailing: IconButton(icon: const Icon(Icons.close), tooltip: 'Remove', onPressed: () => setState(() { lines.removeAt(entry.key); outgoingBarcodes.removeAt(entry.key); })))),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))), const SizedBox(height: 16),
          FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.arrow_outward), label: Text(saving ? 'Checking out…' : 'Create rental and check out')),
        ])));
      },
    ),
  );
}
  */
}

class Workstation extends StatefulWidget {
  const Workstation({
    super.key,
    required this.api,
    required this.token,
    required this.onLogout,
  });
  final GatewayApi api;
  final String token;
  final Future<void> Function() onLogout;
  @override
  State<Workstation> createState() => _WorkstationState();
}

class _WorkstationState extends State<Workstation> {
  int section = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      EquipmentList(api: widget.api, token: widget.token),
      RentalList(api: widget.api, token: widget.token),
      CustomerList(api: widget.api, token: widget.token),
    ];
    final names = ['Equipment', 'Rentals', 'Customers'];
    return LayoutBuilder(
      builder: (context, size) {
        final desktop = size.maxWidth >= 820;
        return Scaffold(
          appBar: desktop
              ? null
              : AppBar(
                  title: Text(names[section]),
                  actions: [_AccountMenu(onLogout: widget.onLogout)],
                ),
          body: Row(
            children: [
              if (desktop)
                _SideNavigation(
                  selectedIndex: section,
                  onChanged: (value) => setState(() => section = value),
                  onLogout: widget.onLogout,
                ),
              Expanded(
                child: Column(
                  children: [
                    if (desktop) _DesktopTopBar(title: names[section]),
                    Expanded(child: pages[section]),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: section,
                  onDestinationSelected: (value) =>
                      setState(() => section = value),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      label: 'Equipment',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      label: 'Rentals',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_outline),
                      label: 'Clients',
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class EquipmentList extends StatefulWidget {
  const EquipmentList({super.key, required this.api, required this.token});
  final GatewayApi api;
  final String token;
  @override
  State<EquipmentList> createState() => _EquipmentListState();
}

class _EquipmentListState extends State<EquipmentList> {
  late Future<List<Map<String, dynamic>>> equipment;
  @override
  void initState() {
    super.initState();
    equipment = widget.api.list('/api/v1/items', 'items', widget.token);
  }

  Future<void> addEquipment() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EquipmentForm(api: widget.api, token: widget.token),
      ),
    );
    if (created == true && mounted) {
      setState(
        () =>
            equipment = widget.api.list('/api/v1/items', 'items', widget.token),
      );
    }
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
    eyebrow: 'CATALOGUE',
    title: 'Equipment library',
    description: 'Every rentable item currently synced from ERPNext.',
    action: FilledButton.icon(
      onPressed: addEquipment,
      icon: const Icon(Icons.add),
      label: const Text('Add equipment'),
    ),
    child: DataList(
      future: equipment,
      emptyTitle: 'No equipment found',
      item: (item) => _DataRow(
        icon: item['has_serial_no'] == 1
            ? Icons.qr_code_2
            : Icons.inventory_2_outlined,
        title: item['item_name'] as String? ?? item['item_code'] as String,
        subtitle:
            '${item['item_code']} · ${item['item_group']} · ${item['actual_qty'] ?? 0} in store',
        trailing: _Tag(
          label: item['has_serial_no'] == 1 ? 'Serialized' : 'Quantity',
          color: item['has_serial_no'] == 1 ? _signal : _muted,
        ),
      ),
    ),
  );
}

class EquipmentForm extends StatefulWidget {
  const EquipmentForm({
    super.key,
    required this.api,
    required this.token,
    this.initialBarcode,
  });
  final GatewayApi api;
  final String token;
  final String? initialBarcode;
  @override
  State<EquipmentForm> createState() => _EquipmentFormState();
}

class _EquipmentFormState extends State<EquipmentForm> {
  final itemCode = TextEditingController();
  final itemName = TextEditingController();
  final category = TextEditingController();
  final barcode = TextEditingController();
  final assetId = TextEditingController();
  final quantity = TextEditingController(text: '1');
  String trackingMode = 'serialized';
  String? error;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    barcode.text = widget.initialBarcode ?? '';
  }

  @override
  void dispose() {
    itemCode.dispose();
    itemName.dispose();
    category.dispose();
    barcode.dispose();
    assetId.dispose();
    quantity.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.api.post('/api/v1/items', widget.token, {
        'itemCode': itemCode.text.trim(),
        'itemName': itemName.text.trim(),
        'category': category.text.trim(),
        'trackingMode': trackingMode,
        'barcode': barcode.text.trim(),
        'assetId': assetId.text.trim(),
        'quantity': double.tryParse(quantity.text.trim()),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add equipment')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Register physical equipment',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'This receives the equipment into ERPNext inventory. Use the exact barcode printed on the equipment.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: itemCode,
              decoration: const InputDecoration(labelText: 'Equipment code'),
            ),
            TextField(
              controller: itemName,
              decoration: const InputDecoration(labelText: 'Equipment name'),
            ),
            TextField(
              controller: category,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            DropdownButtonFormField<String>(
              initialValue: trackingMode,
              decoration: const InputDecoration(labelText: 'Tracking'),
              items: const [
                DropdownMenuItem(
                  value: 'serialized',
                  child: Text('Serialized — one physical unit'),
                ),
                DropdownMenuItem(
                  value: 'quantity',
                  child: Text('Quantity — identical units'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => trackingMode = value ?? 'serialized'),
            ),
            TextField(
              controller: barcode,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Physical barcode'),
            ),
            if (trackingMode == 'serialized')
              TextField(
                controller: assetId,
                decoration: const InputDecoration(
                  labelText: 'Asset ID / serial number',
                ),
              ),
            if (trackingMode == 'quantity')
              TextField(
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Initial quantity',
                ),
              ),
            if (error != null) _InlineNotice(message: error!, color: _danger),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Adding…' : 'Add to ERPNext inventory'),
            ),
          ],
        ),
      ),
    ),
  );
}

class CustomerList extends StatelessWidget {
  const CustomerList({super.key, required this.api, required this.token});
  final GatewayApi api;
  final String token;
  @override
  Widget build(BuildContext context) => _PageFrame(
    eyebrow: 'RELATIONSHIPS',
    title: 'Clients',
    description: 'The people and companies you rent equipment to.',
    action: FilledButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerForm(api: api, token: token),
        ),
      ),
      icon: const Icon(Icons.person_add),
      label: const Text('Add client'),
    ),
    child: DataList(
      future: api.list('/api/v1/customers', 'customers', token),
      emptyTitle: 'No clients yet',
      item: (item) => _DataRow(
        icon: Icons.person_outline,
        title: item['customer_name'] as String? ?? item['name'] as String,
        subtitle: item['email_id'] as String? ?? 'No email address',
      ),
    ),
  );
}

class RentalList extends StatelessWidget {
  const RentalList({super.key, required this.api, required this.token});
  final GatewayApi api;
  final String token;
  @override
  Widget build(BuildContext context) => _PageFrame(
    eyebrow: 'RENTAL DESK',
    title: 'Rentals',
    description: 'Create reservations, issue gear, and handle returns.',
    action: Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QuickCheckIn(api: api, token: token),
            ),
          ),
          icon: const Icon(Icons.keyboard_return),
          label: const Text('Quick check-in'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RentalForm(api: api, token: token),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('New rental'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  RentalForm(api: api, token: token, checkoutInitially: true),
            ),
          ),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan out now'),
        ),
      ],
    ),
    child: DataList(
      future: api.list('/api/v1/rentals', 'rentals', token),
      emptyTitle: 'No rentals found',
      item: (item) => _DataRow(
        icon: Icons.receipt_long_outlined,
        title: item['name'] as String,
        subtitle:
            '${item['customer']} · ${item['start_date']} → ${item['end_date']}',
        trailing: _Tag(
          label: item['status'] as String,
          color: _statusColor(item['status'] as String),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RentalScanner(
              api: api,
              token: token,
              rental: item['name'] as String,
              checkout: item['status'] == 'Reserved',
            ),
          ),
        ),
      ),
    ),
  );
}

class DataList extends StatelessWidget {
  const DataList({
    super.key,
    required this.future,
    required this.item,
    required this.emptyTitle,
  });
  final Future<List<Map<String, dynamic>>> future;
  final Widget Function(Map<String, dynamic>) item;
  final String emptyTitle;
  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator(color: _signal));
      }
      if (snapshot.hasError) {
        return _EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load this view',
          subtitle: snapshot.error.toString(),
        );
      }
      final values = snapshot.data ?? [];
      if (values.isEmpty)
        return _EmptyState(
          icon: Icons.inventory_2_outlined,
          title: emptyTitle,
          subtitle: 'When records are added in ERPNext, they will appear here.',
        );
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: values.length,
        separatorBuilder: (_, index) => const SizedBox(height: 8),
        itemBuilder: (_, index) => item(values[index]),
      );
    },
  );
}

class CustomerForm extends StatefulWidget {
  const CustomerForm({super.key, required this.api, required this.token});
  final GatewayApi api;
  final String token;
  @override
  State<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<CustomerForm> {
  final name = TextEditingController();
  final email = TextEditingController();
  final mobile = TextEditingController();
  String? error;
  bool saving = false;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    mobile.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.api.post('/api/v1/customers', widget.token, {
        'customerName': name.text.trim(),
        'email': email.text.trim(),
        'mobileNo': mobile.text.trim(),
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add client')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Client profile',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Add the details used for rental reservations and communication.',
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Client name'),
                  ),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  TextField(
                    controller: mobile,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Mobile'),
                  ),
                  if (error != null)
                    _InlineNotice(message: error!, color: _danger),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: saving ? null : save,
                    child: Text(saving ? 'Saving…' : 'Save client'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class RentalForm extends StatefulWidget {
  const RentalForm({
    super.key,
    required this.api,
    required this.token,
    this.checkoutInitially = false,
  });
  final GatewayApi api;
  final String token;
  final bool checkoutInitially;
  @override
  State<RentalForm> createState() => _RentalFormState();
}

class _RentalFormState extends State<RentalForm> {
  late Future<List<Map<String, dynamic>>> data;
  final start = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final end = TextEditingController(
    text: DateTime.now()
        .add(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10),
  );
  final notes = TextEditingController();
  final qty = TextEditingController(text: '1');
  final outgoingScanner = TextEditingController();
  final outgoingFocus = FocusNode();
  String? customer, itemCode, serialNo, error;
  bool serialized = true, saving = false;
  bool registeringEquipment = false;
  late bool checkoutNow;
  final lines = <Map<String, dynamic>>[];
  final outgoingBarcodes = <String>[];
  @override
  void initState() {
    super.initState();
    checkoutNow = widget.checkoutInitially;
    data =
        Future.wait([
          widget.api.list('/api/v1/customers', 'customers', widget.token),
          widget.api.list('/api/v1/items', 'items', widget.token),
        ]).then(
          (value) => [
            ...value[0],
            ...value[1].map((item) => {'_item': item}),
          ],
        );
  }

  @override
  void dispose() {
    start.dispose();
    end.dispose();
    notes.dispose();
    qty.dispose();
    outgoingScanner.dispose();
    outgoingFocus.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> serials() => itemCode == null
      ? Future.value([])
      : widget.api.list(
          '/api/v1/items/${Uri.encodeComponent(itemCode!)}/serials',
          'serials',
          widget.token,
        );
  void addLine() {
    if (itemCode == null || (serialized && serialNo == null)) {
      setState(() => error = 'Choose an item and serial number.');
      return;
    }
    setState(() {
      lines.add({
        'line_type': serialized ? 'serialized' : 'qty',
        'item_code': itemCode,
        if (serialized) 'serial_no': serialNo,
        'qty': serialized ? 1 : double.tryParse(qty.text) ?? 0,
      });
      serialNo = null;
      error = null;
    });
  }

  void addScannedEquipment(Map<String, dynamic> lookup, String barcode) {
    final serializedLookup = lookup['type'] == 'serialized';
    final detail =
        lookup[serializedLookup ? 'serial' : 'item'] as Map<String, dynamic>;
    setState(() {
      outgoingBarcodes.add(barcode);
      if (serializedLookup) {
        lines.add({
          'line_type': 'serialized',
          'item_code': detail['item_code'],
          'serial_no': detail['name'],
          'qty': 1,
        });
      } else {
        Map<String, dynamic>? existing;
        for (final line in lines) {
          if (line['line_type'] == 'qty' &&
              line['item_code'] == detail['item_code']) {
            existing = line;
            break;
          }
        }
        if (existing == null) {
          lines.add({
            'line_type': 'qty',
            'item_code': detail['item_code'],
            'qty': 1,
          });
        } else {
          existing['qty'] = (existing['qty'] as num) + 1;
        }
      }
    });
  }

  Future<void> scanOutgoing(String value) async {
    final barcode = value.trim();
    if (barcode.isEmpty || registeringEquipment) return;
    outgoingScanner.clear();
    try {
      final lookup = await widget.api.get(
        '/api/v1/barcodes/${Uri.encodeComponent(barcode)}',
        widget.token,
      );
      addScannedEquipment(lookup, barcode);
    } catch (e) {
      if (e is GatewayException && e.statusCode == 404 && mounted) {
        setState(() {
          registeringEquipment = true;
          error = null;
        });
        try {
          await widget.api.post(
            '/api/v1/barcodes/${Uri.encodeComponent(barcode)}/register',
            widget.token,
            {},
          );
          final lookup = await widget.api.get(
            '/api/v1/barcodes/${Uri.encodeComponent(barcode)}',
            widget.token,
          );
          if (mounted) addScannedEquipment(lookup, barcode);
        } catch (registrationError) {
          if (mounted) setState(() => error = registrationError.toString());
        } finally {
          if (mounted) setState(() => registeringEquipment = false);
        }
      } else if (mounted) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted) outgoingFocus.requestFocus();
    }
  }

  Future<void> save() async {
    if (customer == null || lines.isEmpty) {
      setState(() => error = 'Choose a client and add at least one line.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = await widget.api.post('/api/v1/rentals', widget.token, {
        'customer': customer,
        'startDate': start.text,
        'endDate': end.text,
        'notes': notes.text,
        'items': lines,
      });
      final rental = result['rental'] as Map<String, dynamic>;
      await widget.api.post(
        '/api/v1/rentals/${Uri.encodeComponent(rental['name'] as String)}/submit',
        widget.token,
        {},
      );
      if (checkoutNow) {
        await widget.api.post(
          '/api/v1/rentals/${Uri.encodeComponent(rental['name'] as String)}/checkout/commit',
          widget.token,
          {
            'barcodes': outgoingBarcodes,
            'requestId': 'web-${DateTime.now().microsecondsSinceEpoch}',
          },
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (checkoutNow) return _buildScanOut(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New rental')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final customers = snapshot.data!
              .where((value) => !value.containsKey('_item'))
              .toList();
          final items = snapshot.data!
              .where((value) => value.containsKey('_item'))
              .map((value) => value['_item'] as Map<String, dynamic>)
              .toList();
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DropdownButtonFormField<String>(
                initialValue: customer,
                decoration: const InputDecoration(labelText: 'Client'),
                items: customers
                    .map(
                      (value) => DropdownMenuItem(
                        value: value['name'] as String,
                        child: Text(
                          value['customer_name'] as String? ??
                              value['name'] as String,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => customer = value),
              ),
              TextField(
                controller: start,
                decoration: const InputDecoration(
                  labelText: 'Start date (YYYY-MM-DD)',
                ),
              ),
              TextField(
                controller: end,
                decoration: const InputDecoration(
                  labelText: 'End date (YYYY-MM-DD)',
                ),
              ),
              TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              SwitchListTile(
                value: checkoutNow,
                title: const Text('Check out now with scanner'),
                subtitle: const Text(
                  'Scans become the rental items and are moved out immediately.',
                ),
                onChanged: (value) => setState(() => checkoutNow = value),
              ),
              if (checkoutNow)
                TextField(
                  controller: outgoingScanner,
                  focusNode: outgoingFocus,
                  autofocus: true,
                  onSubmitted: scanOutgoing,
                  decoration: InputDecoration(
                    labelText: 'Scan equipment leaving inventory',
                    helperText: 'Scanned: ${outgoingBarcodes.length}',
                  ),
                ),
              const Divider(height: 36),
              SwitchListTile(
                value: serialized,
                title: const Text('Serialized item'),
                onChanged: (value) => setState(() {
                  serialized = value;
                  serialNo = null;
                }),
              ),
              DropdownButtonFormField<String>(
                initialValue: itemCode,
                decoration: const InputDecoration(labelText: 'Equipment'),
                items: items
                    .map(
                      (value) => DropdownMenuItem(
                        value: value['item_code'] as String,
                        child: Text(
                          '${value['item_code']} — ${value['item_name']}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  itemCode = value;
                  serialNo = null;
                }),
              ),
              if (serialized)
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: serials(),
                  builder: (context, serialSnapshot) =>
                      DropdownButtonFormField<String>(
                        initialValue: serialNo,
                        decoration: const InputDecoration(
                          labelText: 'Serial number',
                        ),
                        items: (serialSnapshot.data ?? [])
                            .map(
                              (value) => DropdownMenuItem(
                                value: value['name'] as String,
                                child: Text(
                                  '${value['name']} ${value['barcode_payload'] == null ? '' : '· ${value['barcode_payload']}'}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => serialNo = value),
                      ),
                )
              else
                TextField(
                  controller: qty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
              OutlinedButton.icon(
                onPressed: addLine,
                icon: const Icon(Icons.add),
                label: const Text('Add line'),
              ),
              ...lines.asMap().entries.map(
                (entry) => ListTile(
                  title: Text(
                    '${entry.value['item_code']} · ${entry.value['qty']}',
                  ),
                  subtitle: Text(
                    entry.value['serial_no'] as String? ?? 'Quantity item',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => lines.removeAt(entry.key)),
                  ),
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: saving ? null : save,
                child: Text(
                  saving
                      ? 'Creating…'
                      : checkoutNow
                      ? 'Create and check out'
                      : 'Create reservation',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScanOut(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan out equipment')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: data,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final customers = snapshot.data!
            .where((value) => !value.containsKey('_item'))
            .toList();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Create rental & scan out',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose the client and dates, then scan equipment. No serial setup is needed.',
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '1 · Rental details',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: customer,
                          decoration: const InputDecoration(
                            labelText: 'Client',
                          ),
                          items: customers
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value['name'] as String,
                                  child: Text(
                                    value['customer_name'] as String? ??
                                        value['name'] as String,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => customer = value),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final startField = TextField(
                              controller: start,
                              decoration: const InputDecoration(
                                labelText: 'Start date',
                              ),
                            );
                            final endField = TextField(
                              controller: end,
                              decoration: const InputDecoration(
                                labelText: 'Return date',
                              ),
                            );
                            if (constraints.maxWidth < 460) {
                              return Column(
                                children: [
                                  startField,
                                  const SizedBox(height: 12),
                                  endField,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: startField),
                                const SizedBox(width: 12),
                                Expanded(child: endField),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xffe4f2ee),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '2 · Scan equipment',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: outgoingScanner,
                          focusNode: outgoingFocus,
                          autofocus: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          onSubmitted: scanOutgoing,
                          decoration: const InputDecoration(
                            labelText: 'Ready to scan',
                            prefixIcon: Icon(Icons.qr_code_scanner),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          registeringEquipment
                              ? 'Adding new equipment to ERPNext…'
                              : '${outgoingBarcodes.length} scanned',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                for (final entry in lines.asMap().entries)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        '${entry.value['item_code']} · ${entry.value['qty']}',
                      ),
                      subtitle: Text(
                        entry.value['serial_no'] as String? ?? 'Quantity item',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            setState(() => lines.removeAt(entry.key)),
                      ),
                    ),
                  ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: const Icon(Icons.arrow_outward),
                  label: Text(
                    saving ? 'Checking out…' : 'Create rental and check out',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class QuickCheckIn extends StatefulWidget {
  const QuickCheckIn({super.key, required this.api, required this.token});
  final GatewayApi api;
  final String token;
  @override
  State<QuickCheckIn> createState() => _QuickCheckInState();
}

class _QuickCheckInState extends State<QuickCheckIn> {
  final scanner = TextEditingController();
  final focus = FocusNode();
  String? selectedRental;
  String? error;
  late Future<List<Map<String, dynamic>>> activeRentals;
  @override
  void initState() {
    super.initState();
    activeRentals = widget.api
        .list('/api/v1/rentals', 'rentals', widget.token)
        .then(
          (rentals) => rentals
              .where(
                (rental) => [
                  'Active',
                  'Partially Returned',
                  'Overdue',
                ].contains(rental['status']),
              )
              .toList(),
        );
  }

  @override
  void dispose() {
    scanner.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> startReturn(String value) async {
    final barcode = value.trim();
    if (barcode.isEmpty || selectedRental == null) return;
    scanner.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RentalScanner(
          api: widget.api,
          token: widget.token,
          rental: selectedRental!,
          checkout: false,
          initialBarcodes: [barcode],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quick check-in')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: activeRentals,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Check equipment back in',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'First choose the active rental. Then scan every item that has come back.',
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '1 · Select rental',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedRental,
                          hint: const Text('Choose an active rental'),
                          items: snapshot.data!
                              .map(
                                (rental) => DropdownMenuItem(
                                  value: rental['name'] as String,
                                  child: Text(
                                    '${rental['name']} · ${rental['customer']}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() {
                            selectedRental = value;
                            error = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '2 · Scan returned equipment',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: scanner,
                          focusNode: focus,
                          autofocus: true,
                          enabled: selectedRental != null,
                          onSubmitted: startReturn,
                          decoration: InputDecoration(
                            labelText: selectedRental == null
                                ? 'Select a rental first'
                                : 'Scan first returned item',
                            prefixIcon: const Icon(Icons.qr_code_scanner),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class RentalScanner extends StatefulWidget {
  const RentalScanner({
    super.key,
    required this.api,
    required this.token,
    required this.rental,
    required this.checkout,
    this.initialBarcodes = const [],
  });
  final GatewayApi api;
  final String token, rental;
  final bool checkout;
  final List<String> initialBarcodes;
  @override
  State<RentalScanner> createState() => _RentalScannerState();
}

class _RentalScannerState extends State<RentalScanner> {
  final scanner = TextEditingController();
  final focus = FocusNode();
  final barcodes = <String>[];
  String disposition = 'returned';
  String? result;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    barcodes.addAll(widget.initialBarcodes);
    WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
  }

  @override
  void dispose() {
    scanner.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> scan(String value) async {
    final barcode = value.trim();
    if (barcode.isEmpty) {
      return;
    }
    setState(() {
      barcodes.add(barcode);
      scanner.clear();
    });
    try {
      final preview = await widget.api.post(
        '/api/v1/rentals/${Uri.encodeComponent(widget.rental)}/${widget.checkout ? 'checkout' : 'return'}/preview',
        widget.token,
        {'barcodes': barcodes},
      );
      if (mounted) {
        setState(
          () => result =
              'Scanned ${preview['scanned'].length}; missing ${preview['missing'].length}; unknown ${preview['unknown'].length}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => result = e.toString());
      }
    } finally {
      focus.requestFocus();
    }
  }

  Future<void> commit() async {
    if (barcodes.isEmpty) {
      setState(() => result = 'Scan at least one barcode before committing.');
      return;
    }
    setState(() => loading = true);
    try {
      final data = await widget.api.post(
        '/api/v1/rentals/${Uri.encodeComponent(widget.rental)}/${widget.checkout ? 'checkout' : 'return'}/commit',
        widget.token,
        {
          'barcodes': barcodes,
          'requestId': 'web-${DateTime.now().microsecondsSinceEpoch}',
          if (!widget.checkout) 'disposition': disposition,
        },
      );
      if (mounted) {
        setState(
          () =>
              result = 'Committed ${data['stock_entry'] ?? data['operation']}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => result = e.toString());
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${widget.checkout ? 'Checkout' : 'Return'} ${widget.rental}',
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.checkout ? 'Issue equipment' : 'Receive equipment',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                widget.checkout
                    ? 'Scan each item leaving the store. Review the live result, then commit.'
                    : 'Scan returned items and choose their condition before committing.',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'SCAN STATION',
                        style: TextStyle(
                          color: _signal,
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: scanner,
                        focusNode: focus,
                        autofocus: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        onSubmitted: scan,
                        decoration: const InputDecoration(
                          labelText: 'Scan barcode',
                          hintText: 'Scanner appends Enter',
                          prefixIcon: Icon(Icons.qr_code_scanner),
                        ),
                      ),
                      if (!widget.checkout)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: DropdownButtonFormField(
                            initialValue: disposition,
                            decoration: const InputDecoration(
                              labelText: 'Disposition',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'returned',
                                child: Text('Good return'),
                              ),
                              DropdownMenuItem(
                                value: 'damaged',
                                child: Text('Damaged'),
                              ),
                              DropdownMenuItem(
                                value: 'lost',
                                child: Text('Lost'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => disposition = value!),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: const BoxDecoration(
                      color: _panelRaised,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Text(
                      '${barcodes.length} scanned',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: loading || barcodes.isEmpty ? null : commit,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      loading
                          ? 'Committing…'
                          : widget.checkout
                          ? 'Commit checkout'
                          : 'Commit return',
                    ),
                  ),
                ],
              ),
              if (result != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _InlineNotice(
                    message: result!,
                    color:
                        result!.startsWith('Scanned') ||
                            result!.startsWith('Committed')
                        ? _signal
                        : _danger,
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: barcodes.isEmpty
                    ? const _EmptyState(
                        icon: Icons.qr_code_scanner,
                        title: 'Scanner is ready',
                        subtitle:
                            'Use a connected barcode scanner or type a code and press Enter.',
                      )
                    : ListView.separated(
                        itemCount: barcodes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) => _DataRow(
                          icon: Icons.qr_code_2,
                          title: barcodes[index],
                          subtitle: 'Scan ${index + 1}',
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Remove scan',
                            onPressed: () =>
                                setState(() => barcodes.removeAt(index)),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: _signal,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: const Icon(Icons.lightbulb_outline, color: _canvas),
      ),
      const SizedBox(width: 12),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LIGHTBENDERS',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              fontSize: 12,
            ),
          ),
          Text(
            'Inventory operations',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    ],
  );
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.selectedIndex,
    required this.onChanged,
    required this.onLogout,
  });
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) => Container(
    width: 244,
    color: _panel,
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: _BrandMark(),
        ),
        const SizedBox(height: 40),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'WORKSPACE',
            style: TextStyle(
              color: _muted,
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _NavItem(
          icon: Icons.inventory_2_outlined,
          label: 'Equipment',
          selected: selectedIndex == 0,
          onTap: () => onChanged(0),
        ),
        _NavItem(
          icon: Icons.receipt_long_outlined,
          label: 'Rentals',
          selected: selectedIndex == 1,
          onTap: () => onChanged(1),
        ),
        _NavItem(
          icon: Icons.people_outline,
          label: 'Clients',
          selected: selectedIndex == 2,
          onTap: () => onChanged(2),
        ),
        const Spacer(),
        const Divider(),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout, size: 18),
          label: const Align(
            alignment: Alignment.centerLeft,
            child: Text('Sign out'),
          ),
          style: TextButton.styleFrom(
            foregroundColor: _muted,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Material(
      color: selected ? const Color(0xff24483f) : Colors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? _signal : _muted),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: selected ? _ink : _muted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Container(
    height: 76,
    padding: const EdgeInsets.symmetric(horizontal: 36),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _line)),
    ),
    child: Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        const Icon(Icons.cloud_done_outlined, size: 18, color: _signal),
        const SizedBox(width: 8),
        const Text(
          'ERPNext connected',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
      ],
    ),
  );
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.onLogout});
  final Future<void> Function() onLogout;
  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onLogout,
    tooltip: 'Sign out',
    icon: const Icon(Icons.logout),
  );
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.child,
    this.action,
  });
  final String eyebrow;
  final String title;
  final String description;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            final heading = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: const TextStyle(
                    color: _signal,
                    fontSize: 11,
                    letterSpacing: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(description, style: const TextStyle(color: _muted)),
              ],
            );
            if (compact || action == null)
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  if (action != null) ...[const SizedBox(height: 20), action!],
                ],
              );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: heading),
                const SizedBox(width: 20),
                action!,
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        Expanded(child: child),
      ],
    ),
  );
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: _panelRaised,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Icon(icon, color: _signal, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.chevron_right, color: _muted),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: const BorderRadius.all(Radius.circular(20)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message, required this.color});
  final String message;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: const BorderRadius.all(Radius.circular(10)),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: TextStyle(color: color, fontSize: 13)),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: _panelRaised,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Icon(icon, color: _signal),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted),
          ),
        ],
      ),
    ),
  );
}

Color _statusColor(String status) => switch (status) {
  'Active' => _signal,
  'Reserved' => _warning,
  'Overdue' => _danger,
  'Partially Returned' => _warning,
  _ => _muted,
};
