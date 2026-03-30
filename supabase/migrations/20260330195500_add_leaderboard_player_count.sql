create or replace function public.get_leaderboard_player_count()
returns integer
language sql
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.leaderboard_players;
$$;

comment on function public.get_leaderboard_player_count() is
  'Returns the number of unique leaderboard players.';

grant execute on function public.get_leaderboard_player_count()
  to anon, authenticated;
