-- Existe un único trabajo catalog-sync por proyecto. La ausencia de fila indica pruebas manuales.
create table catalog.sync_schedule (
    job_name text primary key check (job_name = 'catalog-sync'),
    edition text not null check (edition ~ '^[a-z0-9][a-z0-9-]{0,63}$'),
    active boolean not null,
    changed_at timestamptz not null default now()
);
alter table catalog.sync_schedule enable row level security;
revoke all on catalog.sync_schedule from public, anon, authenticated, service_role;
grant select on catalog.sync_schedule to catalog_viewer;
create policy schedule_viewer_read on catalog.sync_schedule for select to catalog_viewer using (true);

-- La consulta local y la función alojada comparten el contrato y los permisos del invocante.
create function catalog.panel_snapshot() returns jsonb
language sql stable security invoker set search_path = '' as $$
    with latest as (
        select distinct on (edition) * from catalog.sync_runs
        order by edition, started_at desc, id
    ), completed as (
        select distinct on (edition) * from catalog.sync_runs
        where status in ('success', 'review', 'error')
        order by edition, finished_at desc, id
    ), applied as (
        select distinct on (edition) * from catalog.sync_runs
        where mode = 'apply' and status = 'success'
        order by edition, finished_at desc, id
    ), recent as (
        select * from latest union select * from completed union select * from applied
    )
    select jsonb_build_object(
        'representations', coalesce((select jsonb_agg(to_jsonb(r) order by edition, committee, representation_name)
            from catalog.representations r), '[]'::jsonb),
        'runs', coalesce((select jsonb_agg(to_jsonb(r) order by started_at desc, id)
            from (select id, edition, mode, status, started_at, finished_at, altas, cambios, iguales, ausentes,
                         error_code from recent) r), '[]'::jsonb),
        'schedules', coalesce((select jsonb_agg(jsonb_build_object(
            'edition', s.edition, 'active', s.active,
            'overdue', s.active and now() > greatest(s.changed_at, c.finished_at) + interval '40 minutes'))
            from catalog.sync_schedule s left join completed c using (edition)), '[]'::jsonb)
    );
$$;
revoke all on function catalog.panel_snapshot() from public, anon, authenticated, service_role;
grant execute on function catalog.panel_snapshot() to catalog_viewer;
