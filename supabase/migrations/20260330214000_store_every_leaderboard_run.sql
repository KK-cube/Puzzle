create extension if not exists pgcrypto;
create extension if not exists citext;

create table if not exists public.leaderboard_runs (
  id uuid primary key default gen_random_uuid(),
  player_name citext not null,
  score integer not null check (score >= 0),
  played_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  constraint leaderboard_runs_name_length_check
    check (char_length(player_name::text) between 1 and 24)
);

comment on table public.leaderboard_runs is
  'Stores one leaderboard row per play so the same player can appear multiple times.';

comment on column public.leaderboard_runs.player_name is
  'Display name shown in the leaderboard.';

comment on column public.leaderboard_runs.score is
  'Score recorded for a single play session.';

create index if not exists leaderboard_runs_ranking_idx
  on public.leaderboard_runs (
    score desc,
    played_at asc,
    id asc
  );

alter table public.leaderboard_runs enable row level security;

revoke all on public.leaderboard_runs from anon, authenticated;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'leaderboard_players'
  ) and not exists (
    select 1
    from public.leaderboard_runs
  ) then
    insert into public.leaderboard_runs (
      player_name,
      score,
      played_at,
      created_at
    )
    select
      leaderboard_players.player_name,
      leaderboard_players.best_score,
      coalesce(
        leaderboard_players.best_score_updated_at,
        leaderboard_players.created_at,
        timezone('utc', now())
      ),
      coalesce(
        leaderboard_players.created_at,
        timezone('utc', now())
      )
    from public.leaderboard_players;
  end if;
end;
$$;

drop function if exists public.submit_leaderboard_score(text, integer);

create function public.submit_leaderboard_score(
  p_player_name text,
  p_score integer
)
returns public.leaderboard_runs
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_player_name text := btrim(coalesce(p_player_name, ''));
  v_row public.leaderboard_runs;
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

  insert into public.leaderboard_runs (
    player_name,
    score,
    played_at,
    created_at
  )
  values (
    v_player_name::citext,
    p_score,
    v_now,
    v_now
  )
  returning * into v_row;

  return v_row;
end;
$$;

comment on function public.submit_leaderboard_score(text, integer) is
  'Stores one new leaderboard row for each submitted play.';

create or replace function public.get_leaderboard(p_limit integer default 10)
returns table (
  rank bigint,
  player_name text,
  score integer,
  played_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    ranked.rank,
    ranked.player_name,
    ranked.score,
    ranked.played_at
  from (
    select
      row_number() over (
        order by
          leaderboard_runs.score desc,
          leaderboard_runs.played_at asc,
          leaderboard_runs.id asc
      ) as rank,
      leaderboard_runs.player_name::text as player_name,
      leaderboard_runs.score,
      leaderboard_runs.played_at
    from public.leaderboard_runs
  ) as ranked
  where ranked.rank <= greatest(1, least(coalesce(p_limit, 10), 100))
  order by ranked.rank;
$$;

comment on function public.get_leaderboard(integer) is
  'Returns ranked leaderboard rows from the per-play run log.';

drop function if exists public.get_leaderboard_top3();

create function public.get_leaderboard_top3()
returns table (
  rank bigint,
  player_name text,
  score integer,
  played_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    leaderboard.rank,
    leaderboard.player_name,
    leaderboard.score,
    leaderboard.played_at
  from public.get_leaderboard(3) as leaderboard;
$$;

comment on function public.get_leaderboard_top3() is
  'Compatibility wrapper that returns the top 3 ranked play records.';

create or replace function public.get_leaderboard_player_count()
returns integer
language sql
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.leaderboard_runs;
$$;

comment on function public.get_leaderboard_player_count() is
  'Returns the total number of submitted leaderboard plays.';

grant execute on function public.submit_leaderboard_score(text, integer)
  to anon, authenticated;

grant execute on function public.get_leaderboard(integer)
  to anon, authenticated;

grant execute on function public.get_leaderboard_top3()
  to anon, authenticated;

grant execute on function public.get_leaderboard_player_count()
  to anon, authenticated;
