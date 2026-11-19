-- Roles sin credenciales. Los usuarios de conexión se aprovisionan por entorno.
create role catalog_sync nologin noinherit;
create role catalog_viewer nologin noinherit;
grant usage on schema catalog to catalog_sync, catalog_viewer;

grant select on catalog.representations to catalog_sync, catalog_viewer;
grant insert (edition, committee, representation_name, representation_type, allows_co_delegation)
    on catalog.representations to catalog_sync;
grant update (committee, representation_name, representation_type, allows_co_delegation)
    on catalog.representations to catalog_sync;
grant execute on function catalog.import_representations(text, jsonb, boolean, boolean) to catalog_sync;

create policy catalog_sync_select on catalog.representations for select to catalog_sync using (true);
create policy catalog_sync_insert on catalog.representations for insert to catalog_sync with check (true);
create policy catalog_sync_update on catalog.representations for update to catalog_sync using (true) with check (true);
create policy catalog_viewer_select on catalog.representations for select to catalog_viewer using (true);

create table catalog.sync_runs (
    id uuid primary key default gen_random_uuid(),
    edition text not null check (edition ~ '^[a-z0-9][a-z0-9-]{0,63}$'),
    mode text not null check (mode in ('preview', 'apply')),
    status text not null check (status in ('running', 'success', 'review', 'error', 'skipped')),
    started_at timestamptz not null default now(),
    finished_at timestamptz,
    source_hash text check (source_hash is null or source_hash ~ '^[0-9a-f]{64}$'),
    altas integer check (altas >= 0),
    cambios integer check (cambios >= 0),
    iguales integer check (iguales >= 0),
    ausentes integer check (ausentes >= 0),
    attempts integer not null default 0 check (attempts >= 0),
    rate_limited integer not null default 0 check (rate_limited >= 0 and rate_limited <= attempts),
    error_code text check (error_code is null or error_code ~ '^[a-z0-9_]{1,64}$'),
    check ((status = 'running' and finished_at is null)
        or (status <> 'running' and finished_at is not null)),
    check (finished_at is null or finished_at >= started_at)
);
create index sync_runs_edition_started_idx on catalog.sync_runs (edition, started_at desc);
alter table catalog.sync_runs enable row level security;
revoke all on catalog.sync_runs from public, anon, authenticated, service_role;
grant select, insert, update on catalog.sync_runs to catalog_sync;
grant select on catalog.sync_runs to catalog_viewer;
create policy sync_runs_sync_select on catalog.sync_runs for select to catalog_sync using (true);
create policy sync_runs_sync_insert on catalog.sync_runs for insert to catalog_sync with check (true);
create policy sync_runs_sync_update on catalog.sync_runs for update to catalog_sync using (true) with check (true);
create policy sync_runs_viewer_select on catalog.sync_runs for select to catalog_viewer using (true);

-- Cada llamada consume una reserva antes de efectuar una solicitud a Sheets.
create table catalog.sync_read_attempts (
    project_key text not null check (project_key ~ '^[a-zA-Z0-9_-]{1,100}$'),
    attempted_at timestamptz not null default clock_timestamp()
);
create index sync_read_attempts_recent_idx on catalog.sync_read_attempts (project_key, attempted_at);
alter table catalog.sync_read_attempts enable row level security;
revoke all on catalog.sync_read_attempts from public, anon, authenticated, service_role;
grant select, insert, delete on catalog.sync_read_attempts to catalog_sync;
create policy sync_attempts_select on catalog.sync_read_attempts for select to catalog_sync using (true);
create policy sync_attempts_insert on catalog.sync_read_attempts for insert to catalog_sync with check (true);
create policy sync_attempts_delete on catalog.sync_read_attempts for delete to catalog_sync using (true);

create function catalog.reserve_sheet_read(project_key text) returns boolean
language plpgsql volatile security invoker set search_path = ''
as $$
declare
    now_at timestamptz;
begin
    if project_key is null or project_key !~ '^[a-zA-Z0-9_-]{1,100}$' then
        raise exception 'Identificador de proyecto inválido';
    end if;
    perform pg_advisory_xact_lock(hashtextextended('catalog.google-quota:' || project_key, 0));
    now_at := clock_timestamp();
    delete from catalog.sync_read_attempts
        where sync_read_attempts.project_key = reserve_sheet_read.project_key
          and attempted_at <= now_at - interval '60 seconds';
    if (select count(*) from catalog.sync_read_attempts
        where sync_read_attempts.project_key = reserve_sheet_read.project_key) >= 12 then
        return false;
    end if;
    insert into catalog.sync_read_attempts (project_key, attempted_at) values (project_key, now_at);
    return true;
end;
$$;
revoke all on function catalog.reserve_sheet_read(text) from public, anon, authenticated, service_role;
grant execute on function catalog.reserve_sheet_read(text) to catalog_sync;
