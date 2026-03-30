const kSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);

bool get isSupabaseConfigured =>
    kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty;
