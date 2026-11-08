import 'package:dio/dio.dart';

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';



const purple = Color(0xFF54258A);

const apiBase = String.fromEnvironment(

  'SUQ_API',

  defaultValue: 'https://suq-silk.vercel.app/api',

);



late SharedPreferences prefs;

late SupplierApi api;



Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  prefs = await SharedPreferences.getInstance();

  api = SupplierApi(prefs.getString('supplier.token'));

  runApp(const SupplierApp());

}



class SupplierApi {

  SupplierApi(String? token)

    : dio = Dio(

        BaseOptions(

          baseUrl: apiBase,

          connectTimeout: const Duration(seconds: 30),

          receiveTimeout: const Duration(seconds: 45),

        ),

      ) {

    setToken(token);

  }

  final Dio dio;

  void setToken(String? token) {

    if (token == null || token.isEmpty) {

      dio.options.headers.remove('Authorization');

    } else {

      dio.options.headers['Authorization'] = 'Bearer $token';

    }

  }



  Future<Map<String, dynamic>> get(String path) async =>

      _map((await dio.get(path)).data);

  Future<Map<String, dynamic>> post(String path, Object body) async =>

      _map((await dio.post(path, data: body)).data);

  Future<Map<String, dynamic>> patch(String path, Object body) async =>

      _map((await dio.patch(path, data: body)).data);

  static Map<String, dynamic> _map(dynamic value) =>

      Map<String, dynamic>.from(value as Map);

}



class SupplierApp extends StatefulWidget {

  const SupplierApp({super.key});

  @override

  State<SupplierApp> createState() => _SupplierAppState();

}



class _SupplierAppState extends State<SupplierApp> {

  bool get _signedIn => prefs.getString('supplier.token')?.isNotEmpty == true;

  void _signedInNow(String token) {

    api.setToken(token);

    prefs.setString('supplier.token', token);

    setState(() {});

  }



  void _signOut() {

    api.setToken(null);

    prefs.remove('supplier.token');

    setState(() {});

  }



  @override

  Widget build(BuildContext context) => MaterialApp(

    title: 'SUQ Supplier',

    debugShowCheckedModeBanner: false,

    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: purple),
      scaffoldBackgroundColor: const Color(0xFFF8F6FB),
      useMaterial3: true,
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        margin: EdgeInsets.symmetric(vertical: 6),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8F6FB),
        foregroundColor: Color(0xFF21182D),
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: purple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),

    home: _signedIn

        ? SupplierHome(onSignOut: _signOut)

        : SupplierLogin(onLogin: _signedInNow),

  );

}



class SupplierLogin extends StatefulWidget {

  const SupplierLogin({required this.onLogin, super.key});

  final ValueChanged<String> onLogin;

  @override

  State<SupplierLogin> createState() => _SupplierLoginState();

}



class _SupplierLoginState extends State<SupplierLogin> {

  final _phone = TextEditingController(

    text: prefs.getString('supplier.phone') ?? '',

  );

  final _pin = TextEditingController();

  bool _busy = false;

  String? _error;

  @override

  void dispose() {

    _phone.dispose();

    _pin.dispose();

    super.dispose();

  }



