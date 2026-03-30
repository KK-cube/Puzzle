-- Leaderboard schema for Supabase.
-- Design:
-- 1. Keep one best-score row per player name.
-- 2. Expose writes through RPC so clients cannot update arbitrary columns.
-- 3. Expose reads through an RPC that returns the top 3 ranked players.

create extension if not exists pgcrypto;
create extension if not exists citext;

create table if not exists public.leaderboard_players (
  id uuid primary key default gen_random_uuid(),
  player_name citext not null,
  best_score integer not null check (best_score >= 0),
  best_score_updated_at timestamptz not null default timezone('utc', now()),
  last_submitted_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint leaderboard_players_name_length_check
    check (char_length(player_name::text) between 1 and 24),
  constraint leaderboard_players_player_name_key unique (player_name)
);

comment on table public.leaderboard_players is
  'Stores one best-score row per leaderboard player name.';

comment on column public.leaderboard_players.player_name is
  'Display name shown in the leaderboard. Case-insensitive unique.';

comment on column public.leaderboard_players.best_score is
  'Best score ever submitted for this player name.';

create index if not exists leaderboard_players_ranking_idx
  on public.leaderboard_players (
    best_score desc,
    best_score_updated_at asc,
    player_name asc
  );

alter table public.leaderboard_players enable row level security;

revoke all on public.leaderboard_players from anon, authenticated;

create or replace function public.submit_leaderboard_score(
  p_player_name text,
  p_score integer
)
returns public.leaderboard_players
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_player_name text := btrim(coalesce(p_player_name, ''));
  v_row public.leaderboard_players;
begin
  if v_player_name = '' then
    raise exception 'player_name must not be empty';
  end if;

  if char_length(v_player_name) > 24 then
    raise exception 'player_name must be 24 characters or fewer';
  end if;

  if p_score is null or p_score < 0 then
    raise exception 'score must be a non-negative integer';
  end if;

  insert into public.leaderboard_players as leaderboard_players (
    player_name,
    best_score,
    best_score_updated_at,
    last_submitted_at,
    created_at,
    updated_at
  )
  values (
    v_player_name::citext,
    p_score,
    v_now,
    v_now,
    v_now,
    v_now
  )
  on conflict (player_name) do update
    set best_score = greatest(leaderboard_players.best_score, excluded.best_score),
        best_score_updated_at = case
          when excluded.best_score > leaderboard_players.best_score then excluded.best_score_updated_at
          else leaderboard_players.best_score_updated_at
        end,
        last_submitted_at = excluded.last_submitted_at,
        updated_at = excluded.updated_at
  returning * into v_row;

  return v_row;
end;
$$;

comment on function public.submit_leaderboard_score(text, integer) is
  'Upserts a player score and keeps only the best score for each player name.';

create or replace function public.get_leaderboard_top3()
returns table (
  rank bigint,
  player_name text,
  score integer,
  best_score_updated_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    ranked.rank,
    ranked.player_name,
    ranked.score,
    ranked.best_score_updated_at
  from (
    select
      row_number() over (
        order by
          leaderboard_players.best_score desc,
          leaderboard_players.best_score_updated_at asc,
          leaderboard_players.player_name asc
      ) as rank,
      leaderboard_players.player_name::text as player_name,
      leaderboard_players.best_score as score,
      leaderboard_players.best_score_updated_at
    from public.leaderboard_players
  ) as ranked
  where ranked.rank <= 3
  order by ranked.rank;
$$;

comment on function public.get_leaderboard_top3() is
  'Returns the current top 3 leaderboard rows with display rank.';

grant execute on function public.submit_leaderboard_score(text, integer)
  to anon, authenticated;

grant execute on function public.get_leaderboard_top3()
  to anon, authenticated;
