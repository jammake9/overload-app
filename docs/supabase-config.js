/* ============================================================================
   Overload — Supabase connection settings
   ============================================================================
   Paste your two values below, between the quotes.

   Find them at: Supabase dashboard -> your project
                 -> Project Settings -> API

     SUPABASE_URL      = the "Project URL"        (looks like https://abcdefgh.supabase.co)
     SUPABASE_ANON_KEY = the "anon public" key    (a long string starting with "eyJ")

   The anon key is designed to be public — it ships inside every Supabase web
   and mobile app, and Row Level Security is what actually protects your data.
   It is safe to commit this file.

   Never put the "service_role" key here. That one bypasses all security and
   must stay on a server you control.
============================================================================ */

window.OVERLOAD_CONFIG = {
  SUPABASE_URL:      '',
  SUPABASE_ANON_KEY: '',

  // When true, the app runs entirely on localStorage with no account required —
  // the original pre-migration behaviour. Handy for working on the UI without
  // a network connection. Leave false for normal use.
  OFFLINE_ONLY: false
};