  Future<void> _login() async {

    setState(() {

      _busy = true;

      _error = null;

    });

    try {

      final result = await api.post('/auth/login', {

        'phone': _phone.text.trim(),

        'pin': _pin.text,

      });

      final user = Map<String, dynamic>.from(result['user'] as Map);

      if (user['role'] != 'SUPPLIER')

        throw Exception('This account is not a supplier account.');

      final token = result['token'] as String?;

      if (token == null || token.isEmpty)

        throw Exception('The server did not return a session.');

      await prefs.setString('supplier.phone', _phone.text.trim());

      widget.onLogin(token);

    } on DioException catch (e) {

      setState(

        () => _error = e.response?.data is Map

            ? (e.response!.data['message']?.toString() ?? 'Could not sign in.')

            : 'Cannot reach the SUQ server. Check your connection.',

      );

    } catch (e) {

      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));

    } finally {

      if (mounted) setState(() => _busy = false);

    }

  }



  @override

  Widget build(BuildContext context) => Scaffold(

    body: Center(

      child: SingleChildScrollView(

        padding: const EdgeInsets.all(24),

        child: ConstrainedBox(

          constraints: const BoxConstraints(maxWidth: 410),

          child: Card(

            child: Padding(

              padding: const EdgeInsets.all(26),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [

                  const CircleAvatar(

                    radius: 34,

                    backgroundColor: purple,

                    child: Padding(

                      padding: EdgeInsets.all(12),

                      child: Image(

                        image: AssetImage('assets/branding/qaf_logo.png'),

                      ),

                    ),

                  ),

                  const SizedBox(height: 16),

                  const Text(

                    'SUQ SUPPLIER',

                    textAlign: TextAlign.center,

                    style: TextStyle(

                      fontSize: 23,

                      fontWeight: FontWeight.w900,

                      letterSpacing: 1,

                      color: purple,

                    ),

                  ),

                  const SizedBox(height: 5),

                  const Text(

                    'Sign in to manage your catalog and orders',

                    textAlign: TextAlign.center,

                    style: TextStyle(color: Colors.black54),

                  ),

                  const SizedBox(height: 24),

                  TextField(

                    controller: _phone,

                    keyboardType: TextInputType.phone,

                    decoration: const InputDecoration(

                      labelText: 'Phone number',

                      prefixIcon: Icon(Icons.phone_outlined),

                    ),

                  ),

                  const SizedBox(height: 12),

                  TextField(

                    controller: _pin,

                    obscureText: true,

                    keyboardType: TextInputType.number,

                    onSubmitted: (_) => _login(),

                    decoration: const InputDecoration(

                      labelText: 'PIN',

                      prefixIcon: Icon(Icons.lock_outline),

                    ),

                  ),

                  if (_error != null)

                    Padding(

                      padding: const EdgeInsets.only(top: 12),

                      child: Text(

                        _error!,

                        style: const TextStyle(color: Colors.red),

                      ),

                    ),

                  const SizedBox(height: 20),

                  FilledButton(

                    onPressed: _busy ? null : _login,

                    child: _busy

                        ? const SizedBox(

                            width: 20,

                            height: 20,

                            child: CircularProgressIndicator(strokeWidth: 2),

                          )

                        : const Text('Log in'),

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



class SupplierHome extends StatefulWidget {

  const SupplierHome({required this.onSignOut, super.key});

  final VoidCallback onSignOut;

  @override

  State<SupplierHome> createState() => _SupplierHomeState();

}



class _SupplierHomeState extends State<SupplierHome> {

  int _index = 0;

  void _changed() => setState(() {});

  @override

  Widget build(BuildContext context) {

    final pages = [

      ProductsPage(onChanged: _changed),

      ListingsPage(onChanged: _changed),

      const OrdersPage(),

      const DeliveryPage(),

    ];

    const labels = ['Products', 'Bulk listings', 'Orders', 'Delivery'];

    const icons = [

      Icons.inventory_2_outlined,

      Icons.sell_outlined,

      Icons.receipt_long_outlined,

      Icons.map_outlined,

    ];

    return Scaffold(

      appBar: AppBar(

        title: Text(

          labels[_index],

          style: const TextStyle(fontWeight: FontWeight.w800),

        ),

        actions: [

          IconButton(

            tooltip: 'Sign out',

            onPressed: widget.onSignOut,

            icon: const Icon(Icons.logout_rounded),

          ),

        ],

      ),

      body: IndexedStack(index: _index, children: pages),

      bottomNavigationBar: NavigationBar(

        selectedIndex: _index,

        onDestinationSelected: (i) => setState(() => _index = i),

        destinations: [

          for (var i = 0; i < labels.length; i++)

            NavigationDestination(icon: Icon(icons[i]), label: labels[i]),

        ],

      ),

    );

  }

}



class ProductsPage extends StatefulWidget {

  const ProductsPage({required this.onChanged, super.key});

  final VoidCallback onChanged;

  @override

  State<ProductsPage> createState() => _ProductsPageState();

}



class _ProductsPageState extends State<ProductsPage> {

  Future<Map<String, dynamic>> _data() async {

    final p = await api.get('/supplier/products');

    final c = await api.get('/supplier/categories');

    return {'products': p['products'], 'categories': c['categories']};

  }



  late Future<Map<String, dynamic>> _future = _data();

  void _refresh() => setState(() => _future = _data());

  Future<void> _createCategory() async {

    final name = await _textDialog(context, 'New category', 'Category name');

    if (name == null || name.trim().isEmpty) return;

    try {

      await api.post('/supplier/categories', {'name': name.trim()});

      _refresh();

    } catch (e) {

      _snack(context, 'Could not add category: $e');

    }

  }



  Future<void> _createProduct(List categories) async {

    if (categories.isEmpty) {

      _snack(context, 'Create a category first.');

      return;

    }

    final draft = await showDialog<Map<String, dynamic>>(

      context: context,

      builder: (_) => _ProductDialog(categories: categories),

    );

    if (draft == null) return;

    try {

      await api.post('/supplier/products', draft);

      _refresh();

      widget.onChanged();

    } catch (e) {

      _snack(context, 'Could not save product: $e');

    }

  }



  @override

  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(

    future: _future,

    builder: (context, snap) {

      if (snap.hasError) return _retry(snap.error.toString(), _refresh);

      if (!snap.hasData)

        return const Center(child: CircularProgressIndicator());

      final products = (snap.data!['products'] as List? ?? []);

      final categories = (snap.data!['categories'] as List? ?? []);

      return RefreshIndicator(

        onRefresh: () async => _refresh(),

        child: ListView(

          padding: const EdgeInsets.all(16),

          children: [

            Row(

              children: [

                Expanded(

                  child: Text(

                    '${products.length} products',

                    style: const TextStyle(fontWeight: FontWeight.w700),

                  ),

                ),

                TextButton.icon(

                  onPressed: _createCategory,

                  icon: const Icon(Icons.create_new_folder_outlined),

                  label: const Text('Category'),

                ),

                FilledButton.icon(

                  onPressed: () => _createProduct(categories),

                  icon: const Icon(Icons.add),

                  label: const Text('Product'),

                ),

              ],

            ),

            const SizedBox(height: 8),

            if (products.isEmpty)

              const Padding(

                padding: EdgeInsets.all(36),

                child: Text(

                  'Add products to your private library. Choose which ones to list for shop orders under Bulk listings.',

                  textAlign: TextAlign.center,

                ),

              )

            else

              for (final raw in products)

                _productTile(Map<String, dynamic>.from(raw)),

          ],

        ),

      );

    },

  );

  Widget _productTile(Map<String, dynamic> p) => Card(

    child: ListTile(

      leading: const CircleAvatar(

        backgroundColor: Color(0xFFEDE5F5),

        child: Icon(Icons.inventory_2_outlined, color: purple),

      ),

      title: Text(

        '${p['name']}',

        style: const TextStyle(fontWeight: FontWeight.w700),

      ),

      subtitle: Text(

        '${p['category']?['name'] ?? ''} ┬╖ ${p['sku']} ┬╖ sold by shop in ${p['unit']}',

      ),

      trailing: Text('Br ${p['defaultSellingPrice'] ?? 0} / ${p['unit']}'),

    ),

  );

}



class _ProductDialog extends StatefulWidget {

  const _ProductDialog({required this.categories});

  final List categories;

  @override

  State<_ProductDialog> createState() => _ProductDialogState();

}



class _ProductDialogState extends State<_ProductDialog> {

  final name = TextEditingController(),

      sku = TextEditingController(),

      unit = TextEditingController(text: 'pcs'),

      price = TextEditingController(text: '0');

  late String categoryId = (widget.categories.first as Map)['id'].toString();

  @override

  void dispose() {

    name.dispose();

    sku.dispose();

    unit.dispose();

    price.dispose();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) => AlertDialog(

    title: const Text('Add library product'),

    content: SizedBox(

      width: 420,

      child: SingleChildScrollView(

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            DropdownButtonFormField<String>(

              value: categoryId,

              decoration: const InputDecoration(labelText: 'Category'),

              items: [

                for (final c in widget.categories)

                  DropdownMenuItem(

                    value: (c as Map)['id'].toString(),

                    child: Text('${c['name']}'),

                  ),

              ],

              onChanged: (v) => setState(() => categoryId = v ?? categoryId),

            ),

            TextField(

              controller: name,

              decoration: const InputDecoration(labelText: 'Product name'),

            ),

            TextField(

              controller: sku,

              decoration: const InputDecoration(labelText: 'SKU'),

            ),

            TextField(

              controller: unit,

              decoration: const InputDecoration(

                labelText: 'Shop selling unit (pcs, kg, L...)',

              ),

            ),

            TextField(

              controller: price,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(

                labelText: 'Suggested shop price (ETB per unit)',

              ),

            ),

          ],

        ),

      ),

    ),

    actions: [

      TextButton(

        onPressed: () => Navigator.pop(context),

        child: const Text('Cancel'),

      ),

      FilledButton(

        onPressed: () {

          final p = double.tryParse(price.text);

          if (name.text.trim().isEmpty || sku.text.trim().isEmpty || p == null)

            return;

          Navigator.pop(context, {

            'categoryId': categoryId,

            'name': name.text.trim(),

            'sku': sku.text.trim(),

            'unit': unit.text.trim().isEmpty ? 'pcs' : unit.text.trim(),

            'defaultSellingPrice': p,

          });

        },

        child: const Text('Save'),

      ),

    ],

  );

}



class ListingsPage extends StatefulWidget {

  const ListingsPage({required this.onChanged, super.key});

  final VoidCallback onChanged;

  @override

  State<ListingsPage> createState() => _ListingsPageState();

}



class _ListingsPageState extends State<ListingsPage> {

  Future<Map<String, dynamic>> _load() async {

    final a = await api.get('/supplier/listings');

    final p = await api.get('/supplier/products');

    return {'listings': a['listings'], 'products': p['products']};

  }



  late Future<Map<String, dynamic>> _future = _load();

  void _refresh() => setState(() => _future = _load());

  Future<void> _add(List products, List listings) async {

    final listedIds = listings

        .map((e) => (e as Map)['productId'].toString())

        .toSet();

    final available = products

        .where((p) => !listedIds.contains((p as Map)['id'].toString()))

        .toList();

    if (available.isEmpty) {

      _snack(context, 'All your products are listed.');

      return;

    }

    final d = await showDialog<Map<String, dynamic>>(

      context: context,

      builder: (_) => _ListingDialog(products: available),

    );

    if (d == null) return;

    try {

      await api.post('/supplier/listings', d);

      _refresh();

      widget.onChanged();

    } catch (e) {

      _snack(context, 'Could not publish listing: $e');

    }

  }



  Future<void> _edit(Map<String, dynamic> listing) async {

    final product = Map<String, dynamic>.from(listing['product'] as Map);

    final result = await showDialog<Map<String, dynamic>>(

      context: context,

      builder: (_) => _ListingDialog(products: [product], initial: listing),

    );

    if (result == null) return;

    result.remove('productId');

    try {

      await api.patch('/supplier/listings/${listing['id']}', result);

      _refresh();

      widget.onChanged();

    } catch (error) {

      if (mounted) _snack(context, 'Could not update listing: $error');

    }

  }



  @override

  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(

    future: _future,

    builder: (context, s) {

      if (s.hasError) return _retry(s.error.toString(), _refresh);

      if (!s.hasData) return const Center(child: CircularProgressIndicator());

      final ls = (s.data!['listings'] as List? ?? []);

      final ps = (s.data!['products'] as List? ?? []);

      return RefreshIndicator(

        onRefresh: () async => _refresh(),

        child: ListView(

          padding: const EdgeInsets.all(16),

          children: [

            Row(

              children: [

                const Expanded(

                  child: Text(

                    'Shop order catalog',

                    style: TextStyle(fontWeight: FontWeight.w700),

                  ),

                ),

                FilledButton.icon(

                  onPressed: () => _add(ps, ls),

                  icon: const Icon(Icons.add),

                  label: const Text('List product'),

                ),

              ],

            ),

            const SizedBox(height: 10),

            if (ls.isEmpty)

              const Padding(

                padding: EdgeInsets.all(36),

                child: Text(

                  'Your product library stays private until you publish a bulk listing.',

                  textAlign: TextAlign.center,

                ),

              )

            else

              for (final x in ls) _listingTile(Map<String, dynamic>.from(x)),

          ],

        ),

      );

    },

  );

  Widget _listingTile(Map<String, dynamic> l) {

    final p = Map<String, dynamic>.from(l['product'] as Map);

    return Card(

      child: ListTile(

        title: Text(

          '${p['name']} ┬╖ ${l['packName']}',

          style: const TextStyle(fontWeight: FontWeight.w700),

        ),

        subtitle: Text(

          '${l['unitsPerPack']} ${p['unit']} per pack ┬╖ ${l['weightKg']} kg ┬╖ ${l['volumeCubicM']} m┬│',

        ),

        trailing: Row(

          mainAxisSize: MainAxisSize.min,

          children: [

            Column(

              mainAxisAlignment: MainAxisAlignment.center,

              crossAxisAlignment: CrossAxisAlignment.end,

              children: [

                Text(

                  'Br ${l['bulkPrice']}',

                  style: const TextStyle(fontWeight: FontWeight.w800),

                ),

                Text(

                  l['active'] == true ? 'Listed' : 'Hidden',

                  style: TextStyle(

                    color: l['active'] == true ? Colors.green : Colors.grey,

                    fontSize: 12,

                  ),

                ),

              ],

            ),

            IconButton(

              tooltip: l['active'] == true ? 'Hide listing' : 'Publish listing',

              onPressed: () => _toggle(l),

              icon: Icon(

                l['active'] == true

                    ? Icons.visibility_off_outlined

                    : Icons.visibility_outlined,

              ),

            ),

          ],

        ),

        onTap: () => _edit(l),

      ),

    );

  }



  Future<void> _toggle(Map<String, dynamic> l) async {

    try {

      await api.patch('/supplier/listings/${l['id']}', {

        'active': l['active'] != true,

      });

      _refresh();

    } catch (e) {

      _snack(context, 'Could not update listing: $e');

    }

  }

}



class _ListingDialog extends StatefulWidget {

  const _ListingDialog({required this.products, this.initial});

  final List products;

  final Map<String, dynamic>? initial;

  @override

  State<_ListingDialog> createState() => _ListingDialogState();

}



class _ListingDialogState extends State<_ListingDialog> {

  late String productId = (widget.products.first as Map)['id'].toString();

  late final TextEditingController pack;

  late final TextEditingController units;

  late final TextEditingController weight;

  late final TextEditingController volume;

  late final TextEditingController price;

  @override

  void initState() {

    super.initState();

    final listing = widget.initial;

    pack = TextEditingController(

      text: listing?['packName']?.toString() ?? 'Box',

    );

    units = TextEditingController(

      text: listing?['unitsPerPack']?.toString() ?? '12',

    );

    weight = TextEditingController(

      text: listing?['weightKg']?.toString() ?? '0',

    );

    volume = TextEditingController(

      text: listing?['volumeCubicM']?.toString() ?? '0',

    );

    price = TextEditingController(

      text: listing?['bulkPrice']?.toString() ?? '0',

    );

  }



  @override

  void dispose() {

    pack.dispose();

    units.dispose();

    weight.dispose();

    volume.dispose();

    price.dispose();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) => AlertDialog(

    title: const Text('Publish bulk listing'),

    content: SizedBox(

      width: 420,

      child: SingleChildScrollView(

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            if (widget.initial == null)

              DropdownButtonFormField<String>(

                value: productId,

                decoration: const InputDecoration(labelText: 'Library product'),

                items: [

                  for (final p in widget.products)

                    DropdownMenuItem(

                      value: (p as Map)['id'].toString(),

                      child: Text('${p['name']}'),

                    ),

                ],

                onChanged: (v) => setState(() => productId = v ?? productId),

              ),

            TextField(

              controller: pack,

              decoration: const InputDecoration(

                labelText: 'Pack sold to shops (e.g. dozen, 50kg bag)',

              ),

            ),

            TextField(

              controller: units,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(

                labelText: 'Retail units per pack',

              ),

            ),

            TextField(

              controller: price,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(

                labelText: 'Bulk price per pack (ETB)',

              ),

            ),

            TextField(

              controller: weight,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(labelText: 'Pack weight (kg)'),

            ),

            TextField(

              controller: volume,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(labelText: 'Pack volume (m┬│)'),

            ),

          ],

        ),

      ),

    ),

    actions: [

      TextButton(

        onPressed: () => Navigator.pop(context),

        child: const Text('Cancel'),

      ),

      FilledButton(

        onPressed: () {

          final u = double.tryParse(units.text),

              p = double.tryParse(price.text),

              w = double.tryParse(weight.text),

              v = double.tryParse(volume.text);

          if (pack.text.trim().isEmpty ||

              u == null ||

              u <= 0 ||

              p == null ||

              w == null ||

              v == null)

            return;

          Navigator.pop(context, {

            'productId': productId,

            'packName': pack.text.trim(),

            'unitsPerPack': u,

            'bulkPrice': p,

            'weightKg': w,

            'volumeCubicM': v,

          });

        },

        child: const Text('Publish'),

      ),

    ],

  );

}



class OrdersPage extends StatefulWidget {

  const OrdersPage({super.key});

  @override

  State<OrdersPage> createState() => _OrdersPageState();

}



class _OrdersPageState extends State<OrdersPage> {

  late Future<List> _future = _load();

  Future<List> _load() async =>

      (await api.get('/supplier/orders'))['orders'] as List;

  void _refresh() => setState(() => _future = _load());

  Future<void> _status(String id, String value) async {

    try {

      await api.patch('/supplier/orders/$id/status', {'status': value});

      _refresh();

    } catch (e) {

      _snack(context, 'Could not update order: $e');

    }

  }



  Future<void> _quote(Map<String, dynamic> order) async {

    final controller = TextEditingController(

      text: '${order['deliveryFee'] ?? 0}',

    );

    final fee = await showDialog<double>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: const Text('Set delivery quote'),

        content: TextField(

          controller: controller,

          autofocus: true,

          keyboardType: const TextInputType.numberWithOptions(decimal: true),

          decoration: const InputDecoration(

            labelText: 'Full delivery fee (ETB)',

          ),

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(ctx),

            child: const Text('Cancel'),

          ),

          FilledButton(

            onPressed: () =>

                Navigator.pop(ctx, double.tryParse(controller.text.trim())),

            child: const Text('Save quote'),

          ),

        ],

      ),

    );

    controller.dispose();

    if (fee == null || fee < 0 || !mounted) return;

    try {

      await api.patch('/supplier/orders/${order['id']}/delivery', {

        'deliveryFee': fee,

      });

      _refresh();

    } catch (error) {

      if (mounted) _snack(context, 'Could not set delivery quote: $error');

    }

  }



  @override

  Widget build(BuildContext context) => FutureBuilder<List>(

    future: _future,

    builder: (context, s) {

      if (s.hasError) return _retry(s.error.toString(), _refresh);

      if (!s.hasData) return const Center(child: CircularProgressIndicator());

      final orders = s.data!;

      return RefreshIndicator(

        onRefresh: () async => _refresh(),

        child: ListView(

          padding: const EdgeInsets.all(16),

          children: [

            if (orders.isEmpty)

              const Padding(

                padding: EdgeInsets.all(40),

                child: Text(

                  'Shop orders will appear here.',

                  textAlign: TextAlign.center,

                ),

              )

            else

              for (final raw in orders)

                _orderTile(Map<String, dynamic>.from(raw)),

          ],

        ),

      );

    },

  );

  Widget _orderTile(Map<String, dynamic> o) {

    final shop = Map<String, dynamic>.from(o['shop'] as Map);

    final items = (o['items'] as List? ?? []);

    final next = switch (o['status']) {

      'PENDING' => 'ACCEPTED',

      'ACCEPTED' => 'READY',

      'READY' => 'DELIVERED',

      _ => null,

    };

    return Card(

      child: ExpansionTile(

        title: Text(

          shop['name'] ?? 'Shop order',

          style: const TextStyle(fontWeight: FontWeight.w800),

        ),

        subtitle: Text(

          '${o['status']} ┬╖ ${items.length} item lines ┬╖ Br ${o['total']}',

        ),

        children: [

          if (o['deliveryQuoted'] != true && o['status'] == 'PENDING')

            Padding(

              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),

              child: Row(

                children: [

                  const Expanded(

                    child: Text(

                      'No route distance was available. Set the full delivery fee before accepting.',

                      style: TextStyle(fontSize: 12, color: Colors.deepOrange),

                    ),

                  ),

                  TextButton(

                    onPressed: () => _quote(o),

                    child: const Text('Quote delivery'),

                  ),

                ],

              ),

            ),

          for (final x in items)

            ListTile(

              dense: true,

              title: Text(

                '${x['packageCount']} ├ù ${x['packName']} ${x['productName']}',

              ),

              subtitle: Text(

                '${x['unitsPerPack']} ${x['retailUnit']} each ┬╖ Br ${x['lineTotal']}',

              ),

            ),

          if (next != null)

            Padding(

              padding: const EdgeInsets.all(12),

              child: Row(

                mainAxisAlignment: MainAxisAlignment.end,

                children: [

                  if (o['status'] == 'PENDING')

                    TextButton(

                      onPressed: () => _status(o['id'].toString(), 'REJECTED'),

                      child: const Text('Reject'),

                    ),

                  FilledButton(

                    onPressed: () => _status(o['id'].toString(), next),

                    child: Text(next),

                  ),

                ],

              ),

            ),

        ],

      ),

    );

  }

}



