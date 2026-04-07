-- =============================================================================
-- Seed de datos de prueba — Onze
-- NUNCA ejecutar en producción. Solo para desarrollo local con `supabase db reset`.
-- =============================================================================

-- Nota: los usuarios reales se crean a través de Supabase Auth.
-- Este seed asume que se crean manualmente en el panel de Auth
-- y luego se insertan los datos de perfil directamente.

-- ---------------------------------------------------------------------------
-- Achievements del catálogo inicial
-- ---------------------------------------------------------------------------

INSERT INTO public.achievements (code, name, description, target_type) VALUES
  ('first_win',       'Primera victoria',          'Ganaste tu primer partido oficial',           'team'),
  ('hat_trick_10',    'Racha de 10',               'Equipo con 10 victorias consecutivas',        'team'),
  ('unbeaten_season', 'Temporada perfecta',        'Termina un periodo sin perder ningún partido','team'),
  ('centurion',       'Centurión',                 'Jugaste 100 partidos oficiales',              'user'),
  ('veteran',         'Veterano',                  'Jugaste 50 partidos oficiales',               'user'),
  ('ironman',         'Hombre de hierro',          'Jugaste 10 partidos en un mismo periodo',     'user'),
  ('top_scorer',      'Máxima actividad',          'Mayor cantidad de partidos en el periodo',    'team'),
  ('comeback_king',   'Rey de la remontada',       'Ganaste 5 partidos siendo el underdog (ELO más bajo)', 'team')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Recompensas de ejemplo
-- ---------------------------------------------------------------------------

INSERT INTO public.rewards (name, description, partner_business, discount_type, points_cost, active, stock) VALUES
  ('Descuento 20% cancha',   '20% de descuento en tu próxima reserva',      'Canchas Onze',   'percentage', 500,  true, NULL),
  ('Bebida gratis',          'Una bebida energética cortesía del sponsor',   'Sponsor local',  'item',       200,  true, 50),
  ('Hora gratis de cancha',  'Una hora gratis en cancha participante',       'Canchas Onze',   'item',       1000, true, 10)
ON CONFLICT DO NOTHING;
