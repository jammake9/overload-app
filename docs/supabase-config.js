/* Overload — Supabase connection settings
   The publishable (anon) key is designed to be public; it ships inside every
   Supabase web and mobile app. Row Level Security is what protects the data.
   Never put the service_role / secret key here. */

window.OVERLOAD_CONFIG = {
  SUPABASE_URL:      'https://tmpammhubvmqlndqfkeq.supabase.co',
  SUPABASE_ANON_KEY: 'sb_publishable_08uYU62Iixf9DHRc4ajYnQ_CcW9roVO',

  // true = ignore the server, keep everything in this browser only.
  OFFLINE_ONLY: false
};