class DeliveryPage extends StatefulWidget {

  const DeliveryPage({super.key});

  @override

  State<DeliveryPage> createState() => _DeliveryPageState();

}



class _DeliveryPageState extends State<DeliveryPage> {

  final fields = <String, TextEditingController>{};

  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() async {

    final r = await api.get('/supplier/profile');

    final s = Map<String, dynamic>.from(r['supplier'] as Map);

    for (final k in [

      'businessName',

      'latitude',

      'longitude',

      'deliveryBaseFee',

      'deliveryPerKm',

      'deliveryPerKg',

      'deliveryPerCubicMeter',

    ]) {

      fields.putIfAbsent(

        k,

        () => TextEditingController(text: s[k]?.toString() ?? ''),

      );

    }

    return s;

  }



  @override

  void dispose() {

    for (final c in fields.values) c.dispose();

    super.dispose();

  }



  Future<void> _save() async {

    double? n(String k) => double.tryParse(fields[k]!.text.trim());

    try {

      await api.patch('/supplier/profile', {

        'businessName': fields['businessName']!.text.trim(),

        'latitude': n('latitude'),

        'longitude': n('longitude'),

        'deliveryBaseFee': n('deliveryBaseFee') ?? 0,

        'deliveryPerKm': n('deliveryPerKm') ?? 0,

        'deliveryPerKg': n('deliveryPerKg') ?? 0,

        'deliveryPerCubicMeter': n('deliveryPerCubicMeter') ?? 0,

      });

      if (mounted) _snack(context, 'Delivery settings saved.');

    } catch (e) {

      if (mounted) _snack(context, 'Could not save settings: $e');

    }

  }



  @override

  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(

    future: _future,

    builder: (context, s) {

      if (s.hasError)

        return _retry(

          s.error.toString(),

          () => setState(() => _future = _load()),

        );

      if (!s.hasData) return const Center(child: CircularProgressIndicator());

      return ListView(

        padding: const EdgeInsets.all(20),

        children: [

          const Text(

            'Delivery pricing',

            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),

          ),

          const SizedBox(height: 6),

          const Text(

            'All suppliers use the same formula: base fee + km rate ├ù route distance + kg rate ├ù order weight + m┬│ rate ├ù order volume.',

          ),

          for (final e in const [

            ('businessName', 'Business name'),

            ('latitude', 'Pickup latitude'),

            ('longitude', 'Pickup longitude'),

            ('deliveryBaseFee', 'Base delivery fee (ETB)'),

            ('deliveryPerKm', 'ETB per km'),

            ('deliveryPerKg', 'ETB per kg'),

            ('deliveryPerCubicMeter', 'ETB per m┬│'),

          ])

            Padding(

              padding: const EdgeInsets.only(top: 12),

              child: TextField(

                controller: fields[e.$1],

                keyboardType: e.$1 == 'businessName'

                    ? TextInputType.text

                    : const TextInputType.numberWithOptions(decimal: true),

                decoration: InputDecoration(labelText: e.$2),

              ),

            ),

          const SizedBox(height: 20),

          FilledButton(

            onPressed: _save,

            child: const Text('Save delivery settings'),

          ),

        ],

      );

    },

  );

}



Widget _retry(String message, VoidCallback retry) => Center(

  child: Padding(

    padding: const EdgeInsets.all(24),

    child: Column(

      mainAxisSize: MainAxisSize.min,

      children: [

        Text(message, textAlign: TextAlign.center),

        TextButton(onPressed: retry, child: const Text('Retry')),

      ],

    ),

  ),

);

Future<String?> _textDialog(

  BuildContext context,

  String title,

  String label,

) async {

  final c = TextEditingController();

  final result = await showDialog<String>(

    context: context,

    builder: (ctx) => AlertDialog(

      title: Text(title),

      content: TextField(

        controller: c,

        autofocus: true,

        decoration: InputDecoration(labelText: label),

      ),

      actions: [

        TextButton(

          onPressed: () => Navigator.pop(ctx),

          child: const Text('Cancel'),

        ),

        FilledButton(

          onPressed: () => Navigator.pop(ctx, c.text),

          child: const Text('Save'),

        ),

      ],

    ),

  );

  c.dispose();

  return result;

}



void _snack(BuildContext context, String message) => ScaffoldMessenger.of(

  context,

).showSnackBar(SnackBar(content: Text(message)));

